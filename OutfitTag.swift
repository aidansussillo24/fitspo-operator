//
//  OutfitTag.swift
//  FitSpo
//
//  A 2‑D pin that associates an OutfitItem with a point on the image.
//  xNorm / yNorm are normalised (0‑1) so they adapt to every screen size.
//

import Foundation

struct OutfitTag: Identifiable, Codable {
    let id: String
    let itemId: String        // id of the OutfitItem this tag represents
    var xNorm: Double
    var yNorm: Double
}
