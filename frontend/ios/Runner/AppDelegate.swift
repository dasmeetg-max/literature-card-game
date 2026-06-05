import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // ── FIXED: guard against nil window ──────────────────────────
    if let controller = window?.rootViewController as? FlutterViewController {
      let wakelockChannel = FlutterMethodChannel(
        name: "com.literature.wakelock",
        binaryMessenger: controller.binaryMessenger
      )
      
      wakelockChannel.setMethodCallHandler { (call, result) in
        if call.method == "enable" {
          UIApplication.shared.isIdleTimerDisabled = true
          result(nil)
        } else if call.method == "disable" {
          UIApplication.shared.isIdleTimerDisabled = false
          result(nil)
        }
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}