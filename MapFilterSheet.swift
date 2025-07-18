import SwiftUI

struct MapFilterSheet: View {
    @Binding var filter: MapFilter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Temperature")) {
                    Picker("", selection: $filter.tempBand) {
                        Text("Any").tag(MapFilter.TempBand?.none)
                        ForEach(MapFilter.TempBand.allCases, id: \.self) {
                            Text($0.rawValue.capitalized).tag(Optional($0))
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Weather")) {
                    Picker("", selection: $filter.weather) {
                        Text("Any").tag(MapFilter.Weather?.none)
                        ForEach(MapFilter.Weather.allCases, id: \.self) {
                            Text($0.rawValue.capitalized).tag(Optional($0))
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Season")) {
                    Picker("", selection: $filter.season) {
                        Text("Any").tag(ExploreFilter.Season?.none)
                        ForEach(ExploreFilter.Season.allCases, id: \.self) {
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
                    Button("Clear") { filter = MapFilter() }
                }
            }
        }
    }
}
