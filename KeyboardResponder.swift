//
//  KeyboardResponder.swift
//

import SwiftUI
import Combine

/// Publishes the current on-screen keyboard height (0 when hidden).
final class KeyboardResponder: ObservableObject {
    @Published var height: CGFloat = 0
    private var cancellables: Set<AnyCancellable> = []

    init() {
        // keyboard will‐show
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
            .map { $0.height }
            .sink { [weak self] in self?.height = $0 }
            .store(in: &cancellables)

        // keyboard will‐hide
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }
            .sink { [weak self] in self?.height = $0 }
            .store(in: &cancellables)
    }
}
