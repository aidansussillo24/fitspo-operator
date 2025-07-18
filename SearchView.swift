import SwiftUI

struct SearchView: View {
    @State private var selectedTab: SearchTab = .outfits
    @State private var searchText = ""

    enum SearchTab: String, CaseIterable, Identifiable {
        case outfits = "Outfits"
        case users = "Users"
        case tags = "Tags"

        var id: String { self.rawValue }
    }

    var body: some View {
        VStack {
            // Search Bar
            TextField("Search for outfits, users, or tags", text: $searchText)
                .padding()
                .background(Color.white.opacity(0.8))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top, 20)

            // Tab Picker
            Picker("Select", selection: $selectedTab) {
                ForEach(SearchTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .background(Color.white.opacity(0.8))
            .cornerRadius(8)
            .padding(.horizontal)

            // Content Grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 15)]) {
                    ForEach(0..<8) { _ in
                        Rectangle()
                            .fill(Color.white)
                            .cornerRadius(15)
                            .shadow(radius: 5)
                            .frame(height: 200)
                            .overlay(
                                Text("Placeholder")
                                    .foregroundColor(.gray)
                            )
                    }
                }
                .padding()
            }

            Spacer()
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.paleDogwood, Color.melon]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
        )
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
    }
}
