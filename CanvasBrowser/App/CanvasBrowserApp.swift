import SwiftUI

@main
struct CanvasBrowserApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var windowManager = WindowManager.shared
    @StateObject private var shortcutManager = ShortcutManager.shared
    @AppStorage("theme") private var theme = "System"
    let persistenceController = PersistenceController.shared

    private var colorScheme: ColorScheme? {
        switch theme {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil  // System default
        }
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(windowManager)
                .environmentObject(appState)
                .environmentObject(shortcutManager)
                .preferredColorScheme(colorScheme)
                .onAppear {
                    appDelegate.setup(aiOrchestrator: appState.aiOrchestrator)
                }
                .frame(minWidth: WindowManager.WindowSize.minWidth, minHeight: WindowManager.WindowSize.minHeight)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            SidebarCommands()
            CanvasCommands()
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

// Window accessor helper to set initial frame if needed (though .frame on Content usually works for swiftui lifecycle)

