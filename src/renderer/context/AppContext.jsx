import { createContext, useContext, useState, useEffect, useCallback } from 'react'

const AppContext = createContext(null)

export function useAppContext() {
    const context = useContext(AppContext)
    if (!context) throw new Error('useAppContext must be used within AppProvider')
    return context
}

export function AppProvider({ children }) {
    // Theme
    const [theme, setTheme] = useState('light')

    // Chat state
    const [chatMessages, setChatMessages] = useState([])
    const [isTyping, setIsTyping] = useState(false)

    // Suggestions
    const [suggestions, setSuggestions] = useState([])

    // Right panel mode: 'browser' | 'gentab' | 'library'
    const [rightPanelMode, setRightPanelMode] = useState('browser')

    // Browser state
    const [currentUrl, setCurrentUrl] = useState('')
    const [isLoading, setIsLoading] = useState(false)
    const [pageTitle, setPageTitle] = useState('')

    // Tabs (web pages and GenTabs)
    const [tabs, setTabs] = useState([
        { id: 'home', type: 'browser', title: 'New Tab', url: '' }
    ])
    const [activeTabId, setActiveTabId] = useState('home')

    // GenTabs
    const [savedGenTabs, setSavedGenTabs] = useState([])
    const [currentGenTab, setCurrentGenTab] = useState(null)
    const [isGenerating, setIsGenerating] = useState(false)

    // Browsing context (for AI)
    const [pageContext, setPageContext] = useState([])

    // Settings
    const [settings, setSettings] = useState({
        apiKey: '',
        autoSuggestions: true,
        showSources: true
    })

    // Load initial data
    useEffect(() => {
        loadData()
        loadSettings()
    }, [])

    // Apply theme
    useEffect(() => {
        document.body.classList.toggle('dark', theme === 'dark')
    }, [theme])

    const loadData = async () => {
        try {
            const [history, gentabs] = await Promise.all([
                window.electronAPI?.getChatHistory(),
                window.electronAPI?.getGenTabs()
            ])
            setChatMessages(history || [])
            setSavedGenTabs(gentabs || [])
        } catch (e) {
            console.error('Failed to load data:', e)
        }
    }

    const loadSettings = async () => {
        try {
            const apiKey = await window.electronAPI?.getSetting('apiKey')
            const geminiApiKey = await window.electronAPI?.getSetting('geminiApiKey')
            const geminiModel = await window.electronAPI?.getSetting('geminiModel')
            const provider = await window.electronAPI?.getSetting('provider')
            const themeVal = await window.electronAPI?.getSetting('theme')

            setSettings(prev => ({
                ...prev,
                apiKey: apiKey || '',
                geminiApiKey: geminiApiKey || '',
                geminiModel: geminiModel || '',
                provider: provider || 'claude'
            }))
            if (themeVal) setTheme(themeVal)
        } catch (e) {
            console.error('Failed to load settings:', e)
        }
    }

    // Chat functions
    const addMessage = useCallback(async (role, content, relatedGenTabId = null) => {
        const msg = {
            id: Date.now().toString(),
            role,
            content,
            timestamp: Date.now(),
            related_gentab_id: relatedGenTabId
        }
        setChatMessages(prev => [...prev, msg])
        await window.electronAPI?.addChatMessage(msg)
        return msg
    }, [])

    const clearChat = useCallback(async () => {
        setChatMessages([])
        await window.electronAPI?.clearChat()
    }, [])

    // Tab functions
    const addTab = useCallback((tab) => {
        const newTab = {
            id: Date.now().toString(),
            type: tab.type || 'browser',
            title: tab.title || 'New Tab',
            url: tab.url || '',
            gentab: tab.gentab || null
        }
        setTabs(prev => [...prev, newTab])
        setActiveTabId(newTab.id)
        return newTab
    }, [])

    const closeTab = useCallback((tabId) => {
        setTabs(prev => {
            const newTabs = prev.filter(t => t.id !== tabId)
            if (newTabs.length === 0) {
                return [{ id: 'home', type: 'browser', title: 'New Tab', url: '' }]
            }
            if (activeTabId === tabId) {
                setActiveTabId(newTabs[newTabs.length - 1].id)
            }
            return newTabs
        })
    }, [activeTabId])

    const updateTab = useCallback((tabId, updates) => {
        setTabs(prev => prev.map(t => t.id === tabId ? { ...t, ...updates } : t))
    }, [])

    // GenTab functions
    const saveGenTab = useCallback(async (gentab) => {
        await window.electronAPI?.saveGenTab(gentab)
        setSavedGenTabs(prev => {
            const existing = prev.findIndex(g => g.id === gentab.id)
            if (existing >= 0) {
                const updated = [...prev]
                updated[existing] = gentab
                return updated
            }
            return [gentab, ...prev]
        })
        return gentab
    }, [])

    const deleteGenTab = useCallback(async (id) => {
        await window.electronAPI?.deleteGenTab(id)
        setSavedGenTabs(prev => prev.filter(g => g.id !== id))
        setTabs(prev => prev.filter(t => t.gentab?.id !== id))
    }, [])

    const openGenTab = useCallback((gentab) => {
        // Check if already open
        const existing = tabs.find(t => t.gentab?.id === gentab.id)
        if (existing) {
            setActiveTabId(existing.id)
            setRightPanelMode('gentab')
            setCurrentGenTab(gentab)
            return
        }

        const tab = addTab({
            type: 'gentab',
            title: gentab.name,
            gentab
        })
        setRightPanelMode('gentab')
        setCurrentGenTab(gentab)
    }, [tabs, addTab])

    // Page context
    const addPageToContext = useCallback(async (page) => {
        setPageContext(prev => {
            const existing = prev.findIndex(p => p.url === page.url)
            if (existing >= 0) {
                const updated = [...prev]
                updated[existing] = { ...page, timestamp: Date.now() }
                return updated
            }
            return [...prev.slice(-9), { ...page, timestamp: Date.now() }]
        })
        await window.electronAPI?.addPageContext({
            id: btoa(page.url).slice(0, 50),
            ...page
        })
    }, [])

    // Settings
    const updateSettings = useCallback(async (newSettings) => {
        setSettings(newSettings)
        for (const [key, value] of Object.entries(newSettings)) {
            await window.electronAPI?.setSetting(key, String(value))
        }
    }, [])

    const value = {
        // Theme
        theme,
        setTheme,

        // Chat
        chatMessages,
        addMessage,
        clearChat,
        isTyping,
        setIsTyping,

        // Suggestions
        suggestions,
        setSuggestions,

        // Panel mode
        rightPanelMode,
        setRightPanelMode,

        // Browser
        currentUrl,
        setCurrentUrl,
        isLoading,
        setIsLoading,
        pageTitle,
        setPageTitle,

        // Tabs
        tabs,
        activeTabId,
        setActiveTabId,
        addTab,
        closeTab,
        updateTab,

        // GenTabs
        savedGenTabs,
        currentGenTab,
        setCurrentGenTab,
        saveGenTab,
        deleteGenTab,
        openGenTab,
        isGenerating,
        setIsGenerating,

        // Context
        pageContext,
        addPageToContext,

        // Settings
        settings,
        updateSettings
    }

    return <AppContext.Provider value={value}>{children}</AppContext.Provider>
}
