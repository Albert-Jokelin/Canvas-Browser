// Mock Electron API
window.electronAPI = {
    minimizeWindow: vi.fn(),
    maximizeWindow: vi.fn(),
    closeWindow: vi.fn(),
    getChatHistory: vi.fn().mockResolvedValue([]),
    getGenTabs: vi.fn().mockResolvedValue([]),
    getSetting: vi.fn(),
    addChatMessage: vi.fn(),
    saveGenTab: vi.fn(),
    addPageContext: vi.fn()
}

// Mock scrollIntoView
window.HTMLElement.prototype.scrollIntoView = vi.fn()
