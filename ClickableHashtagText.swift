//
//  ClickableHashtagText.swift
//  FitSpo
//
//  A SwiftUI view that makes hashtags clickable and blue, like Instagram
//

import SwiftUI

struct ClickableHashtagText: View {
    let text: String
    let onHashtagTap: (String) -> Void
    let onMentionTap: ((String) -> Void)?
    
    init(text: String, onHashtagTap: @escaping (String) -> Void, onMentionTap: ((String) -> Void)? = nil) {
        self.text = text
        self.onHashtagTap = onHashtagTap
        self.onMentionTap = onMentionTap
    }
    
    var body: some View {
        let words = text.components(separatedBy: " ")
        
        HStack(alignment: .top, spacing: 4) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                if word.hasPrefix("#") && word.count > 1 {
                    // Hashtag
                    Text(word)
                        .foregroundColor(.blue)
                        .onTapGesture {
                            let hashtag = String(word.dropFirst())
                            onHashtagTap(hashtag)
                        }
                } else if word.hasPrefix("@") && word.count > 1 {
                    // Mention
                    Text(word)
                        .foregroundColor(.blue)
                        .onTapGesture {
                            let username = String(word.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                            // Only call callback if username is not empty
                            if !username.isEmpty {
                                onMentionTap?(username)
                            }
                        }
                } else {
                    // Regular text
                    Text(word)
                        .foregroundColor(.primary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        ClickableHashtagText(text: "Love this outfit! #fashion #ootd #style") { hashtag in
            print("Tapped hashtag: \(hashtag)")
        }
        
        ClickableHashtagText(
            text: "Hey @sofia check out this #outfit!",
            onHashtagTap: { hashtag in
                print("Tapped hashtag: \(hashtag)")
            },
            onMentionTap: { username in
                print("Tapped mention: \(username)")
            }
        )
        
        ClickableHashtagText(text: "Just regular text without hashtags") { hashtag in
            print("Tapped hashtag: \(hashtag)")
        }
        
        ClickableHashtagText(text: "Mix of #hashtags @username and regular text #cool") { hashtag in
            print("Tapped hashtag: \(hashtag)")
        } onMentionTap: { username in
            print("Tapped mention: \(username)")
        }
    }
    .padding()
} 