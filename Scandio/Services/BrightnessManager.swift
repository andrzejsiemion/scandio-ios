import UIKit

@Observable
@MainActor
final class BrightnessManager {
    static let shared = BrightnessManager()

    private var savedBrightness: CGFloat?

    func activate() {
        let enabled = UserDefaults.standard.object(forKey: DefaultsKey.brightnessEnabled) as? Bool ?? true
        if enabled {
            if savedBrightness == nil {
                savedBrightness = UIScreen.main.brightness
            }
            let level = UserDefaults.standard.object(forKey: DefaultsKey.brightnessLevel) as? Double ?? 1.0
            UIScreen.main.brightness = CGFloat(level)
        }
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func deactivate() {
        if let saved = savedBrightness {
            UIScreen.main.brightness = saved
            savedBrightness = nil
        }
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
