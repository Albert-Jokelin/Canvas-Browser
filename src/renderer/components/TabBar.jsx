import { X, Plus, Globe, Sparkles } from 'lucide-react'
import { useAppContext } from '../context/AppContext'

export function TabBar() {
    const {
        tabs,
        activeTabId,
        setActiveTabId,
        closeTab,
        addTab,
        setRightPanelMode,
        setCurrentGenTab
    } = useAppContext()

    const handleTabClick = (tab) => {
        setActiveTabId(tab.id)
        if (tab.type === 'gentab' && tab.gentab) {
            setCurrentGenTab(tab.gentab)
            setRightPanelMode('gentab')
        } else {
            setRightPanelMode('browser')
        }
    }

    const handleNewTab = () => {
        addTab({ type: 'browser', title: 'New Tab', url: '' })
        setRightPanelMode('browser')
    }

    return (
        <div className="flex items-center gap-1 px-2 py-1.5 bg-light-panel dark:bg-dark-panel border-b border-light-border dark:border-dark-border overflow-x-auto">
            {tabs.map((tab) => (
                <div
                    key={tab.id}
                    onClick={() => handleTabClick(tab)}
                    className={`tab-item flex items-center gap-2 min-w-[120px] max-w-[200px] cursor-pointer group ${activeTabId === tab.id ? 'active' : ''
                        }`}
                >
                    {tab.type === 'gentab' ? (
                        <Sparkles className="w-4 h-4 text-google-blue shrink-0" />
                    ) : (
                        <Globe className="w-4 h-4 text-light-muted dark:text-dark-muted shrink-0" />
                    )}
                    <span className="flex-1 truncate text-xs">{tab.title}</span>
                    <button
                        onClick={(e) => {
                            e.stopPropagation()
                            closeTab(tab.id)
                        }}
                        className="p-0.5 rounded opacity-0 group-hover:opacity-100 hover:bg-black/10 dark:hover:bg-white/10"
                    >
                        <X className="w-3 h-3" />
                    </button>
                </div>
            ))}

            <button
                onClick={handleNewTab}
                className="p-1.5 rounded-lg hover:bg-black/5 dark:hover:bg-white/5 shrink-0"
            >
                <Plus className="w-4 h-4 text-light-muted dark:text-dark-muted" />
            </button>
        </div>
    )
}
