//
//  Post.swift
//  FitSpo
//

import Foundation
import CoreLocation
import SwiftUI

struct Post: Identifiable, Codable {

    // core
    let id:        String
    let userId:    String
    let imageURL:  String
    let caption:   String
    var username:  String? = nil
    let timestamp: Date
    var likes:     Int
    var isLiked:   Bool

    // geo / weather
    let latitude:    Double?
    let longitude:   Double?
    var  temp:       Double?
    var  weatherIcon: String?

    // outfit
    var outfitItems: [OutfitItem]? = nil
    var outfitTags : [OutfitTag]?  = nil        // ← NEW

    // hashtags
    var hashtags: [String]


    // convenience
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Map OpenWeather icon → SF Symbol name
    var weatherSymbolName: String? {
        guard let icon = weatherIcon else { return nil }
        let day = icon.hasSuffix("d")
        switch String(icon.prefix(2)) {
        case "01": return day ? "sun.max" : "moon"
        case "02": return day ? "cloud.sun" : "cloud.moon"
        case "03", "04": return "cloud"
        case "09": return "cloud.drizzle"
        case "10": return "cloud.rain"
        case "11": return "cloud.bolt"
        case "13": return "snow"
        case "50": return "cloud.fog"
        default: return nil
        }
    }

    /// Suggested colors for the SF Symbol based on the weather condition
    var weatherIconColors: (Color, Color?)? {
        guard let name = weatherSymbolName else { return nil }
        switch name {
        case "sun.max":           return (.yellow, nil)
        case "moon":              return (.white, nil)
        case "cloud.sun":         return (.white, .yellow)
        case "cloud.moon":        return (.white, .gray)
        case "cloud":             return (.white, nil)
        case "cloud.drizzle":     return (.white, .blue)
        case "cloud.rain":        return (.white, .blue)
        case "cloud.bolt":        return (.white, .yellow)
        case "snow":              return (.white, nil)
        case "cloud.fog":         return (.white, nil)
        default:                   return nil
        }
    }

    var tempString: String? {
        guard let c = temp else { return nil }
        let f = c * 9 / 5 + 32
        return String(format: "%.0f\u{00B0}", f)
    }


    enum CodingKeys: String, CodingKey {
        case id, userId, imageURL, caption, username, timestamp, likes, isLiked
        case latitude, longitude, temp, weatherIcon, hashtags
        case outfitItems, outfitTags
    }
}

// Hashable conformance for navigationDestination(item:)
extension Post: Hashable {
    static func == (lhs: Post, rhs: Post) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
