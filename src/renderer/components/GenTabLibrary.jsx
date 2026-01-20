import { useState } from 'react'
import { ArrowLeft, Search, Sparkles, Trash2, Download, Clock, MoreVertical } from 'lucide-react'
import { useAppContext } from '../context/AppContext'

export function GenTabLibrary() {
    const { savedGenTabs, openGenTab, deleteGenTab, setRightPanelMode } = useAppContext()
    const [searchQuery, setSearchQuery] = useState('')
    const [menuOpen, setMenuOpen] = useState(null)

    const filteredGenTabs = savedGenTabs.filter(g =>
        g.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        g.type.toLowerCase().includes(searchQuery.toLowerCase())
    )

    const handleExport = (gentab) => {
        const data = JSON.stringify(gentab, null, 2)
        const blob = new Blob([data], { type: 'application/json' })
        const url = URL.createObjectURL(blob)
        const a = document.createElement('a')
        a.href = url
        a.download = `${gentab.name.replace(/\s+/g, '-').toLowerCase()}.json`
        a.click()
        URL.revokeObjectURL(url)
        setMenuOpen(null)
    }

    const handleDelete = async (id) => {
        if (confirm('Delete this GenTab?')) {
            await deleteGenTab(id)
        }
        setMenuOpen(null)
    }

    return (
        <div className="h-full flex flex-col">
            {/* Header */}
            <div className="px-6 py-4 border-b border-light-border dark:border-dark-border">
                <div className="flex items-center gap-4 mb-4">
                    <button
                        onClick={() => setRightPanelMode('browser')}
                        className="p-2 hover:bg-black/5 dark:hover:bg-white/5 rounded-lg"
                    >
                        <ArrowLeft className="w-5 h-5" />
                    </button>
                    <h1 className="text-xl font-semibold text-light-text dark:text-dark-text">
                        GenTab Library
                    </h1>
                </div>

                {/* Search */}
                <div className="relative">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-light-muted dark:text-dark-muted" />
                    <input
                        type="text"
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        placeholder="Search GenTabs..."
                        className="input-primary pl-10"
                    />
                </div>
            </div>

            {/* Grid */}
            <div className="flex-1 overflow-y-auto p-6">
                {filteredGenTabs.length === 0 ? (
                    <div className="text-center py-12">
                        <div className="w-16 h-16 rounded-full bg-light-panel dark:bg-dark-surface flex items-center justify-center mx-auto mb-4">
                            <Sparkles className="w-8 h-8 text-light-muted dark:text-dark-muted" />
                        </div>
                        <h3 className="font-medium text-light-text dark:text-dark-text mb-2">
                            {searchQuery ? 'No matching GenTabs' : 'No GenTabs yet'}
                        </h3>
                        <p className="text-sm text-light-muted dark:text-dark-muted">
                            {searchQuery
                                ? 'Try a different search term'
                                : 'Browse the web and I\'ll suggest apps to create!'}
                        </p>
                    </div>
                ) : (
                    <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
                        {filteredGenTabs.map((gentab) => (
                            <div
                                key={gentab.id}
                                className="group bg-white dark:bg-dark-surface border border-light-border dark:border-dark-border rounded-xl overflow-hidden hover:shadow-lg transition-all cursor-pointer"
                                onClick={() => openGenTab(gentab)}
                            >
                                {/* Preview placeholder */}
                                <div className="h-32 bg-gradient-to-br from-google-blue/10 to-blue-500/10 flex items-center justify-center">
                                    <Sparkles className="w-10 h-10 text-google-blue/50" />
                                </div>

                                <div className="p-4">
                                    <div className="flex items-start justify-between">
                                        <div>
                                            <h3 className="font-medium text-light-text dark:text-dark-text truncate">
                                                {gentab.name}
                                            </h3>
                                            <p className="text-xs text-light-muted dark:text-dark-muted mt-0.5">
                                                {gentab.type}
                                            </p>
                                        </div>

                                        <div className="relative">
                                            <button
                                                onClick={(e) => {
                                                    e.stopPropagation()
                                                    setMenuOpen(menuOpen === gentab.id ? null : gentab.id)
                                                }}
                                                className="p-1 rounded hover:bg-black/5 dark:hover:bg-white/5"
                                            >
                                                <MoreVertical className="w-4 h-4 text-light-muted dark:text-dark-muted" />
                                            </button>

                                            {menuOpen === gentab.id && (
                                                <div className="absolute right-0 top-8 w-36 bg-white dark:bg-dark-surface border border-light-border dark:border-dark-border rounded-lg shadow-lg z-10 py-1">
                                                    <button
                                                        onClick={(e) => {
                                                            e.stopPropagation()
                                                            handleExport(gentab)
                                                        }}
                                                        className="w-full px-3 py-2 text-left text-sm hover:bg-light-panel dark:hover:bg-dark-panel flex items-center gap-2"
                                                    >
                                                        <Download className="w-4 h-4" />
                                                        Export
                                                    </button>
                                                    <button
                                                        onClick={(e) => {
                                                            e.stopPropagation()
                                                            handleDelete(gentab.id)
                                                        }}
                                                        className="w-full px-3 py-2 text-left text-sm hover:bg-light-panel dark:hover:bg-dark-panel flex items-center gap-2 text-red-500"
                                                    >
                                                        <Trash2 className="w-4 h-4" />
                                                        Delete
                                                    </button>
                                                </div>
                                            )}
                                        </div>
                                    </div>

                                    <div className="flex items-center gap-1 mt-3 text-xs text-light-muted dark:text-dark-muted">
                                        <Clock className="w-3 h-3" />
                                        {formatDate(gentab.modified_at || gentab.created_at)}
                                    </div>
                                </div>
                            </div>
                        ))}
                    </div>
                )}
            </div>
        </div>
    )
}

function formatDate(timestamp) {
    if (!timestamp) return ''
    const date = new Date(timestamp)
    const now = new Date()
    const diffMs = now - date
    const diffDays = Math.floor(diffMs / 86400000)

    if (diffDays === 0) return 'Today'
    if (diffDays === 1) return 'Yesterday'
    if (diffDays < 7) return `${diffDays} days ago`
    return date.toLocaleDateString()
}
