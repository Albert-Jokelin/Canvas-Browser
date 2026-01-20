# Canvas Browser - AI Context Document

## Project Overview

Canvas is an AI-powered Chromium browser with a split-screen interface: chat on the left, web browsing on the right. It generates interactive "GenTabs" - React applications based on browsing context.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Title Bar (Canvas)                         │
├────────────────────┬────────────────────────────────────┤
│                    │                                    │
│   CHAT PANEL       │      BROWSER VIEW / GenTab         │
│   (38% width)      │      (62% width)                   │
│                    │                                    │
│  • AI chat         │  • WebView for browsing            │
│  • Suggestions     │  • GenTab renderer                 │
│  • Input (URL/AI)  │  • Tab management                  │
│                    │                                    │
└────────────────────┴────────────────────────────────────┘
```

## Tech Stack

- **Electron 33+** with webviewTag enabled
- **React 18** for UI
- **Tailwind CSS** with Google-style theming
- **SQLite** (better-sqlite3) for persistence
- **Claude API** for AI features
- **Babel Standalone** for dynamic JSX rendering

## Key Files

| File | Purpose |
|------|---------|
| `src/main/index.js` | Electron main process, IPC handlers |
| `src/main/database.js` | SQLite schema (gentabs, chat, history) |
| `src/renderer/App.jsx` | Split layout with ChatPanel + RightPanel |
| `src/renderer/components/ChatPanel.jsx` | AI chat with URL detection |
| `src/renderer/components/BrowserView.jsx` | WebView with content extraction |
| `src/renderer/components/GenTabView.jsx` | Dynamic React component renderer |
| `src/renderer/services/claude.js` | Claude API integration |

## Database Schema

```sql
gentabs (id, name, type, component_code, state, created_at, modified_at)
gentab_sources (gentab_id, url, title, snippet)
chat_history (id, role, content, timestamp, related_gentab_id)
browsing_history (id, url, title, visited_at, content_summary)
settings (key, value)
```

## GenTab Generation Flow

1. User browses 2+ related pages
2. Content extracted via `executeJavaScript` in webview
3. Claude analyzes context → suggests GenTab types
4. User clicks "Generate"
5. Claude produces React component code
6. Babel transforms JSX → rendered in GenTabView
7. User refines via chat → Claude updates code

## IPC Channels

- Window: `window-minimize`, `window-maximize`, `window-close`
- GenTabs: `db-get-gentabs`, `db-save-gentab`, `db-delete-gentab`
- Sources: `db-save-sources`, `db-get-sources`
- Chat: `db-get-chat-history`, `db-add-chat-message`, `db-clear-chat`
- Context: `db-add-page-context`, `db-get-recent-pages`
- Settings: `db-get-setting`, `db-set-setting`

## Requirements

- Node.js 18+ (current system is v12 - UPGRADE REQUIRED)
- Claude API key

## Run Commands

```bash
npm install          # Install deps
npm run electron:dev # Dev mode
npm run build        # Production build
```
