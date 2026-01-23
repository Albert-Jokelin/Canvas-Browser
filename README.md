# Canvas Browser

A native macOS intelligent browser with AI-powered features, built with Swift 6.0 and SwiftUI.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Split-Screen Browsing** - Web browser with integrated AI chat panel
- **AI Chat** - Powered by Google Gemini and Anthropic Claude
- **GenTabs** - AI-generated interactive content (card grids, maps, 3D views)
- **Dark Mode** - Full support for macOS light and dark themes
- **Menu Bar Access** - Quick AI access via Cmd+Shift+K
- **Native Performance** - Built with Swift and WebKit for optimal macOS experience

## Screenshots

| Empty State | Browser with Chat | GenTabs |
|-------------|-------------------|---------|
| Beautiful onboarding | Split-screen layout | AI-generated content |

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+ (for development)
- Swift 5.9+

## Quick Start

### Build & Run

```bash
# Clone the repository
git clone https://github.com/yourusername/Canvas.git
cd Canvas

# Build and run (with tests)
./bundle_and_run.sh

# Or manually
swift test && swift build
open CanvasBrowser.app
```

### Build Options

```bash
# Skip tests for faster iteration
./bundle_and_run.sh --skip-tests

# Build only (don't launch)
./bundle_and_run.sh --no-launch

# Release build
./bundle_and_run.sh --release
```

## Configuration

### AI Setup

1. Open Canvas Browser
2. Go to **Settings** (Cmd+,) > **AI Features**
3. Choose your AI provider:
   - **Google Gemini**: Get key from [AI Studio](https://aistudio.google.com/app/apikey)
   - **Anthropic Claude**: Get key from [Console](https://console.anthropic.com/)
4. Enter your API key and select a model

## Architecture

```
Canvas/
├── CanvasBrowser/          # Main app source
│   ├── App/                # App lifecycle & state
│   ├── Models/             # Data structures
│   ├── Views/              # SwiftUI views
│   ├── Services/           # AI & web services
│   └── Persistence/        # CoreData storage
├── Tests/                  # Unit tests
├── Package.swift           # SPM configuration
└── bundle_and_run.sh       # Build script
```

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| New Tab | Cmd+T |
| Close Tab | Cmd+W |
| Toggle AI Menu | Cmd+Shift+K |
| Reload Page | Cmd+R |
| Settings | Cmd+, |

## Development

### Running Tests

```bash
swift test
```

### Project Structure

See [claude.md](claude.md) for detailed architecture documentation and coding standards.

### CI/CD

The project includes GitHub Actions workflows for:
- Automated testing on pull requests
- Release builds on main branch pushes
- DMG artifact generation

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Run tests (`swift test`)
4. Commit your changes
5. Push to the branch
6. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Built with [Swift](https://swift.org) and [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- AI powered by [Google Gemini](https://ai.google.dev/) and [Anthropic Claude](https://anthropic.com)
- WebKit for browser rendering
