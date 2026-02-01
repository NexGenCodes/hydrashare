import Flutter
import UIKit
import MultipeerConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Initialize Go Daemon early if needed, or let Flutter trigger it via FFI
    // The FFI bridge in Dart will call InitDaemon()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
