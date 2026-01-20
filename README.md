# Canvas-Browser
AI Browser for macOS
A beautiful, modern Chromium-based browser that transforms your browsing sessions into interactive, custom web applications using AI.

## Features

- 🌐 **Split-Screen Browser** - Chat on the left, web browsing on the right
- 🤖 **AI Chat Interface** - Natural language interaction powered by Claude
- ✨ **GenTabs** - AI-generated interactive React applications based on your browsing context
- 🔗 **Source Attribution** - Every generated element links back to original sources
- 💾 **Local Persistence** - All data stored locally in SQLite
- 🌙 **Light/Dark Mode** - Beautiful Google-style theming

## Tech Stack

| Component | Technology |
|-----------|------------|
| Browser Engine | Chromium (via Electron) |
| UI Framework | React 18 |
| Styling | Tailwind CSS |
| AI | Claude API (Anthropic) |
| Database | SQLite (better-sqlite3) |
| Build | Vite + electron-builder |

## Prerequisites

- **Node.js 18+** (Required for Electron)
- **Claude API key** from [Anthropic Console](https://console.anthropic.com)

## Installation

```bash
# Clone the repository
git clone <repo-url>
cd canvas-browser

# Install dependencies
npm install

# Run in development
npm run electron:dev
```

## Configuration

1. Open Canvas
2. Go to Settings (⚙️ in title bar)
3. Enter your Claude API key
4. Click "Test Key" to verify

## How It Works

### Browsing
- Type a URL in the chat input to navigate
- Browse normally in the right panel
- Canvas extracts page content for AI context

### GenTabs
1. Browse related websites (e.g., 3-4 recipe sites)
2. AI suggests relevant apps (e.g., "Create Meal Planner")
3. Click "Generate" to create an interactive app
4. Refine via natural language: "Add calorie counts"

### Example GenTab Types
- 🗺️ **Trip Planner** - Interactive itinerary with maps
- 🍽️ **Meal Planner** - Weekly calendar with recipes  
- 📊 **Comparison Table** - Side-by-side product analysis
- 📚 **Study Guide** - Flashcards and concept maps

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd/Ctrl + L` | Focus chat input |
| `Cmd/Ctrl + T` | New tab |
| `Cmd/Ctrl + W` | Close tab |
| `Cmd/Ctrl + ,` | Settings |

## Project Structure

```
canvas-browser/
├── src/
│   ├── main/                    # Electron main process
│   │   ├── index.js             # Window, IPC, session
│   │   └── database.js          # SQLite schema
│   ├── renderer/                # React UI
│   │   ├── App.jsx              # Main layout
│   │   ├── components/
│   │   │   ├── TitleBar.jsx     # Window controls
│   │   │   ├── ChatPanel.jsx    # Left: chat + suggestions
│   │   │   ├── RightPanel.jsx   # Container for views
│   │   │   ├── TabBar.jsx       # Tab management
│   │   │   ├── BrowserView.jsx  # WebView wrapper
│   │   │   ├── GenTabView.jsx   # Dynamic component renderer
│   │   │   ├── GenTabLibrary.jsx
│   │   │   └── SettingsPanel.jsx
│   │   ├── context/
│   │   │   └── AppContext.jsx   # Global state
│   │   └── services/
│   │       └── claude.js        # AI API client
│   └── preload/
│       └── index.js             # IPC bridge
├── assets/icons/
├── package.json
├── vite.config.js
└── tailwind.config.js
```

## Building for Production

```bash
npm run build
```

Outputs to `release/` directory.

## License

MIT
