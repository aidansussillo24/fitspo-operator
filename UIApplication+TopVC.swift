//
//  UIApplication+TopVC.swift
//  FitSpo
//
//  Small helpers used by SafariView & toast overlays.
//

import UIKit

extension UIApplication {

    /// Dismiss the keyboard if present.
    func hideKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder),
                   to: nil, from: nil, for: nil)
    }

    /// Returns the currently visible view-controller.
    var topMostVC: UIViewController? {
        guard let root = connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController
        else { return nil }

        var current = root
        while let presented = current.presentedViewController {
            current = presented
        }
        return current
    }
}
