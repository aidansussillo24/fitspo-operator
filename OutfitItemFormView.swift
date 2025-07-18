//
//  OutfitItemFormView.swift
//  FitSpo
//
//  Sheet for adding or editing a single outfit item.
//  Updated 2025-06-20:   • Adds URL-sanitisation so entries like “nike.com”
//                         are automatically saved as “https://nike.com”.
//

import SwiftUI

/// Adds “https://” if the string does not already start with
/// `http://` or `https://`. Returns `nil` when the input is empty.
fileprivate func sanitizedURL(from raw: String) -> URL? {
    guard !raw.isEmpty else { return nil }
    if raw.lowercased().hasPrefix("http://") || raw.lowercased().hasPrefix("https://") {
        return URL(string: raw)
    } else {
        return URL(string: "https://\(raw)")
    }
}

// ─────────────────────────────────────────────────────────────
struct OutfitItemFormView: View {

    /// Pass an item here to edit it; leave `nil` to create a new one.
    var initial: OutfitItem? = nil
    var onSave: (OutfitItem) -> Void
    var onCancel: () -> Void

    // form fields
    @State private var label  = ""
    @State private var brand  = ""
    @State private var link   = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("What is the item?") {
                    TextField("e.g. Dunk Low Retro", text: $label)
                }

                Section {
                    TextField("Brand (optional)", text: $brand)

                    TextField("Buy link (optional)", text: $link)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(initial == nil ? "Add Item" : "Edit Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // ——— sanitize link ———
                        let cleaned = link.trimmingCharacters(in: .whitespaces)
                        let final   = sanitizedURL(from: cleaned)?.absoluteString ?? cleaned

                        onSave(OutfitItem(
                            id: initial?.id ?? UUID().uuidString,
                            label:  label.trimmingCharacters(in: .whitespaces),
                            brand:  brand.trimmingCharacters(in: .whitespaces),
                            shopURL: final
                        ))
                    }
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                // pre-fill when editing
                if let ini = initial {
                    label = ini.label
                    brand = ini.brand
                    link  = ini.shopURL
                }
            }
        }
    }
}
