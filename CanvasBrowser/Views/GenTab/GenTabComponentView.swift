import SwiftUI
import MapKit

/// Renders a single GenTab component dynamically
struct GenTabComponentView: View {
    let component: GenTabComponent

    var body: some View {
        switch component {
        case .header(let text):
            HeaderComponentView(text: text)

        case .paragraph(let text):
            ParagraphComponentView(text: text)

        case .bulletList(let items):
            BulletListComponentView(items: items)

        case .numberedList(let items):
            NumberedListComponentView(items: items)

        case .table(let columns, let rows):
            TableComponentView(columns: columns, rows: rows)

        case .cardGrid(let cards):
            CardGridComponentView(cards: cards)

        case .map(let locations):
            MapComponentView(locations: locations)

        case .keyValue(let pairs):
            KeyValueComponentView(pairs: pairs)

        case .callout(let type, let text):
            CalloutComponentView(type: type, text: text)

        case .divider:
            DividerComponentView()

        case .link(let title, let url):
            LinkComponentView(title: title, url: url)

        case .image(let url, let caption):
            ImageComponentView(url: url, caption: caption)
        }
    }
}

// MARK: - Header Component

struct HeaderComponentView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Paragraph Component

struct ParagraphComponentView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Bullet List Component

struct BulletListComponentView: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(item)
                        .foregroundColor(.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Numbered List Component

struct NumberedListComponentView: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .foregroundColor(.secondary)
                        .frame(width: 24, alignment: .trailing)
                    Text(item)
                        .foregroundColor(.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Table Component

struct TableComponentView: View {
    let columns: [String]
    let rows: [[String]]

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                ForEach(columns, id: \.self) { column in
                    Text(column)
                        .font(.headline)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                }
            }
            .border(Color.secondary.opacity(0.2), width: 1)

            // Data rows
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                        Text(cell)
                            .font(.body)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(rowIndex % 2 == 0 ? Color.clear : Color(NSColor.controlBackgroundColor).opacity(0.5))
                    }
                }
                .border(Color.secondary.opacity(0.1), width: 0.5)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Card Grid Component

struct CardGridComponentView: View {
    let cards: [GenTabComponent.CardData]
    @State private var hoveredCard: String?

    let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 320), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(cards, id: \.title) { card in
                CardComponentView(card: card, isHovered: hoveredCard == card.title)
                    .onHover { isHovered in
                        withAnimation(.easeOut(duration: 0.2)) {
                            hoveredCard = isHovered ? card.title : nil
                        }
                    }
            }
        }
    }
}

struct CardComponentView: View {
    let card: GenTabComponent.CardData
    let isHovered: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let imageURL = card.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                    }
                } else {
                    Image(systemName: "square.grid.2x2")
                        .font(.largeTitle)
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                if let subtitle = card.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }

                if let description = card.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }

            Spacer(minLength: 0)

            // Action button
            if let actionTitle = card.metadata?["actionTitle"] {
                Button(action: {
                    if let sourceURL = card.sourceURL, let url = URL(string: sourceURL) {
                        NotificationCenter.default.post(
                            name: .createNewTabWithURL,
                            object: nil,
                            userInfo: ["url": url]
                        )
                    }
                }) {
                    HStack {
                        Text(actionTitle)
                        Image(systemName: "arrow.right")
                    }
                    .font(.caption.weight(.medium))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(isHovered ? 0.15 : 0.05), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
}

// MARK: - Map Component

struct MapComponentView: View {
    let locations: [GenTabComponent.LocationData]

    @State private var region: MKCoordinateRegion

    init(locations: [GenTabComponent.LocationData]) {
        self.locations = locations

        // Initialize region based on first location or default
        if let first = locations.first {
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            ))
        } else {
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            ))
        }
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: locations.map { MapLocation(data: $0) }) { location in
            MapAnnotation(coordinate: location.coordinate) {
                VStack {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                    Text(location.title)
                        .font(.caption)
                        .padding(4)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(4)
                }
            }
        }
        .frame(height: 300)
        .cornerRadius(12)
    }
}

struct MapLocation: Identifiable {
    let id = UUID()
    let title: String
    let coordinate: CLLocationCoordinate2D

    init(data: GenTabComponent.LocationData) {
        self.title = data.title
        self.coordinate = CLLocationCoordinate2D(latitude: data.latitude, longitude: data.longitude)
    }
}

// MARK: - Key-Value Component

struct KeyValueComponentView: View {
    let pairs: [GenTabComponent.KeyValuePair]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(pairs, id: \.key) { pair in
                HStack {
                    Text(pair.key)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(pair.value)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Callout Component

struct CalloutComponentView: View {
    let type: GenTabComponent.CalloutType
    let text: String

    var icon: String {
        switch type {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .tip: return "lightbulb.fill"
        case .price: return "tag.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch type {
        case .info: return .blue
        case .warning: return .orange
        case .tip: return .yellow
        case .price: return .green
        case .success: return .green
        case .error: return .red
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Divider Component

struct DividerComponentView: View {
    var body: some View {
        Divider()
            .padding(.vertical, 8)
    }
}

// MARK: - Link Component

struct LinkComponentView: View {
    let title: String
    let url: String

    var body: some View {
        Button(action: {
            if url != "#", let linkURL = URL(string: url) {
                NotificationCenter.default.post(
                    name: .createNewTabWithURL,
                    object: nil,
                    userInfo: ["url": linkURL]
                )
            }
        }) {
            HStack {
                Image(systemName: "link")
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right")
            }
            .font(.subheadline)
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .foregroundColor(.blue)
    }
}

// MARK: - Image Component

struct ImageComponentView: View {
    let url: String
    let caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(8)
                    case .failure:
                        HStack {
                            Image(systemName: "photo")
                            Text("Failed to load image")
                        }
                        .foregroundColor(.secondary)
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    default:
                        ProgressView()
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            if let caption = caption {
                Text(caption)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}
