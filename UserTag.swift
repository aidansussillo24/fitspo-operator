//
//  UserTag.swift
//  FitSpo
//
//  Light‑weight model used by the tag overlay and for saving to Firestore.
//

import Foundation
import CoreGraphics

struct UserTag: Identifiable, Codable {
    /// Firestore uid of the tagged user
    let id: String          // alias = uid
    
    /// Normalised coordinates (0…1) relative to the image
    var xNorm: CGFloat
    var yNorm: CGFloat
    
    /// Display name (cached for convenience so we don’t re‑fetch every time)
    var displayName: String
    
    enum CodingKeys: String, CodingKey {
        case id   = "uid"
        case xNorm, yNorm, displayName
    }
}
