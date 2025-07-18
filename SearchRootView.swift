//
//  SearchRootView.swift
//

import SwiftUI

struct SearchRootView: View {
    @State private var query = ""
    @State private var showResults = false

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .opacity(0.15)
                Text("Search accounts or #tags")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .navigationTitle("Search")
        }
        .searchable(text: $query, prompt: "Username or #tag")
        .onSubmit(of: .search) {
            if !query.isEmpty { showResults = true }
        }
        .sheet(isPresented: $showResults) {
            SearchResultsView(query: query)
                .presentationDetents([.large])
        }
    }
}
