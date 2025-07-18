//
//  OutfitItem.swift
//  FitSpo
//
//  Model returned by Cloud Function *and* cached in Firestore.
//
import Foundation

struct OutfitItem: Identifiable, Codable {
    let id      : String          // UUID on the client
    let label   : String          // “denim jacket”, “sneaker” …
    let brand   : String
    let shopURL : String

    /// Helper when writing back to Firestore
    var asDictionary: [String:String] {
        ["label": label,
         "brand": brand,
         "shopURL": shopURL]
    }
}
