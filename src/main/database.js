import Database from 'better-sqlite3'
import path from 'path'
import { app } from 'electron'
import fs from 'fs'

let db = null

export function createDatabase() {
    const userDataPath = app.getPath('userData')
    const dbPath = path.join(userDataPath, 'canvas.db')

    if (!fs.existsSync(userDataPath)) {
        fs.mkdirSync(userDataPath, { recursive: true })
    }

    db = new Database(dbPath)
    db.pragma('journal_mode = WAL')

    // Create tables
    db.exec(`
    -- GenTabs (generated interactive apps)
    CREATE TABLE IF NOT EXISTS gentabs (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      component_code TEXT NOT NULL,
      component_state TEXT DEFAULT '{}',
      created_at INTEGER,
      modified_at INTEGER
    );
    
    -- Sources linked to GenTabs
    CREATE TABLE IF NOT EXISTS gentab_sources (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      gentab_id TEXT,
      url TEXT,
      title TEXT,
      snippet TEXT,
      FOREIGN KEY (gentab_id) REFERENCES gentabs(id)
    );
    
    -- Chat history
    CREATE TABLE IF NOT EXISTS chat_history (
      id TEXT PRIMARY KEY,
      role TEXT NOT NULL,
      content TEXT NOT NULL,
      timestamp INTEGER,
      related_gentab_id TEXT
    );
    
    -- Browsing history (for context)
    CREATE TABLE IF NOT EXISTS browsing_history (
      id TEXT PRIMARY KEY,
      url TEXT NOT NULL,
      title TEXT,
      visited_at INTEGER,
      content_summary TEXT
    );
    
    -- Settings
    CREATE TABLE IF NOT EXISTS settings (
      key TEXT PRIMARY KEY,
      value TEXT
    );
    
    -- Indexes
    CREATE INDEX IF NOT EXISTS idx_gentabs_modified ON gentabs(modified_at);
    CREATE INDEX IF NOT EXISTS idx_chat_timestamp ON chat_history(timestamp);
    CREATE INDEX IF NOT EXISTS idx_history_visited ON browsing_history(visited_at);
  `)

    return db
}

export function getDatabase() {
    if (!db) {
        throw new Error('Database not initialized')
    }
    return db
}
