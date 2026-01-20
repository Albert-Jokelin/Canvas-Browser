import React, { useState, useEffect, useMemo, useCallback, useRef } from 'react'
import {
    Save,
    Download,
    MessageSquare,
    X,
    ExternalLink,
    AlertCircle,
    Loader2,
    Send
} from 'lucide-react'
import * as Babel from '@babel/standalone'
import * as LucideIcons from 'lucide-react'
import * as Recharts from 'recharts'
import { useAppContext } from '../context/AppContext'
import { llmService } from '../services/llm'

export function GenTabView() {
    const {
        currentGenTab,
        setCurrentGenTab,
        saveGenTab,
        setRightPanelMode,
        addMessage,
        settings
    } = useAppContext()

    const [showChat, setShowChat] = useState(false)
    const [chatInput, setChatInput] = useState('')
    const [isRefining, setIsRefining] = useState(false)
    const [refinementHistory, setRefinementHistory] = useState([])
    const [error, setError] = useState(null)
    const [sources, setSources] = useState([])

    useEffect(() => {
        if (currentGenTab?.id) {
            loadSources()
        }
    }, [currentGenTab?.id])

    const loadSources = async () => {
        if (currentGenTab?.sources) {
            setSources(currentGenTab.sources)
        } else {
            const srcs = await window.electronAPI?.getSources(currentGenTab.id)
            setSources(srcs || [])
        }
    }

    // Render the GenTab component
    const RenderedComponent = useMemo(() => {
        if (!currentGenTab?.component_code) return null

        setError(null)

        try {
            // Transform JSX to JS
            const transformed = Babel.transform(currentGenTab.component_code, {
                presets: ['react'],
                filename: 'gentab.jsx'
            }).code

            // Create component function with available libraries
            const createComponent = new Function(
                'React',
                'useState',
                'useEffect',
                'useMemo',
                'useCallback',
                'useRef',
                'LucideIcons',
                'Recharts',
                `
        const { ${Object.keys(LucideIcons).join(', ')} } = LucideIcons;
        const { ${Object.keys(Recharts).join(', ')} } = Recharts;
        ${transformed}
        return typeof GenTab !== 'undefined' ? GenTab : null;
        `
            )

            return createComponent(
                React,
                useState,
                useEffect,
                useMemo,
                useCallback,
                useRef,
                LucideIcons,
                Recharts
            )
        } catch (e) {
            console.error('GenTab render error:', e)
            setError(e.message)
            return null
        }
    }, [currentGenTab?.component_code])

    const handleRefine = async (e) => {
        e.preventDefault()
        if (!chatInput.trim() || !llmService.isInitialized() || isRefining) return

        const request = chatInput.trim()
        setChatInput('')
        setIsRefining(true)

        setRefinementHistory(prev => [...prev, { role: 'user', content: request }])

        try {
            const result = await llmService.refineGenTab(
                currentGenTab.component_code,
                request,
                sources
            )

            const updatedGenTab = {
                ...currentGenTab,
                component_code: result.code,
                modified_at: Date.now()
            }

            await saveGenTab(updatedGenTab)
            setCurrentGenTab(updatedGenTab)

            setRefinementHistory(prev => [...prev, { role: 'assistant', content: result.changes }])
            await addMessage('assistant', `Updated ${currentGenTab.name}: ${result.changes}`)
        } catch (e) {
            setRefinementHistory(prev => [...prev, { role: 'assistant', content: `Error: ${e.message}` }])
        } finally {
            setIsRefining(false)
        }
    }

    const handleSave = async () => {
        if (currentGenTab) {
            await saveGenTab(currentGenTab)
            await addMessage('assistant', `Saved ${currentGenTab.name}`)
        }
    }

    const handleExport = () => {
        if (!currentGenTab) return

        const html = `
<!DOCTYPE html>
<html>
<head>
  <title>${currentGenTab.name}</title>
  <script src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
  <script src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
  <script src="https://cdn.tailwindcss.com"></script>
</head>
<body>
  <div id="root"></div>
  <script type="text/babel">
    ${currentGenTab.component_code}
    ReactDOM.createRoot(document.getElementById('root')).render(<GenTab />);
  </script>
  <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
</body>
</html>
    `.trim()

        const blob = new Blob([html], { type: 'text/html' })
        const url = URL.createObjectURL(blob)
        const a = document.createElement('a')
        a.href = url
        a.download = `${currentGenTab.name.replace(/\s+/g, '-').toLowerCase()}.html`
        a.click()
        URL.revokeObjectURL(url)
    }

    const handleClose = () => {
        setCurrentGenTab(null)
        setRightPanelMode('browser')
    }

    if (!currentGenTab) {
        return (
            <div className="h-full flex items-center justify-center text-light-muted dark:text-dark-muted">
                No GenTab selected
            </div>
        )
    }

    return (
        <div className="h-full flex flex-col">
            {/* Header */}
            <div className="flex items-center justify-between px-4 py-3 bg-light-panel dark:bg-dark-panel border-b border-light-border dark:border-dark-border">
                <div>
                    <h2 className="font-semibold text-light-text dark:text-dark-text">
                        {currentGenTab.name}
                    </h2>
                    <p className="text-xs text-light-muted dark:text-dark-muted">
                        {currentGenTab.type}
                    </p>
                </div>

                <div className="flex items-center gap-2">
                    <button
                        onClick={() => setShowChat(!showChat)}
                        className={`btn-secondary text-sm ${showChat ? 'bg-google-blue/10 border-google-blue/30' : ''}`}
                    >
                        <MessageSquare className="w-4 h-4" />
                        Edit with AI
                    </button>
                    <button onClick={handleSave} className="btn-ghost p-2">
                        <Save className="w-4 h-4" />
                    </button>
                    <button onClick={handleExport} className="btn-ghost p-2">
                        <Download className="w-4 h-4" />
                    </button>
                    <button onClick={handleClose} className="btn-ghost p-2">
                        <X className="w-4 h-4" />
                    </button>
                </div>
            </div>

            {/* Content */}
            <div className="flex-1 flex overflow-hidden">
                {/* GenTab Content */}
                <div className="flex-1 overflow-auto gentab-container bg-white dark:bg-dark-bg">
                    {error ? (
                        <div className="flex flex-col items-center justify-center h-full text-center p-8">
                            <AlertCircle className="w-12 h-12 text-red-500 mb-4" />
                            <h3 className="font-semibold text-light-text dark:text-dark-text mb-2">
                                Failed to render GenTab
                            </h3>
                            <p className="text-sm text-light-muted dark:text-dark-muted max-w-md mb-4">
                                {error}
                            </p>
                            <button
                                onClick={() => setShowChat(true)}
                                className="btn-primary"
                            >
                                <MessageSquare className="w-4 h-4" />
                                Fix with AI
                            </button>
                        </div>
                    ) : RenderedComponent ? (
                        <ErrorBoundary onError={setError}>
                            <RenderedComponent />
                        </ErrorBoundary>
                    ) : (
                        <div className="flex items-center justify-center h-full">
                            <Loader2 className="w-8 h-8 animate-spin text-google-blue" />
                        </div>
                    )}
                </div>

                {/* Refinement Chat */}
                {showChat && (
                    <div className="w-80 border-l border-light-border dark:border-dark-border flex flex-col bg-light-panel dark:bg-dark-panel animate-slide-in-right">
                        <div className="px-4 py-3 border-b border-light-border dark:border-dark-border flex items-center justify-between">
                            <span className="font-medium text-sm">Edit with AI</span>
                            <button onClick={() => setShowChat(false)} className="p-1 hover:bg-black/5 dark:hover:bg-white/5 rounded">
                                <X className="w-4 h-4" />
                            </button>
                        </div>

                        <div className="flex-1 overflow-y-auto p-4 space-y-3">
                            {refinementHistory.length === 0 && (
                                <p className="text-xs text-light-muted dark:text-dark-muted text-center py-4">
                                    Describe what you'd like to change
                                </p>
                            )}
                            {refinementHistory.map((msg, i) => (
                                <div
                                    key={i}
                                    className={msg.role === 'user' ? 'chat-user text-xs' : 'chat-ai text-xs'}
                                >
                                    {msg.content}
                                </div>
                            ))}
                            {isRefining && (
                                <div className="chat-ai">
                                    <div className="typing-indicator">
                                        <span></span><span></span><span></span>
                                    </div>
                                </div>
                            )}
                        </div>

                        <form onSubmit={handleRefine} className="p-4 border-t border-light-border dark:border-dark-border">
                            <div className="flex gap-2">
                                <input
                                    type="text"
                                    value={chatInput}
                                    onChange={(e) => setChatInput(e.target.value)}
                                    placeholder="Add a budget column..."
                                    className="input-primary text-sm flex-1"
                                    disabled={isRefining}
                                />
                                <button type="submit" disabled={isRefining} className="btn-primary p-2">
                                    <Send className="w-4 h-4" />
                                </button>
                            </div>
                        </form>
                    </div>
                )}
            </div>

            {/* Sources */}
            {sources.length > 0 && settings.showSources && (
                <div className="px-4 py-2 border-t border-light-border dark:border-dark-border bg-light-panel dark:bg-dark-panel">
                    <div className="flex items-center gap-2 flex-wrap">
                        <span className="text-xs text-light-muted dark:text-dark-muted">Sources:</span>
                        {sources.map((src, i) => (
                            <a
                                key={i}
                                href={src.url}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="source-link flex items-center gap-1"
                            >
                                {src.title || src.url}
                                <ExternalLink className="w-3 h-3" />
                            </a>
                        ))}
                    </div>
                </div>
            )}
        </div>
    )
}

// Error boundary component
class ErrorBoundary extends React.Component {
    constructor(props) {
        super(props)
        this.state = { hasError: false }
    }

    static getDerivedStateFromError() {
        return { hasError: true }
    }

    componentDidCatch(error) {
        this.props.onError?.(error.message)
    }

    render() {
        if (this.state.hasError) return null
        return this.props.children
    }
}
