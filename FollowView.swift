import SwiftUI

struct FollowView: View {
    var body: some View {
        VStack {
            Text("Followers")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.cherryBlossomPink)
                .padding(.top, 20)

            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(0..<10) { _ in
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 50, height: 50)
                                .foregroundColor(.cambridgeBlue)

                            VStack(alignment: .leading) {
                                Text("Username")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Bio or description goes here.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: {
                                // Follow/unfollow action
                            }) {
                                Text("Follow")
                                    .font(.headline)
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 5)
                                    .foregroundColor(.white)
                                    .background(Color.cherryBlossomPink)
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(radius: 5)
                    }
                }
                .padding()
            }
            .background(
                LinearGradient(gradient: Gradient(colors: [Color.paleDogwood, Color.melon]), startPoint: .top, endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)
            )
        }
    }
}

struct FollowView_Previews: PreviewProvider {
    static var previews: some View {
        FollowView()
    }
}
