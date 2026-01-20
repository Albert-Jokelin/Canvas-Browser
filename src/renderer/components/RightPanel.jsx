import { useAppContext } from '../context/AppContext'
import { BrowserView } from './BrowserView'
import { GenTabView } from './GenTabView'
import { GenTabLibrary } from './GenTabLibrary'
import { SettingsPanel } from './SettingsPanel'
import { TabBar } from './TabBar'

export function RightPanel() {
    const { rightPanelMode, tabs } = useAppContext()

    return (
        <div className="flex-1 flex flex-col bg-white dark:bg-dark-bg overflow-hidden">
            {/* Tab Bar */}
            {tabs.length > 0 && rightPanelMode !== 'settings' && rightPanelMode !== 'library' && (
                <TabBar />
            )}

            {/* Content */}
            <div className="flex-1 overflow-hidden">
                {rightPanelMode === 'browser' && <BrowserView />}
                {rightPanelMode === 'gentab' && <GenTabView />}
                {rightPanelMode === 'library' && <GenTabLibrary />}
                {rightPanelMode === 'settings' && <SettingsPanel />}
            </div>
        </div>
    )
}
