# Canvas Browser - AI Agent Guide

## Project Overview

Canvas Browser is a **native macOS intelligent orchestrator** built with Swift 6.0 and SwiftUI. It combines a modern web browser with AI-powered features including:

- **Split-screen browsing** with integrated AI chat panel
- **GenTabs** - AI-generated interactive content (card grids, maps, 3D views)
- **Semantic intent detection** - Proactive AI suggestions based on browsing context
- **Menu bar AI access** - Quick AI access via Cmd+Shift+K

**Target Platform:** macOS 14.0+ (Sonoma and newer)
**Build System:** Swift Package Manager (SPM)

---

## Architecture

### Directory Structure

```
Canvas/
├── CanvasBrowser/
│   ├── App/                    # Application lifecycle & coordination
│   │   ├── CanvasBrowserApp.swift    # @main entry point
│   │   ├── AppDelegate.swift         # Menu bar & system integration
│   │   ├── AppState.swift            # Central state management
│   │   ├── WindowManager.swift       # Multi-window coordination
│   │   └── MenuBarController.swift   # Menu bar popover controller
│   │
│   ├── Models/                 # Data structures
│   │   ├── BrowsingSession.swift     # Tab management (web + gen tabs)
│   │   ├── GenTab.swift              # Generated tab definitions
│   │   ├── SemanticIntent.swift      # AI intent detection structures
│   │   └── UserAccount.swift         # User profile & sync settings
│   │
│   ├── Views/                  # SwiftUI views
│   │   ├── MainWindowView.swift      # Root 3-column layout
│   │   ├── ChatPanelView.swift       # AI chat interface
│   │   ├── BrowserPanelView.swift    # Web browser container
│   │   ├── BrowserToolbar.swift      # Navigation controls
│   │   ├── SidebarRail.swift         # Navigation rail
│   │   ├── EmptyStateView.swift      # Empty state UI
│   │   ├── Settings/
│   │   │   └── SettingsView.swift    # App preferences
│   │   ├── MenuBar/
│   │   │   └── MenuBarContentView.swift
│   │   └── GenTab/
│   │       ├── GenTabView.swift
│   │       ├── CardGridView.swift
│   │       ├── MapView.swift
│   │       └── GenTabToolbar.swift
│   │
│   ├── Services/               # Business logic
│   │   ├── AIOrchestrator.swift      # Intent detection & action management
│   │   ├── ClaudeService.swift       # Claude API integration
│   │   ├── GeminiService.swift       # Gemini API integration
│   │   ├── HistoryManager.swift      # Browsing history (CoreData)
│   │   └── WebViewCoordinator.swift  # WKWebView management
│   │
│   ├── Persistence/            # Data storage
│   │   ├── CoreDataStack.swift       # CoreData initialization
│   │   └── CoreDataModel.swift       # CoreData schema (HistoryEntry)
│   │
│   └── Resources/
│       ├── Info.plist
│       └── Entitlements.entitlements
│
├── Tests/                      # Unit & integration tests
│   └── CanvasBrowserTests/
│
├── Package.swift               # SPM configuration
├── bundle_and_run.sh           # Build & run script
└── claude.md                   # This file
```

### Data Flow

```
CanvasBrowserApp (@main)
    └─ AppState (ObservableObject - central state)
        ├─ BrowsingSession
        │   └─ [TabItem: .web(WebTab) | .gen(GenTab)]
        └─ AIOrchestrator
            ├─ ClaudeService (API integration)
            ├─ GeminiService (API integration)
            └─ HistoryManager (CoreData)
```

### UI Layout

```
┌─────────────────────────────────────────┐
│ ┌────┬─────────────┬───────────────────┐│
│ │    │ Chat Panel  │                   ││
│ │ R  │ (togglable) │  Browser/GenTab   ││
│ │ A  │  350px      │  Content Area     ││
│ │ I  │             │                   ││
│ │ L  │             │                   ││
│ │    │             │                   ││
│ │60px│             │                   ││
│ └────┴─────────────┴───────────────────┘│
└─────────────────────────────────────────┘
```

---

## Development Phases

### Phase 1 - Foundation (Current)
- [x] Native macOS app with SwiftUI
- [x] WKWebView-based browser
- [x] Tab management (web tabs + gen tabs)
- [x] AI chat panel with Gemini integration
- [x] GenTab visualization (card grids, maps)
- [x] CoreData history persistence
- [x] Menu bar quick access
- [x] Settings preferences

### Phase 2 - AI Enhancement (Next)
- [ ] Full Claude API integration
- [ ] Semantic intent detection from browsing context
- [ ] Proactive AI suggestions
- [ ] GenTab generation from natural language
- [ ] Context-aware chat (page content analysis)

### Phase 3 - Advanced Features
- [ ] Multi-window support
- [ ] Tab sync across devices
- [ ] Custom GenTab templates
- [ ] Plugin/extension system
- [ ] Keyboard-driven navigation

---

## Build & Run

### Prerequisites
- macOS 14.0+ (Sonoma)
- Xcode 15+ (for Swift 5.9+ toolchain)
- Swift Package Manager

### Quick Start

```bash
# Build and run (development)
./bundle_and_run.sh

# Or manual build
swift build
swift run CanvasBrowser

# Run tests
swift test
```

### Build Script Details

The `bundle_and_run.sh` script:
1. Runs `swift test` to verify all tests pass
2. Runs `swift build` to compile the executable
3. Creates `CanvasBrowser.app` bundle structure
4. Copies executable and Info.plist
5. Ad-hoc code signs with entitlements
6. Launches the app

---

## Coding Standards

### SwiftUI Views
- Use `@EnvironmentObject` for shared state (AppState, WindowManager)
- Use `@StateObject` for view-owned observable objects
- Use `@State` for local view state
- Prefer `Color(NSColor.*)` over hardcoded colors for dark mode support
- Use SF Symbols for icons

### Services
- Make services `ObservableObject` when UI needs to observe changes
- Use `async/await` for network calls
- Store API keys in UserDefaults via `@AppStorage`
- Handle errors gracefully with user-friendly messages

### Models
- Use `Codable` for serialization
- Use `Identifiable` for ForEach compatibility
- Prefer `struct` over `class` unless reference semantics needed

### Testing
- Unit tests for models and services
- Use `XCTest` framework
- Test file naming: `*Tests.swift`
- Aim for >80% coverage on business logic

---

## API Configuration

### Gemini API
1. Get API key from: https://aistudio.google.com/app/apikey
2. Enter in Settings > AI Features > Gemini API Key
3. Click "Get Models" to fetch available models

### Claude API
1. Get API key from: https://console.anthropic.com/
2. Enter in Settings > AI Features > Claude API Key
3. Select preferred model (claude-3-sonnet, claude-3-opus, etc.)

---

## Key Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| New Tab | Cmd+T |
| Toggle AI Menu | Cmd+Shift+K |
| Settings | Cmd+, |
| Close Tab | Cmd+W |

---

## Common Tasks

### Adding a New View
1. Create `.swift` file in `CanvasBrowser/Views/`
2. Import SwiftUI
3. Use `@EnvironmentObject var appState: AppState` if needed
4. Add to appropriate parent view

### Adding a New Service
1. Create `.swift` file in `CanvasBrowser/Services/`
2. Make it `ObservableObject` if UI observes it
3. Initialize in `AppState.init()` if app-wide
4. Inject via `@EnvironmentObject` or direct reference

### Adding a New GenTab Type
1. Add case to `GenTabContentType` enum in `GenTab.swift`
2. Add corresponding data properties to `GenTab` struct
3. Add view case in `GenTabView.swift` switch statement
4. Create view in `Views/GenTab/`

---

## Troubleshooting

### App won't launch
- Ensure macOS 14.0+
- Check code signing: `codesign -dv CanvasBrowser.app`
- Verify entitlements are applied

### WebView not loading
- Check network entitlements in Entitlements.entitlements
- Verify NSAppTransportSecurity allows loads in Info.plist

### AI not responding
- Verify API key is set in Settings
- Check network connectivity
- Review console for API errors

---

## Contributing

1. Create feature branch from `main`
2. Write tests for new functionality
3. Ensure `swift test` passes
4. Follow coding standards above
5. Submit PR with clear description
