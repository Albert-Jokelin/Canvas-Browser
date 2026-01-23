import SwiftUI
import MapKit

struct MapView: View {
    let locations: [LocationItem]

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            ForEach(locations) { location in
                Annotation(location.title, coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)) {
                    VStack(spacing: 4) {
                        Text(location.icon)
                            .font(.title)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color(NSColor.controlBackgroundColor))
                                    .shadow(color: Color.primary.opacity(0.1), radius: 4)
                            )
                        Text(location.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.9))
                            )
                    }
                }
            }
        }
        .mapStyle(.standard)
        .onAppear {
            if let first = locations.first {
                position = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                ))
            }
        }
    }
}
