import SwiftUI

/// A toast notification view that displays a brief message with an icon
struct ToastView: View {
    let message: String
    let icon: String
    var style: ToastStyle = .info

    enum ToastStyle {
        case info
        case success
        case warning
        case error

        var iconColor: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(style.iconColor)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

/// A view modifier to display toast notifications
struct ToastModifier: ViewModifier {
    @Binding var toast: ToastData?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast = toast {
                    ToastView(
                        message: toast.message,
                        icon: toast.icon,
                        style: toast.style
                    )
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: toast != nil)
    }
}

/// Data structure for toast notifications
struct ToastData: Equatable {
    let id = UUID()
    let message: String
    let icon: String
    var style: ToastView.ToastStyle = .success
    var duration: Double = 2.0

    static func == (lhs: ToastData, rhs: ToastData) -> Bool {
        lhs.id == rhs.id
    }
}

extension View {
    func toast(_ toast: Binding<ToastData?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}

/// Manager for handling toast notifications across the app
class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var currentToast: ToastData?
    private var dismissTask: Task<Void, Never>?

    func show(_ toast: ToastData) {
        dismissTask?.cancel()

        withAnimation {
            currentToast = toast
        }

        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(toast.duration * 1_000_000_000))
            if !Task.isCancelled {
                withAnimation {
                    self.currentToast = nil
                }
            }
        }
    }

    func showBookmarkAdded() {
        show(ToastData(
            message: "Bookmark added",
            icon: "bookmark.fill",
            style: .success
        ))
    }

    func showReadingListAdded() {
        show(ToastData(
            message: "Added to Reading List",
            icon: "eyeglasses",
            style: .success
        ))
    }

    func showBookmarkRemoved() {
        show(ToastData(
            message: "Bookmark removed",
            icon: "bookmark.slash",
            style: .info
        ))
    }
}
