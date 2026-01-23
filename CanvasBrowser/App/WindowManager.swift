import SwiftUI
import Combine

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    @Published var activeWindow: WindowCoordinator?
    var windows: [UUID: WindowCoordinator] = [:]

    struct WindowSize {
        static let defaultWidth: CGFloat = 1400
        static let defaultHeight: CGFloat = 900
        static let minWidth: CGFloat = 1024
        static let minHeight: CGFloat = 768
    }

    func register(_ coordinator: WindowCoordinator) {
        windows[coordinator.id] = coordinator
        activeWindow = coordinator
    }
    
    func unregister(_ coordinator: WindowCoordinator) {
        windows.removeValue(forKey: coordinator.id)
        if activeWindow?.id == coordinator.id {
            activeWindow = windows.values.first
        }
    }
}

class WindowCoordinator: ObservableObject, Identifiable {
    let id = UUID()
    
    @Published var activeTabId: UUID?
    
    func newTab() {
        print("New tab requested for window \(id)")
        // Logic to add a tab to the session
    }
}
