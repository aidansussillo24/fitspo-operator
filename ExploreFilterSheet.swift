//
//  ExploreFilterSheet.swift
//  FitSpo
//

import SwiftUI

struct ExploreFilterSheet: View {

    @Binding var filter: ExploreFilter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {

                // ── Season ─────────────────────────────────────
                Section(header: Text("Season")) {
                    Picker("", selection: $filter.season) {
                        Text("Any").tag(ExploreFilter.Season?.none)
                        ForEach(ExploreFilter.Season.allCases, id: \.self) {
                            Text($0.rawValue.capitalized).tag(Optional($0))
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // ── Time of Day ───────────────────────────────
                Section(header: Text("Time of Day")) {
                    Picker("", selection: $filter.timeBand) {
                        Text("Any").tag(ExploreFilter.TimeBand?.none)
                        ForEach(ExploreFilter.TimeBand.allCases, id: \.self) {
                            Text($0.rawValue.capitalized).tag(Optional($0))
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        filter = ExploreFilter()          // reset to defaults
                    }
                }
            }
        }
    }
}
