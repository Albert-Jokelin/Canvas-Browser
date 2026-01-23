import SwiftUI

@main
struct CanvasBrowserApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var windowManager = WindowManager.shared
    @StateObject private var shortcutManager = ShortcutManager.shared
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(windowManager)
                .environmentObject(appState)
                .environmentObject(shortcutManager)
                .onAppear {
                    appDelegate.setup(aiOrchestrator: appState.aiOrchestrator)
                }
                .frame(minWidth: WindowManager.WindowSize.minWidth, minHeight: WindowManager.WindowSize.minHeight)
        }
        .windowStyle(.titleBar)
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

