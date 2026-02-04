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
        // Use the shelf controller's status button since we consolidated menu bar icons
        guard let shelfController = MenuBarShelfController.shared.statusButton,
              let popover = popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: shelfController.bounds, of: shelfController, preferredEdge: .minY)
        }
    }
}
