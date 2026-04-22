# Contributing to Canvas Browser

Thank you for your interest in contributing! Canvas Browser is an open source native macOS browser and we welcome contributions of all kinds.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Submitting Changes](#submitting-changes)
- [Issue Labels](#issue-labels)

---

## Code of Conduct

This project follows our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold it. Please report unacceptable behavior to the maintainers.

---

## Getting Started

1. **Browse open issues** — look for issues tagged [`good first issue`](https://github.com/Albert-Jokelin/Canvas-Browser/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22) or [`help wanted`](https://github.com/Albert-Jokelin/Canvas-Browser/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22)
2. **Comment on an issue** before starting work to avoid duplicate effort
3. **Fork the repo** and create a branch from `main`

---

## How to Contribute

### Reporting Bugs
Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md). Include:
- macOS version
- Steps to reproduce
- Expected vs actual behavior
- Console logs if relevant

### Suggesting Features
Use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.md). Check existing issues first to avoid duplicates.

### Asking Questions
Use [GitHub Discussions](https://github.com/Albert-Jokelin/Canvas-Browser/discussions) for questions — not issues.

### Submitting Code
See [Submitting Changes](#submitting-changes) below.

---

## Development Setup

### Prerequisites
- macOS 14.0+ (Sonoma)
- Xcode 15+ (for Swift toolchain)
- Swift 5.9+

### Build & Run

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/Canvas-Browser.git
cd Canvas-Browser

# Build and run (runs tests first)
./bundle_and_run.sh

# Skip tests for faster iteration
./bundle_and_run.sh --skip-tests

# Run tests only
swift test
```

### AI API Keys (optional for development)
Some features require API keys. Set them in **Settings > AI Features** after launching:
- [Google Gemini](https://aistudio.google.com/app/apikey) — for AI chat
- [Anthropic Claude](https://console.anthropic.com/) — for Claude integration

You can develop and test UI features without API keys.

---

## Coding Standards

### Swift / SwiftUI

- Use `@EnvironmentObject` for shared state, `@StateObject` for view-owned objects, `@State` for local state
- Use `async/await` for all async operations — no completion handlers
- Prefer `struct` over `class` unless reference semantics are required
- Use `Color(NSColor.*)` over hardcoded colors for dark mode support
- Use SF Symbols for all icons

### File Organization

```
CanvasBrowser/
├── App/          # App lifecycle & coordination
├── Models/       # Data structures (Codable, Identifiable)
├── Views/        # SwiftUI views
├── Services/     # Business logic & API integrations
└── Persistence/  # CoreData
```

### Adding a New View
1. Create `.swift` in `CanvasBrowser/Views/`
2. Import SwiftUI
3. Use `@EnvironmentObject var appState: AppState` if needed
4. Add to the appropriate parent view

### Adding a New Service
1. Create `.swift` in `CanvasBrowser/Services/`
2. Mark as `ObservableObject` if the UI needs to observe it
3. Initialize in `AppState.init()` if app-wide
4. Inject via `@EnvironmentObject` or direct reference

### Design System
Use the constants in `CanvasDesignSystem.swift`:
- Colors: `Color.canvasBlue`, `.canvasRed`, etc.
- Spacing: `CanvasSpacing.sm/md/lg/xl`
- Corner radius: `CanvasRadius.small/medium/large`

---

## Submitting Changes

1. **Create a branch** from `main`:
   ```bash
   git checkout -b feature/my-feature
   # or
   git checkout -b fix/issue-123
   ```

2. **Write tests** for new functionality when applicable

3. **Run the test suite**:
   ```bash
   swift test
   ```

4. **Commit** with a clear message:
   ```
   Add content blocker service for ad filtering

   Implements WKContentRuleList-based blocking using EasyList rules.
   Closes #42
   ```

5. **Push and open a PR** against `main`. Fill in the PR template.

6. **Respond to review feedback** — maintainers aim to review within a week.

### PR Requirements
- All CI checks must pass (`swift test`, `swift build`)
- New features should include tests where practical
- Follow the coding standards above
- One logical change per PR — keep diffs focused

---

## Issue Labels

| Label | Meaning |
|-------|---------|
| `good first issue` | Small, well-scoped, great for first-timers |
| `help wanted` | Maintainers want community help |
| `bug` | Something isn't working |
| `enhancement` | New feature or improvement |
| `documentation` | Docs-only change |
| `performance` | Speed or memory improvement |
| `accessibility` | a11y improvements |
| `ai` | AI/ML feature area |
| `ui` | Visual or UX change |
| `in progress` | Someone is actively working on this |

---

## Questions?

Open a [Discussion](https://github.com/Albert-Jokelin/Canvas-Browser/discussions) — we're happy to help.
