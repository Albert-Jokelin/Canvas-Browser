import SwiftUI
import AppKit

class MenuBarController: ObservableObject {
    @ObservedObject var aiOrchestrator: AIOrchestrator
    private var popover: NSPopover?
    
    init(aiOrchestrator: AIOrchestrator) {
        self.aiOrchestrator = aiOrchestrator
        setupPopover()
    }
    
    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 800, height: 600)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContentView(orchestrator: aiOrchestrator)
        )
        self.popover = popover
    }
    
    func showMenu() {
        guard let appDelegate = NSApp.delegate as? AppDelegate,
              let statusButton = appDelegate.statusItem?.button,
              let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: statusButton.bounds, of: statusButton, preferredEdge: .minY)
        }
    }
}
