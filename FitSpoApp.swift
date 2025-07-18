import SwiftUI
import Firebase

@main
struct FitSpoApp: App {
    // wire up your AppDelegate so Firebase.config gets called
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .accentColor(.black)
        }
    }
}
