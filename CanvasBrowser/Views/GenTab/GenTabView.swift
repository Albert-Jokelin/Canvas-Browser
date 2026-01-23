import SwiftUI

struct GenTabView: View {
    let genTab: GenTab
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: genTab.icon)
                    .foregroundColor(.purple)
                Text(genTab.title)
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            // Toolbar
            if !genTab.availableActions.isEmpty {
                GenTabToolbar(actions: genTab.availableActions)
            }
            
            // Content
            Group {
                switch genTab.contentType {
                case .cardGrid:
                    CardGridView(items: genTab.items)
                case .map:
                    MapView(locations: genTab.locations)
                case .dashboard:
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text("Dashboard Overview")
                                .font(.headline)
                                .padding()
                            CardGridView(items: genTab.items)
                        }
                    }
                default:
                    Text("Unknown Content Type")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}
