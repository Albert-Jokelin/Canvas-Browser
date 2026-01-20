import { Minus, Square, X, Settings, Moon, Sun } from 'lucide-react'
import { useAppContext } from '../context/AppContext'

export function TitleBar() {
    const { theme, setTheme, setRightPanelMode } = useAppContext()

    return (
        <header className="drag-region h-11 bg-light-panel dark:bg-dark-panel border-b border-light-border dark:border-dark-border flex items-center justify-between px-4 shrink-0">
            {/* Logo */}
            <div className="flex items-center gap-3 no-drag">
                <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-google-blue to-blue-600 flex items-center justify-center shadow-sm">
                    <span className="text-white font-bold text-sm">C</span>
                </div>
                <span className="text-sm font-semibold text-light-text dark:text-dark-text">Canvas</span>
            </div>

            {/* Center space for dragging */}
            <div className="flex-1" />

            {/* Actions */}
            <div className="flex items-center gap-1 no-drag">
                {/* Theme toggle */}
                <button
                    onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
                    className="p-2 rounded-lg hover:bg-black/5 dark:hover:bg-white/5 transition-colors"
                >
                    {theme === 'dark' ? (
                        <Sun className="w-4 h-4 text-dark-muted" />
                    ) : (
                        <Moon className="w-4 h-4 text-light-muted" />
                    )}
                </button>

                {/* Settings */}
                <button
                    onClick={() => setRightPanelMode('settings')}
                    className="p-2 rounded-lg hover:bg-black/5 dark:hover:bg-white/5 transition-colors"
                >
                    <Settings className="w-4 h-4 text-light-muted dark:text-dark-muted" />
                </button>

                {/* Window controls */}
                <div className="flex items-center ml-2 border-l border-light-border dark:border-dark-border pl-2">
                    <button
                        onClick={() => window.electronAPI?.minimizeWindow()}
                        className="p-2 rounded hover:bg-black/5 dark:hover:bg-white/5"
                    >
                        <Minus className="w-4 h-4 text-light-muted dark:text-dark-muted" />
                    </button>
                    <button
                        onClick={() => window.electronAPI?.maximizeWindow()}
                        className="p-2 rounded hover:bg-black/5 dark:hover:bg-white/5"
                    >
                        <Square className="w-3.5 h-3.5 text-light-muted dark:text-dark-muted" />
                    </button>
                    <button
                        onClick={() => window.electronAPI?.closeWindow()}
                        className="p-2 rounded hover:bg-red-100 dark:hover:bg-red-500/20 group"
                    >
                        <X className="w-4 h-4 text-light-muted dark:text-dark-muted group-hover:text-red-500" />
                    </button>
                </div>
            </div>
        </header>
    )
}
