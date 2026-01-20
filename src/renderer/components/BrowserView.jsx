import { useRef, useEffect, useCallback } from 'react'
import { ArrowLeft, ArrowRight, RotateCw, MessageSquare, Globe } from 'lucide-react'
import { useAppContext } from '../context/AppContext'

export function BrowserView() {
    const {
        currentUrl,
        setCurrentUrl,
        isLoading,
        setIsLoading,
        setPageTitle,
        addPageToContext,
        updateTab,
        activeTabId,
        tabs,
        addMessage
    } = useAppContext()

    const webviewRef = useRef(null)
    const activeTab = tabs.find(t => t.id === activeTabId)

    useEffect(() => {
        const webview = webviewRef.current
        if (!webview) return

        const handleStartLoading = () => setIsLoading(true)
        const handleStopLoading = () => setIsLoading(false)

        const handleDidNavigate = (e) => {
            setCurrentUrl(e.url)
            updateTab(activeTabId, { url: e.url })
        }

        const handleTitleUpdate = (e) => {
            setPageTitle(e.title)
            updateTab(activeTabId, { title: e.title })
        }

        const handleDomReady = async () => {
            try {
                // Extract page content for context
                const content = await webview.executeJavaScript(`
          ({
            title: document.title,
            url: window.location.href,
            text: document.body?.innerText?.slice(0, 3000) || '',
            description: document.querySelector('meta[name="description"]')?.content || ''
          })
        `)

                // Summarize and add to context
                addPageToContext({
                    url: content.url,
                    title: content.title,
                    summary: content.description || content.text.slice(0, 200)
                })
            } catch (e) {
                console.error('Failed to extract page content:', e)
            }
        }

        webview.addEventListener('did-start-loading', handleStartLoading)
        webview.addEventListener('did-stop-loading', handleStopLoading)
        webview.addEventListener('did-navigate', handleDidNavigate)
        webview.addEventListener('did-navigate-in-page', handleDidNavigate)
        webview.addEventListener('page-title-updated', handleTitleUpdate)
        webview.addEventListener('dom-ready', handleDomReady)

        return () => {
            webview.removeEventListener('did-start-loading', handleStartLoading)
            webview.removeEventListener('did-stop-loading', handleStopLoading)
            webview.removeEventListener('did-navigate', handleDidNavigate)
            webview.removeEventListener('did-navigate-in-page', handleDidNavigate)
            webview.removeEventListener('page-title-updated', handleTitleUpdate)
            webview.removeEventListener('dom-ready', handleDomReady)
        }
    }, [activeTabId, setCurrentUrl, setIsLoading, setPageTitle, addPageToContext, updateTab])

    // Navigate when URL changes
    useEffect(() => {
        const webview = webviewRef.current
        try {
            if (webview && activeTab?.url && webview.getURL && activeTab.url !== webview.getURL()) {
                webview.src = activeTab.url
            }
        } catch (e) {
            // Webview might not be ready
            if (webview && activeTab?.url) {
                webview.src = activeTab.url
            }
        }
    }, [activeTab?.url])

    const handleBack = useCallback(() => {
        webviewRef.current?.goBack()
    }, [])

    const handleForward = useCallback(() => {
        webviewRef.current?.goForward()
    }, [])

    const handleRefresh = useCallback(() => {
        webviewRef.current?.reload()
    }, [])

    const handleAskAI = useCallback(() => {
        addMessage('user', `Tell me about this page: ${activeTab?.title}`)
    }, [addMessage, activeTab])

    // Empty state
    if (!activeTab?.url) {
        return (
            <div className="h-full flex flex-col items-center justify-center text-center p-8">
                <div className="w-20 h-20 rounded-full bg-gradient-to-br from-google-blue/10 to-blue-500/10 flex items-center justify-center mb-6">
                    <Globe className="w-10 h-10 text-google-blue" />
                </div>
                <h2 className="text-xl font-semibold text-light-text dark:text-dark-text mb-2">
                    Ready to browse
                </h2>
                <p className="text-light-muted dark:text-dark-muted max-w-sm">
                    Type a URL in the chat panel to start browsing, or ask me to find something for you.
                </p>
            </div>
        )
    }

    return (
        <div className="h-full flex flex-col">
            {/* Mini toolbar */}
            <div className="flex items-center gap-1 px-3 py-2 bg-light-panel dark:bg-dark-panel border-b border-light-border dark:border-dark-border">
                <div style={{ color: 'red', fontSize: '10px' }}>[DEBUG: {activeTab?.url}]</div>
                <button onClick={handleBack} className="btn-ghost p-1.5">
                    <ArrowLeft className="w-4 h-4" />
                </button>
                <button onClick={handleForward} className="btn-ghost p-1.5">
                    <ArrowRight className="w-4 h-4" />
                </button>
                <button onClick={handleRefresh} className="btn-ghost p-1.5">
                    <RotateCw className={`w-4 h-4 ${isLoading ? 'animate-spin' : ''}`} />
                </button>

                <div className="flex-1 px-3">
                    <div className="text-xs text-light-muted dark:text-dark-muted truncate">
                        {activeTab?.url}
                    </div>
                </div>

                <button onClick={handleAskAI} className="btn-secondary text-xs px-3 py-1.5">
                    <MessageSquare className="w-3.5 h-3.5" />
                    Ask AI
                </button>
            </div>

            {/* Loading bar */}
            {isLoading && (
                <div className="h-0.5 bg-light-border dark:bg-dark-border">
                    <div className="progress-bar" />
                </div>
            )}

            {/* WebView */}
            <webview
                ref={webviewRef}
                className="flex-1 w-full h-full"
                src={activeTab?.url || 'about:blank'}
                allowpopups="true"
                webpreferences="sandbox=no, contextIsolation=yes"
                style={{ width: '100%', height: '100%', border: 'none' }}
            />
        </div>
    )
}
