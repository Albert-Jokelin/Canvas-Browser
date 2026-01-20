import { useEffect } from 'react'
import { useAppContext } from './context/AppContext'
import { llmService } from './services/llm'
import { TitleBar } from './components/TitleBar'
import { ChatPanel } from './components/ChatPanel'
import { RightPanel } from './components/RightPanel'

export default function App() {
    const { settings, theme } = useAppContext()

    // Initialize AI when settings change
    useEffect(() => {
        const provider = settings.provider || 'claude'
        const apiKey = provider === 'gemini' ? settings.geminiApiKey : settings.apiKey
        const model = provider === 'gemini' ? (settings.geminiModel || 'gemini-1.5-flash-latest') : undefined

        if (apiKey) {
            try {
                llmService.initialize({
                    provider,
                    apiKey,
                    model
                })
            } catch (e) {
                console.error('Failed to init AI:', e)
            }
        }
    }, [settings.apiKey, settings.geminiApiKey, settings.provider, settings.geminiModel])

    return (
        <div className={`h-screen flex flex-col ${theme === 'dark' ? 'dark' : ''}`}>
            {/* Title Bar */}
            <TitleBar />

            {/* Main Split Layout */}
            <div className="flex-1 flex overflow-hidden">
                {/* Left Panel - Chat */}
                <ChatPanel />

                {/* Right Panel - Browser / GenTab */}
                <RightPanel />
            </div>
        </div>
    )
}
