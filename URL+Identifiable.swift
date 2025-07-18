//
//  URL+Identifiable.swift
//  FitSpo
//
//  Allows you to use `URL` with `.sheet(item:)`.
//

import Foundation

extension URL: Identifiable {
    public var id: String { absoluteString }
}
