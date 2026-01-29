import Flutter
import UIKit
import MultipeerConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let p2pChannel = FlutterMethodChannel(name: "com.example.hydrashare/p2p",
                                              binaryMessenger: controller.binaryMessenger)
    
    p2pChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "openP2PInvitation" {
        self.openP2PInvitation(controller: controller)
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func openP2PInvitation(controller: UIViewController) {
    // Standard iOS P2P invitation via Multipeer Connectivity
    let serviceType = "hydra-share"
    let peerID = MCPeerID(displayName: UIDevice.current.name)
    let browser = MCBrowserViewController(serviceType: serviceType, session: MCSession(peer: peerID))
    // browser.delegate = self // Would need to implement delegate
    controller.present(browser, animated: true, completion: nil)
  }
}
