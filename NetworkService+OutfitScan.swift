//
//  NetworkService+OutfitScan.swift
//  FitSpo
//
//  Polls the Replicate job until it finishes.
//  Updated 2025‑06‑19: allow up to ~60 s instead of 30 s.
//

import Foundation
import FirebaseFunctions

// ───────── Cloud‑Function DTOs ─────────

struct ScanOutfitResponse: Decodable {
    let postId   : String
    let replicate: ReplicateJob
}

struct ReplicateJob: Decodable {
    let id     : String
    let status : String          // starting / processing / succeeded / failed
    let output : ReplicateOutput?
}

struct ReplicateOutput: Decodable {
    struct JsonData: Decodable   { let objects: [DetectedObject] }
    let json_data: JsonData
}

struct DetectedObject: Decodable, Identifiable {
    let id         = UUID()
    let name       : String
    let confidence : Double
    let bbox       : [Double]

    private enum CodingKeys: String, CodingKey {
        case name, label, category, confidence, score, bbox, box
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name       = try c.decodeIfPresent(String.self, forKey: .name)
                  ?? c.decodeIfPresent(String.self, forKey: .label)
                  ?? c.decodeIfPresent(String.self, forKey: .category)
                  ?? "item"
        confidence = try c.decodeIfPresent(Double.self, forKey: .confidence)
                  ?? c.decodeIfPresent(Double.self, forKey: .score)
                  ?? 0
        bbox       = try c.decodeIfPresent([Double].self, forKey: .bbox)
                  ?? c.decodeIfPresent([Double].self, forKey: .box)
                  ?? []
    }
}

// ───────── Outfit‑scan helpers ─────────

@MainActor
extension NetworkService {

    /// Kick off the Cloud Function that starts a Replicate job.
    static func scanOutfit(postId: String,
                           imageURL: String) async throws -> ReplicateJob {
        let functions = Functions.functions(region: "us-central1")
        let body: [String: Any] = ["postId": postId, "imageURL": imageURL]
        let data = try await functions.httpsCallable("scanOutfit").call(body)
        return try JSONDecoder().decode(
            ScanOutfitResponse.self,
            from: JSONSerialization.data(withJSONObject: data.data)
        ).replicate
    }

    /// Poll Replicate every 2 s until the job leaves “starting/processing”.
    /// Now allows up to **29 polls ≈ 58 s** before giving up.
    static func waitForReplicate(prediction job: ReplicateJob) async throws -> ReplicateJob {
        var current = job
        var tries   = 0
        while ["starting", "processing"].contains(current.status) {
            try await Task.sleep(for: .seconds(2))
            current = try await fetchReplicate(jobID: current.id)
            guard tries < 29 else { throw URLError(.timedOut) }  // ← was 15
            tries += 1
        }
        return current
    }

    private static func fetchReplicate(jobID: String) async throws -> ReplicateJob {
        let functions = Functions.functions(region: "us-central1")
        let res = try await functions
            .httpsCallable("fetchReplicate")
            .call(["jobId": jobID])
        return try JSONDecoder().decode(
            ReplicateJob.self,
            from: JSONSerialization.data(withJSONObject: res.data)
        )
    }
}
