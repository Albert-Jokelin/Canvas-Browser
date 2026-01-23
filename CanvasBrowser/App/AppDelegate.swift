import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var menuBarController: MenuBarController?
    var aiOrchestrator: AIOrchestrator?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // We need access to the orchestrator created in AppState
        // This will be injected via `CanvasBrowserApp` ideally, but efficient access 
        // in AppDelegate often requires a shared instance or injection pattern.
        // For simplicity in this structure, we'll initialize if not set, but `CanvasBrowserApp` will likely set it.
    }
    
    func setup(aiOrchestrator: AIOrchestrator) {
        self.aiOrchestrator = aiOrchestrator
        self.menuBarController = MenuBarController(aiOrchestrator: aiOrchestrator)
        
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Canvas AI")
            button.action = #selector(toggleMenu)
            button.target = self
        }
        
        // Listen for AI intent changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuBarTitle),
            name: .aiIntentDetected,
            object: nil
        )
    }
    
    @objc func updateMenuBarTitle(_ notification: Notification) {
        guard let button = statusItem?.button,
              let intent = notification.object as? SemanticIntent else { return }
        
        button.title = intent.shortDescription
        button.image = NSImage(systemSymbolName: intent.icon, accessibilityDescription: nil)
    }
    
    @objc func toggleMenu() {
        menuBarController?.showMenu()
    }
}

extension Notification.Name {
    static let aiIntentDetected = Notification.Name("aiIntentDetected")
}
