import { app, BrowserWindow, ipcMain, session, Menu, MenuItem } from 'electron'
import path from 'path'
import { fileURLToPath } from 'url'
import { createDatabase, getDatabase } from './database.js'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

let mainWindow = null
const isDev = process.env.NODE_ENV === 'development' || !app.isPackaged

// Disable GPU and Sandbox programmatically to fix AppImage issues
app.commandLine.appendSwitch('no-sandbox')
app.commandLine.appendSwitch('disable-gpu')
app.commandLine.appendSwitch('disable-software-rasterizer')

app.on('web-contents-created', (event, contents) => {
    console.log('WebContents created:', contents.getType())
    if (contents.getType() === 'webview') {
        console.log('WebView created!')
        contents.on('did-start-loading', () => console.log('WebView started loading'))
        contents.on('did-finish-load', () => console.log('WebView finished loading'))
        contents.on('did-navigate', (e, url) => console.log('WebView navigated to:', url))
        contents.on('did-fail-load', (e, errorCode, errorDescription) => {
            console.error('WebView failed to load:', errorCode, errorDescription)
        })
    }
})

function createMainWindow() {
    mainWindow = new BrowserWindow({
        width: 1400,
        height: 900,
        minWidth: 1000,
        minHeight: 700,
        frame: false,
        backgroundColor: '#ffffff',
        webPreferences: {
            preload: path.join(__dirname, '../preload/index.cjs'),
            nodeIntegration: false,
            contextIsolation: true,
            webviewTag: true, // Enable webview tag for browser functionality
            sandbox: false
        },
        show: false
    })

    mainWindow.once('ready-to-show', () => {
        mainWindow.show()
    })

    // Context menu for DevTools
    mainWindow.webContents.on('context-menu', (e, params) => {
        const menu = new Menu()
        menu.append(new MenuItem({ label: 'Inspect Element', click: () => mainWindow.webContents.inspectElement(params.x, params.y) }))
        menu.append(new MenuItem({ type: 'separator' }))
        menu.append(new MenuItem({ label: 'Open Developer Tools', click: () => mainWindow.webContents.openDevTools() }))
        menu.popup()
    })

    if (isDev) {
        mainWindow.loadURL('http://localhost:5173')
        mainWindow.webContents.openDevTools()
    } else {
        mainWindow.loadFile(path.join(__dirname, '../../dist/index.html'))
        mainWindow.webContents.openDevTools() // Open in prod for debugging
    }

    mainWindow.on('closed', () => {
        mainWindow = null
    })

    return mainWindow
}

function setupIPC() {
    const db = getDatabase()

    // Window controls
    ipcMain.on('window-minimize', () => mainWindow?.minimize())
    ipcMain.on('window-maximize', () => {
        if (mainWindow?.isMaximized()) {
            mainWindow.unmaximize()
        } else {
            mainWindow?.maximize()
        }
    })
    ipcMain.on('window-close', () => mainWindow?.close())

    // Database: GenTabs
    ipcMain.handle('db-get-gentabs', () => {
        return db.prepare('SELECT * FROM gentabs ORDER BY modified_at DESC').all()
    })

    ipcMain.handle('db-get-gentab', (_, id) => {
        return db.prepare('SELECT * FROM gentabs WHERE id = ?').get(id)
    })

    ipcMain.handle('db-save-gentab', (_, gentab) => {
        const existing = db.prepare('SELECT id FROM gentabs WHERE id = ?').get(gentab.id)
        if (existing) {
            db.prepare(`
        UPDATE gentabs SET name = ?, type = ?, component_code = ?, component_state = ?, modified_at = ?
        WHERE id = ?
      `).run(gentab.name, gentab.type, gentab.component_code, gentab.component_state || '{}', Date.now(), gentab.id)
        } else {
            db.prepare(`
        INSERT INTO gentabs (id, name, type, component_code, component_state, created_at, modified_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `).run(gentab.id, gentab.name, gentab.type, gentab.component_code, gentab.component_state || '{}', Date.now(), Date.now())
        }
        return gentab
    })

    ipcMain.handle('db-delete-gentab', (_, id) => {
        db.prepare('DELETE FROM gentabs WHERE id = ?').run(id)
        db.prepare('DELETE FROM gentab_sources WHERE gentab_id = ?').run(id)
        return true
    })

    // Database: Sources
    ipcMain.handle('db-save-sources', (_, gentabId, sources) => {
        db.prepare('DELETE FROM gentab_sources WHERE gentab_id = ?').run(gentabId)
        const insert = db.prepare('INSERT INTO gentab_sources (gentab_id, url, title, snippet) VALUES (?, ?, ?, ?)')
        for (const src of sources) {
            insert.run(gentabId, src.url, src.title, src.snippet || '')
        }
        return true
    })

    ipcMain.handle('db-get-sources', (_, gentabId) => {
        return db.prepare('SELECT * FROM gentab_sources WHERE gentab_id = ?').all(gentabId)
    })

    // Database: Chat history
    ipcMain.handle('db-get-chat-history', () => {
        return db.prepare('SELECT * FROM chat_history ORDER BY timestamp ASC LIMIT 100').all()
    })

    ipcMain.handle('db-add-chat-message', (_, msg) => {
        db.prepare(`
      INSERT INTO chat_history (id, role, content, timestamp, related_gentab_id)
      VALUES (?, ?, ?, ?, ?)
    `).run(msg.id, msg.role, msg.content, Date.now(), msg.related_gentab_id || null)
        return msg
    })

    ipcMain.handle('db-clear-chat', () => {
        db.prepare('DELETE FROM chat_history').run()
        return true
    })

    // Database: Browsing history (for context)
    ipcMain.handle('db-add-page-context', (_, page) => {
        db.prepare(`
      INSERT OR REPLACE INTO browsing_history (id, url, title, visited_at, content_summary)
      VALUES (?, ?, ?, ?, ?)
    `).run(page.id, page.url, page.title, Date.now(), page.summary || '')
        return page
    })

    ipcMain.handle('db-get-recent-pages', (_, limit = 10) => {
        return db.prepare('SELECT * FROM browsing_history ORDER BY visited_at DESC LIMIT ?').all(limit)
    })

    // Database: Settings
    ipcMain.handle('db-get-setting', (_, key) => {
        const row = db.prepare('SELECT value FROM settings WHERE key = ?').get(key)
        return row ? row.value : null
    })

    ipcMain.handle('db-set-setting', (_, key, value) => {
        db.prepare(`
      INSERT INTO settings (key, value) VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = ?
    `).run(key, value, value)
        return true
    })
}

// App lifecycle
app.whenReady().then(async () => {
    // Initialize database
    createDatabase()

    // Setup IPC handlers
    setupIPC()

    // Set user agent for webviews
    session.defaultSession.webRequest.onBeforeSendHeaders((details, callback) => {
        details.requestHeaders['User-Agent'] = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        callback({ requestHeaders: details.requestHeaders })
    })

    // Create main window
    createMainWindow()
})

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') {
        app.quit()
    }
})

app.on('activate', () => {
    if (mainWindow === null) {
        createMainWindow()
    }
})
