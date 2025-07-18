//
//  UserLite.swift
//  FitSpo
//

import Foundation

/// Lightweight user object returned by prefix-search
struct UserLite: Identifiable, Codable, Hashable {
    let id: String           // same as uid
    let displayName: String
    let avatarURL: String
}
