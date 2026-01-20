import { useState, useRef, useEffect, useCallback } from 'react'
import { Send, Paperclip, Sparkles, X, RefreshCw, Trash2, FolderOpen } from 'lucide-react'
import { useAppContext } from '../context/AppContext'
import { llmService } from '../services/llm'
import { SuggestionCard } from './SuggestionCard'

export function ChatPanel() {
    const {
        chatMessages,
        addMessage,
        clearChat,
        isTyping,
        setIsTyping,
        suggestions,
        setSuggestions,
        settings,
        setCurrentUrl,
        setRightPanelMode,
        pageContext,
        activeTabId,
        updateTab,
        isGenerating,
        setIsGenerating,
        saveGenTab,
        openGenTab
    } = useAppContext()

    const [input, setInput] = useState('')
    const messagesEndRef = useRef(null)
    const inputRef = useRef(null)

    // Auto-scroll
    useEffect(() => {
        messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
    }, [chatMessages, isTyping])

    // Keyboard shortcut
    useEffect(() => {
        const handleKeyDown = (e) => {
            if ((e.metaKey || e.ctrlKey) && e.key === 'l') {
                e.preventDefault()
                inputRef.current?.focus()
            }
        }
        window.addEventListener('keydown', handleKeyDown)
        return () => window.removeEventListener('keydown', handleKeyDown)
    }, [])

    const isUrl = (text) => {
        try {
            // Basic check for spaces - URLs generally don't have spaces
            if (text.includes(' ')) return false

            // If it has a protocol, it's likely a URL
            if (text.startsWith('http://') || text.startsWith('https://')) {
                new URL(text) // Validate
                return true
            }

            // If no protocol, check for domain-like structure (x.y)
            // Must have at least one dot, and TLD must be 2+ chars
            const domainRegex = /^[a-zA-Z0-9][a-zA-Z0-9-]*(\.[a-zA-Z0-9][a-zA-Z0-9-]*)+$/
            // Or domain/path
            const domainPathRegex = /^[a-zA-Z0-9][a-zA-Z0-9-]*(\.[a-zA-Z0-9][a-zA-Z0-9-]*)+(\/.*)?$/

            return domainPathRegex.test(text)
        } catch {
            return false
        }
    }

    const handleSubmit = async (e) => {
        e.preventDefault()
        const text = input.trim()
        if (!text) return

        setInput('')

        // Check if it's a URL
        if (isUrl(text)) {
            const url = text.startsWith('http') ? text : `https://${text}`
            setCurrentUrl(url)
            updateTab(activeTabId, { url, title: 'Loading...' })
            setRightPanelMode('browser')
            addMessage('user', `Navigate to ${url}`)
            addMessage('assistant', `Opening ${url}`)
            return
        }

        // Regular chat message
        await addMessage('user', text)

        if (!llmService.isInitialized()) {
            await addMessage('assistant', "Please add your Claude API key in Settings to enable AI features.")
            return
        }

        setIsTyping(true)

        try {
            const response = await llmService.chat(text, chatMessages, pageContext)

            // Check for navigation command
            const navMatch = response.match(/\[NAVIGATE:\s*(https?:\/\/[^\]]+)\]/i)
            if (navMatch) {
                const url = navMatch[1]
                setCurrentUrl(url)
                updateTab(activeTabId, { url, title: 'Loading...' })
                setRightPanelMode('browser')
                await addMessage('assistant', response.replace(navMatch[0], `Opening ${url}...`))
            } else {
                await addMessage('assistant', response)
            }

            // Update suggestions if we have context
            if (pageContext.length >= 2 && settings.autoSuggestions) {
                const newSuggestions = await llmService.analyzeForSuggestions(pageContext, chatMessages)
                setSuggestions(newSuggestions)
            }
        } catch (error) {
            await addMessage('assistant', `Error: ${error.message}`)
        } finally {
            setIsTyping(false)
        }
    }

    const handleGenerateGenTab = useCallback(async (suggestion) => {
        if (!llmService.isInitialized() || isGenerating) return

        setIsGenerating(true)
        await addMessage('user', `Create a ${suggestion.type}: ${suggestion.description}`)
        await addMessage('assistant', `Building your ${suggestion.type}... ✨`)

        try {
            const gentab = await llmService.generateGenTab(
                suggestion.description,
                pageContext,
                suggestion.type
            )

            await saveGenTab(gentab)
            openGenTab(gentab)
            await addMessage('assistant', `Your ${gentab.name} is ready! I've opened it for you.`)

            // Remove this suggestion
            setSuggestions(prev => prev.filter(s => s.type !== suggestion.type))
        } catch (error) {
            await addMessage('assistant', `Failed to create GenTab: ${error.message}`)
        } finally {
            setIsGenerating(false)
        }
    }, [isGenerating, pageContext, addMessage, saveGenTab, openGenTab, setSuggestions, setIsGenerating])

    return (
        <div className="w-[38%] min-w-[340px] max-w-[500px] bg-light-panel dark:bg-dark-panel border-r border-light-border dark:border-dark-border flex flex-col">
            {/* Header */}
            <div className="flex items-center justify-between px-4 py-3 border-b border-light-border dark:border-dark-border">
                <h2 className="font-medium text-light-text dark:text-dark-text">Chat</h2>
                <div className="flex items-center gap-1">
                    <button
                        onClick={() => setRightPanelMode('library')}
                        className="p-1.5 rounded-lg hover:bg-black/5 dark:hover:bg-white/5"
                        title="GenTab Library"
                    >
                        <FolderOpen className="w-4 h-4 text-light-muted dark:text-dark-muted" />
                    </button>
                    <button
                        onClick={clearChat}
                        className="p-1.5 rounded-lg hover:bg-black/5 dark:hover:bg-white/5"
                        title="Clear chat"
                    >
                        <Trash2 className="w-4 h-4 text-light-muted dark:text-dark-muted" />
                    </button>
                </div>
            </div>

            {/* Messages */}
            <div className="flex-1 overflow-y-auto p-4 space-y-4">
                {chatMessages.length === 0 && (
                    <div className="text-center py-8">
                        <div className="w-16 h-16 rounded-full bg-gradient-to-br from-google-blue/20 to-blue-500/20 flex items-center justify-center mx-auto mb-4">
                            <Sparkles className="w-8 h-8 text-google-blue" />
                        </div>
                        <h3 className="font-medium text-light-text dark:text-dark-text mb-2">
                            Welcome to Canvas
                        </h3>
                        <p className="text-sm text-light-muted dark:text-dark-muted max-w-xs mx-auto">
                            Type a URL to browse, or ask me anything. I can create interactive apps based on your browsing!
                        </p>
                    </div>
                )}

                {chatMessages.map((msg) => (
                    <div
                        key={msg.id}
                        className={msg.role === 'user' ? 'chat-user animate-slide-up' : 'chat-ai animate-slide-up'}
                    >
                        <p className="text-sm whitespace-pre-wrap">{msg.content}</p>
                    </div>
                ))}

                {isTyping && (
                    <div className="chat-ai">
                        <div className="typing-indicator">
                            <span></span>
                            <span></span>
                            <span></span>
                        </div>
                    </div>
                )}

                <div ref={messagesEndRef} />
            </div>

            {/* Suggestions */}
            {suggestions.length > 0 && (
                <div className="px-4 py-3 border-t border-light-border dark:border-dark-border space-y-2">
                    <div className="flex items-center gap-2 text-xs text-light-muted dark:text-dark-muted">
                        <Sparkles className="w-3.5 h-3.5" />
                        <span>Suggestions</span>
                    </div>
                    {suggestions.slice(0, 2).map((suggestion, i) => (
                        <SuggestionCard
                            key={i}
                            suggestion={suggestion}
                            onGenerate={() => handleGenerateGenTab(suggestion)}
                            onDismiss={() => setSuggestions(prev => prev.filter((_, j) => j !== i))}
                            isLoading={isGenerating}
                        />
                    ))}
                </div>
            )}

            {/* Input */}
            <form onSubmit={handleSubmit} className="p-4 border-t border-light-border dark:border-dark-border">
                <div className="flex items-end gap-2">
                    <div className="flex-1 relative">
                        <input
                            ref={inputRef}
                            type="text"
                            value={input}
                            onChange={(e) => setInput(e.target.value)}
                            placeholder="Type a prompt, URL, or command... ⌘L"
                            className="input-primary pr-10 text-sm"
                            disabled={isTyping}
                        />
                    </div>
                    <button
                        type="submit"
                        disabled={!input.trim() || isTyping}
                        className="btn-primary p-2.5 disabled:opacity-50"
                    >
                        <Send className="w-4 h-4" />
                    </button>
                </div>
            </form>
        </div>
    )
}
