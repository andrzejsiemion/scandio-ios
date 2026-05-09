import SwiftUI
import SwiftData

@main
struct ScandioApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue

    private var appTheme: AppTheme {
        AppTheme(rawValue: appThemeRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            CardListView()
                .task(id: appThemeRaw) {
                    appTheme.apply()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        BrightnessManager.shared.deactivate()
                    } else if newPhase == .active {
                        appTheme.apply()
                    }
                }
        }
        .modelContainer(for: LoyaltyCard.self)
    }
}
