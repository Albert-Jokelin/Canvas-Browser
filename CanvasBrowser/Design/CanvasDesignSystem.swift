import SwiftUI
import AppKit

// MARK: - Apple Official Color Scheme (NO PURPLE)

extension Color {
    // PRIMARY COLORS (Apple Official)
    static let canvasBlue = Color(nsColor: .systemBlue)           // #007AFF - Primary actions
    static let canvasTeal = Color(nsColor: .systemTeal)           // #5AC8FA - Secondary actions
    static let canvasIndigo = Color(nsColor: .systemIndigo)       // #5856D6 - Tertiary
    static let canvasGreen = Color(nsColor: .systemGreen)         // #34C759 - Success
    static let canvasOrange = Color(nsColor: .systemOrange)       // #FF9500 - Warnings
    static let canvasRed = Color(nsColor: .systemRed)             // #FF3B30 - Destructive
    static let canvasPink = Color(nsColor: .systemPink)           // #FF2D55 - Accent
    static let canvasCyan = Color(nsColor: .systemCyan)           // #32D74B - Fresh
    static let canvasMint = Color(nsColor: .systemMint)           // #00C7BE - Highlight

    // SEMANTIC BACKGROUNDS (Auto dark mode)
    static let canvasBackground = Color(nsColor: .windowBackgroundColor)
    static let canvasSecondaryBackground = Color(nsColor: .controlBackgroundColor)
    static let canvasTertiaryBackground = Color(nsColor: .textBackgroundColor)
    static let canvasGroupedBackground = Color(nsColor: .underPageBackgroundColor)

    // LABELS (Auto dark mode)
    static let canvasLabel = Color(nsColor: .labelColor)
    static let canvasSecondaryLabel = Color(nsColor: .secondaryLabelColor)
    static let canvasTertiaryLabel = Color(nsColor: .tertiaryLabelColor)
    static let canvasQuaternaryLabel = Color(nsColor: .quaternaryLabelColor)

    // FILLS
    static let canvasFill = Color(nsColor: .controlColor)
    static let canvasSecondaryFill = Color(nsColor: .controlBackgroundColor)

    // SPECIAL
    static let canvasDivider = Color(nsColor: .separatorColor)
    static let canvasSelection = Color(nsColor: .selectedContentBackgroundColor)

    // AI-SPECIFIC (Using Apple colors - indigo/teal gradient instead of purple)
    static let canvasAIAccent = Color(nsColor: .systemTeal)
    static let canvasAIGradientStart = Color(nsColor: .systemIndigo)
    static let canvasAIGradientEnd = Color(nsColor: .systemTeal)
}

// MARK: - AI Gradient

struct CanvasAIGradient: View {
    var body: some View {
        LinearGradient(
            colors: [.canvasAIGradientStart, .canvasAIGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Design Tokens

enum CanvasRadius {
    static let small: CGFloat = 6
    static let medium: CGFloat = 10
    static let large: CGFloat = 16
    static let extraLarge: CGFloat = 20
}

enum CanvasSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

enum CanvasShadow {
    static let small = (color: Color.black.opacity(0.05), radius: CGFloat(4), y: CGFloat(2))
    static let medium = (color: Color.black.opacity(0.08), radius: CGFloat(8), y: CGFloat(4))
    static let large = (color: Color.black.opacity(0.12), radius: CGFloat(16), y: CGFloat(8))
}

// MARK: - SF Symbols

enum CanvasSymbols {
    // Navigation
    static let back = "chevron.left"
    static let forward = "chevron.right"
    static let refresh = "arrow.clockwise"
    static let stop = "xmark"
    static let home = "house.fill"
    static let share = "square.and.arrow.up"

    // Tabs
    static let newTab = "plus"
    static let closeTab = "xmark"
    static let tabOverview = "square.stack"
    static let privateTab = "eye.slash"

    // AI Features
    static let aiSpark = "sparkles"
    static let aiChat = "bubble.left.and.text.bubble.right.fill"
    static let aiGenerate = "wand.and.stars"
    static let aiIntent = "brain.head.profile"
    static let aiAnalyze = "doc.text.magnifyingglass"

    // GenTabs
    static let genTab = "rectangle.stack.badge.plus"
    static let detach = "arrow.up.right.square"
    static let genTabPlanner = "calendar.badge.plus"
    static let genTabComparison = "tablecells"
    static let genTabTracker = "chart.line.uptrend.xyaxis"
    static let genTabMap = "map.fill"
    static let genTabCards = "square.grid.2x2.fill"

    // Safari Features
    static let bookmarks = "book.fill"
    static let readingList = "eyeglasses"
    static let downloads = "arrow.down.circle.fill"
    static let history = "clock.fill"
    static let passwords = "key.fill"
    static let extensions = "puzzlepiece.extension.fill"
    static let readerMode = "doc.plaintext"
    static let findInPage = "doc.text.magnifyingglass"

    // Window Management
    static let sidebar = "sidebar.left"
    static let splitView = "rectangle.split.2x1"
    static let fullscreen = "arrow.up.left.and.arrow.down.right"
    static let minimize = "minus"
    static let zoom = "arrow.up.left.and.down.right.magnifyingglass"

    // Settings
    static let settings = "gear"
    static let privacy = "hand.raised.fill"
    static let security = "lock.shield.fill"
    static let appearance = "paintbrush.fill"

    // Actions
    static let search = "magnifyingglass"
    static let delete = "trash"
    static let edit = "pencil"
    static let add = "plus"
    static let close = "xmark.circle.fill"
    static let info = "info.circle"
    static let warning = "exclamationmark.triangle.fill"
    static let success = "checkmark.circle.fill"
}

// MARK: - Visual Effect View (Vibrancy)

struct CanvasVisualEffect: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    init(material: NSVisualEffectView.Material = .sidebar, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Button Styles

struct CanvasPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, CanvasSpacing.lg)
            .padding(.vertical, CanvasSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CanvasRadius.medium)
                    .fill(Color.canvasBlue)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CanvasSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.canvasLabel)
            .padding(.horizontal, CanvasSpacing.lg)
            .padding(.vertical, CanvasSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CanvasRadius.medium)
                    .fill(Color.canvasSecondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CanvasRadius.medium)
                    .stroke(Color.canvasDivider, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CanvasIconButtonStyle: ButtonStyle {
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(isActive ? .canvasBlue : .canvasSecondaryLabel)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: CanvasRadius.small)
                    .fill(isActive ? Color.canvasBlue.opacity(0.15) : Color.clear)
            )
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Card Style

struct CanvasCardModifier: ViewModifier {
    var isHovered: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: CanvasRadius.large)
                    .fill(Color.canvasSecondaryBackground)
                    .shadow(
                        color: CanvasShadow.medium.color,
                        radius: isHovered ? CanvasShadow.large.radius : CanvasShadow.medium.radius,
                        y: isHovered ? CanvasShadow.large.y : CanvasShadow.medium.y
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: CanvasRadius.large)
                    .stroke(isHovered ? Color.canvasBlue.opacity(0.3) : Color.canvasDivider.opacity(0.5), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
}

extension View {
    func canvasCard(isHovered: Bool = false) -> some View {
        modifier(CanvasCardModifier(isHovered: isHovered))
    }
}

// MARK: - Toolbar Background

struct CanvasToolbarBackground: View {
    var body: some View {
        CanvasVisualEffect(material: .headerView, blendingMode: .withinWindow)
    }
}

// MARK: - Loading Indicator

struct CanvasLoadingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.canvasAIAccent)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear { isAnimating = true }
    }
}

// MARK: - Progress Bar

struct CanvasProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.canvasDivider.opacity(0.3))

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.canvasBlue, .canvasTeal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 2)
        .animation(.linear(duration: 0.2), value: progress)
    }
}
