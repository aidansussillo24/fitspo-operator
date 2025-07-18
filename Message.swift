//
//  Message.swift
//  FitSpo
//

import Foundation

/// A single chat message, either text or a shared post
struct Message: Identifiable {
    let id: String
    let senderId: String
    let text: String?      // nil when this is a post share
    let postId: String?    // nil when this is a text message
    let timestamp: Date
}
