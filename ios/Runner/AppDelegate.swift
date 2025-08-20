import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  var privacyOverlay: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Observe for screen capture (screenshot & recording) state changes
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenCaptureChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )

    // Observe for user screenshots (note: iOS does not allow blocking screenshots,
    // but we can detect them and immediately cover sensitive content)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(userDidTakeScreenshot),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )

    // Initial check
    if UIScreen.main.isCaptured {
      showPrivacyOverlay()
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @objc func screenCaptureChanged() {
    DispatchQueue.main.async {
      if UIScreen.main.isCaptured {
        self.showPrivacyOverlay()
      } else {
        self.hidePrivacyOverlay()
      }
    }
  }

  @objc func userDidTakeScreenshot() {
    // Show the privacy overlay briefly when a screenshot is taken
    showPrivacyOverlay()
    // Hide after a short delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      self.hidePrivacyOverlay()
    }
  }

  func showPrivacyOverlay() {
    guard let window = UIApplication.shared.windows.first else { return }
    if privacyOverlay != nil { return }

    let overlay = UIView(frame: window.bounds)
    overlay.backgroundColor = UIColor.black
    overlay.alpha = 0.95
    overlay.isUserInteractionEnabled = false

    // Optional: Add a label explaining why the screen is hidden
    let label = UILabel()
    label.text = "Screen capture is disabled"
    label.textColor = .white
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    overlay.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
    ])

    window.addSubview(overlay)
    privacyOverlay = overlay
  }

  func hidePrivacyOverlay() {
    privacyOverlay?.removeFromSuperview()
    privacyOverlay = nil
  }
}
