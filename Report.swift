//
//  Report.swift
//  FitSpo
//
//  Simple Firestore‑backed model representing a user report.
//

import Foundation
import FirebaseFirestore

// ─────────────────────────────────────────────────────────────
/// The limited set of reasons the user can choose from.
enum ReportReason: String, CaseIterable, Codable, Identifiable {
    case spam            = "Spam or misleading"
    case inappropriate   = "Nudity / sexual content"
    case harassment      = "Harassment or hate"
    case copyright       = "Copyright infringement"
    case other           = "Other"

    var id: String { rawValue }
}

// ─────────────────────────────────────────────────────────────
/// A single report document (stored at `reports/{postId}_{reporterUID}`).
struct Report: Identifiable, Codable {

    // MARK: – stored fields
    let id: String           // "\(postId)_\(reporterId)"
    let postId: String
    let reporterId: String
    let reason: ReportReason
    let timestamp: Date

    // MARK: – convenience init
    init(postId: String, reporterId: String, reason: ReportReason) {
        self.id = "\(postId)_\(reporterId)"
        self.postId = postId
        self.reporterId = reporterId
        self.reason = reason
        self.timestamp = Date()
    }

    // MARK: – CodingKeys (include every stored property)
    enum CodingKeys: String, CodingKey {
        case id, postId, reporterId, reason, timestamp
    }
}
