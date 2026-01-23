import SwiftUI

struct CardGridView: View {
    let items: [CardItem]
    @State private var hoveredCard: UUID?

    let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 320), spacing: CanvasSpacing.xl)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: CanvasSpacing.xl) {
                ForEach(items) { item in
                    CardItemView(
                        item: item,
                        isHovered: hoveredCard == item.id
                    )
                    .onHover { isHovered in
                        withAnimation(.easeOut(duration: 0.2)) {
                            hoveredCard = isHovered ? item.id : nil
                        }
                    }
                }
            }
            .padding(CanvasSpacing.xxl)
        }
        .background(Color.canvasBackground)
    }
}

struct CardItemView: View {
    let item: CardItem
    let isHovered: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CanvasSpacing.md) {
            // Image Placeholder with Apple gradient (indigo to teal)
            ZStack {
                RoundedRectangle(cornerRadius: CanvasRadius.medium)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.canvasIndigo.opacity(0.1),
                                Color.canvasTeal.opacity(0.1),
                                Color.canvasCyan.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let imageURL = item.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                                .foregroundColor(.canvasSecondaryLabel.opacity(0.5))
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.canvasGreen.opacity(0.6), .canvasMint.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .aspectRatio(1.6, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: CanvasRadius.medium))

            VStack(alignment: .leading, spacing: CanvasSpacing.sm) {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.canvasLabel)

                Text(item.description)
                    .font(.system(size: 13))
                    .foregroundColor(.canvasSecondaryLabel)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button(action: {}) {
                HStack {
                    Text(item.actionTitle)
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: CanvasSymbols.forward)
                        .font(.system(size: 11, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.canvasBlue)
            .controlSize(.regular)
        }
        .padding(CanvasSpacing.lg)
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
                .stroke(
                    isHovered
                        ? Color.canvasBlue.opacity(0.3)
                        : Color.canvasLabel.opacity(0.05),
                    lineWidth: 1
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
}
