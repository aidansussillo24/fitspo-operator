// AppDelegate.swift

import UIKit
import FirebaseCore

/// ———————
/// Remove any @main or @UIApplicationMain here.
/// This is a plain UIKit delegate that just configures Firebase.
/// ———————
class AppDelegate: UIResponder, UIApplicationDelegate {

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey:Any]?
  ) -> Bool {
    FirebaseApp.configure()
    return true
  }

  // You can leave your scene-session methods untouched:
  func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    UISceneConfiguration(
      name: "Default Configuration",
      sessionRole: connectingSceneSession.role
    )
  }
}
