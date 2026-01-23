import SwiftUI

struct EmptyStateView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: CanvasSpacing.xxxl) {
            Spacer()

            // Animated logo with Apple gradient (indigo to teal)
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.canvasIndigo.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)
                    .scaleEffect(isAnimating ? 1.1 : 0.9)

                // Logo icon
                Image(systemName: CanvasSymbols.aiSpark)
                    .resizable()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.canvasIndigo, .canvasBlue, .canvasTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(isAnimating ? 5 : -5))
            }
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)

            VStack(spacing: CanvasSpacing.sm) {
                Text("Canvas")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.canvasLabel, .canvasLabel.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Your AI-powered browser")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.canvasSecondaryLabel)
            }

            // Large search input with modern styling
            HStack(spacing: CanvasSpacing.md) {
                Image(systemName: CanvasSymbols.search)
                    .foregroundColor(.canvasSecondaryLabel)
                    .font(.system(size: 16, weight: .medium))

                TextField("Search the web or ask AI anything...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($isSearchFocused)
                    .onSubmit {
                        handleSearch()
                    }

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: CanvasSymbols.close)
                            .foregroundColor(.canvasSecondaryLabel)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, CanvasSpacing.xl)
            .padding(.vertical, 14)
            .frame(maxWidth: 560)
            .background(
                RoundedRectangle(cornerRadius: CanvasRadius.large)
                    .fill(Color.canvasSecondaryBackground)
                    .shadow(color: CanvasShadow.medium.color, radius: CanvasShadow.medium.radius, y: CanvasShadow.medium.y)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CanvasRadius.large)
                    .stroke(Color.canvasDivider.opacity(0.5), lineWidth: 1)
            )

            // Quick action hints
            HStack(spacing: CanvasSpacing.xxl) {
                QuickActionHint(icon: "globe", text: "Browse the web")
                QuickActionHint(icon: CanvasSymbols.aiSpark, text: "Ask AI")
                QuickActionHint(icon: CanvasSymbols.genTabCards, text: "Create GenTab")
            }
            .padding(.top, CanvasSpacing.sm)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color.canvasBackground

                // Subtle gradient overlay (Apple colors - indigo/teal instead of purple)
                LinearGradient(
                    colors: [
                        Color.canvasIndigo.opacity(0.03),
                        Color.canvasTeal.opacity(0.02),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .onAppear {
            isSearchFocused = true
            isAnimating = true
        }
    }

    private func handleSearch() {
        guard !searchText.isEmpty else { return }

        let urlString: String
        if searchText.lowercased().hasPrefix("http") {
            urlString = searchText
        } else if searchText.contains(".") && !searchText.contains(" ") {
            urlString = "https://" + searchText
        } else {
            urlString = "https://www.google.com/search?q=" + (searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchText)
        }

        if let url = URL(string: urlString) {
            appState.sessionManager.addTab(url: url)
        }
    }
}

struct QuickActionHint: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: CanvasSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.canvasSecondaryLabel)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.canvasSecondaryLabel)
        }
        .padding(.horizontal, CanvasSpacing.md)
        .padding(.vertical, CanvasSpacing.sm)
        .background(
            Capsule()
                .fill(Color.canvasSecondaryBackground.opacity(0.5))
        )
    }
}
