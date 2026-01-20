const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('electronAPI', {
    // Window controls
    minimizeWindow: () => ipcRenderer.send('window-minimize'),
    maximizeWindow: () => ipcRenderer.send('window-maximize'),
    closeWindow: () => ipcRenderer.send('window-close'),

    // GenTabs
    getGenTabs: () => ipcRenderer.invoke('db-get-gentabs'),
    getGenTab: (id) => ipcRenderer.invoke('db-get-gentab', id),
    saveGenTab: (gentab) => ipcRenderer.invoke('db-save-gentab', gentab),
    deleteGenTab: (id) => ipcRenderer.invoke('db-delete-gentab', id),

    // Sources
    saveSources: (gentabId, sources) => ipcRenderer.invoke('db-save-sources', gentabId, sources),
    getSources: (gentabId) => ipcRenderer.invoke('db-get-sources', gentabId),

    // Chat
    getChatHistory: () => ipcRenderer.invoke('db-get-chat-history'),
    addChatMessage: (msg) => ipcRenderer.invoke('db-add-chat-message', msg),
    clearChat: () => ipcRenderer.invoke('db-clear-chat'),

    // Browsing context
    addPageContext: (page) => ipcRenderer.invoke('db-add-page-context', page),
    getRecentPages: (limit) => ipcRenderer.invoke('db-get-recent-pages', limit),

    // Settings
    getSetting: (key) => ipcRenderer.invoke('db-get-setting', key),
    setSetting: (key, value) => ipcRenderer.invoke('db-set-setting', key, value),
})
