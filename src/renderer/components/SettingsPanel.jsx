import { useState } from 'react'
import {
    ArrowLeft,
    Key,
    Moon,
    Sun,
    Eye,
    EyeOff,
    Sparkles,
    Trash2,
    Check,
    AlertCircle,
    Bot
} from 'lucide-react'
import { useAppContext } from '../context/AppContext'
import { llmService } from '../services/llm'

export function SettingsPanel() {
    const { settings, updateSettings, setRightPanelMode, theme, setTheme } = useAppContext()
    const [formData, setFormData] = useState(settings)
    const [showKey, setShowKey] = useState(false)
    const [testResult, setTestResult] = useState(null)
    const [testing, setTesting] = useState(false)

    const handleSave = async () => {
        await updateSettings(formData)
        const provider = formData.provider || 'claude'
        const apiKey = provider === 'gemini' ? formData.geminiApiKey : formData.apiKey
        const model = provider === 'gemini' ? formData.geminiModel : undefined

        if (apiKey) {
            try {
                llmService.initialize({ provider, apiKey, model })
            } catch (e) {
                console.error('Failed to init AI:', e)
            }
        }
        setRightPanelMode('browser')
    }

    const testApiKey = async () => {
        const provider = formData.provider || 'claude'
        const apiKey = provider === 'gemini' ? formData.geminiApiKey : formData.apiKey

        if (!apiKey) {
            setTestResult({ success: false, message: 'Please enter an API key' })
            return
        }

        setTesting(true)
        setTestResult(null)

        try {
            // Re-initialize with current form data to test
            llmService.initialize({ provider, apiKey })
            // For Gemini/Claude, this is mostly local validation, but that's what was there.
            setTestResult({ success: true, message: 'Configuration valid!' })
        } catch (e) {
            setTestResult({ success: false, message: e.message })
        } finally {
            setTesting(false)
        }
    }

    const currentProvider = formData.provider || 'claude'

    return (
        <div className="h-full overflow-y-auto">
            <div className="max-w-xl mx-auto p-6">
                {/* Header */}
                <div className="flex items-center gap-4 mb-8">
                    <button
                        onClick={() => setRightPanelMode('browser')}
                        className="p-2 hover:bg-black/5 dark:hover:bg-white/5 rounded-lg"
                    >
                        <ArrowLeft className="w-5 h-5" />
                    </button>
                    <h1 className="text-xl font-semibold">Settings</h1>
                </div>

                <div className="space-y-8">
                    {/* AI Configuration */}
                    <section className="bg-light-panel dark:bg-dark-surface rounded-xl p-6">
                        {/* Provider Selection */}
                        <div className="mb-6 border-b border-light-border dark:border-dark-border pb-6">
                            <div className="flex items-center gap-3 mb-4">
                                <div className="w-10 h-10 rounded-lg bg-google-blue/10 flex items-center justify-center">
                                    <Bot className="w-5 h-5 text-google-blue" />
                                </div>
                                <div>
                                    <h2 className="font-medium">AI Model</h2>
                                    <p className="text-xs text-light-muted dark:text-dark-muted">Select your intelligence provider</p>
                                </div>
                            </div>

                            <select
                                value={currentProvider}
                                onChange={(e) => setFormData({ ...formData, provider: e.target.value })}
                                className="w-full input-primary"
                            >
                                <option value="claude">Anthropic Claude (Sonnet 3.5)</option>
                                <option value="gemini">Google Gemini (Flash 1.5)</option>
                            </select>
                        </div>

                        {/* API Key */}
                        <div>
                            <div className="flex items-center gap-3 mb-4">
                                <div className="w-10 h-10 rounded-lg bg-google-blue/10 flex items-center justify-center">
                                    <Key className="w-5 h-5 text-google-blue" />
                                </div>
                                <div>
                                    <h2 className="font-medium">{currentProvider === 'gemini' ? 'Gemini API Key' : 'Claude API Key'}</h2>
                                    <p className="text-xs text-light-muted dark:text-dark-muted">
                                        {currentProvider === 'gemini'
                                            ? 'Required for Google AI Studio'
                                            : 'Required for Anthropic API'}
                                    </p>
                                </div>
                            </div>

                            <div className="space-y-3">
                                <div className="relative">
                                    <input
                                        type={showKey ? 'text' : 'password'}
                                        value={currentProvider === 'gemini' ? (formData.geminiApiKey || '') : (formData.apiKey || '')}
                                        onChange={(e) => {
                                            if (currentProvider === 'gemini') {
                                                setFormData({ ...formData, geminiApiKey: e.target.value })
                                            } else {
                                                setFormData({ ...formData, apiKey: e.target.value })
                                            }
                                        }}
                                        placeholder={currentProvider === 'gemini' ? "AIza..." : "sk-ant-..."}
                                        className="input-primary pr-10"
                                    />
                                    <button
                                        onClick={() => setShowKey(!showKey)}
                                        className="absolute right-3 top-1/2 -translate-y-1/2"
                                    >
                                        {showKey ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                                    </button>
                                </div>

                                {currentProvider === 'gemini' && (
                                    <div className="flex gap-2">
                                        <div className="flex-1">
                                            <label className="text-xs text-light-muted dark:text-dark-muted mb-1 block">Gemini Model</label>
                                            <div className="relative">
                                                <select
                                                    value={formData.geminiModel || 'gemini-1.5-flash-latest'}
                                                    onChange={(e) => setFormData({ ...formData, geminiModel: e.target.value })}
                                                    className="w-full input-primary"
                                                >
                                                    <option value="gemini-1.5-flash-latest">Flash 1.5 (Default)</option>
                                                    {formData.availableModels?.map(m => (
                                                        <option key={m} value={m}>{m}</option>
                                                    ))}
                                                </select>
                                                <button
                                                    onClick={async () => {
                                                        if (!formData.geminiApiKey) return
                                                        setTesting(true)
                                                        try {
                                                            llmService.initialize({ provider: 'gemini', apiKey: formData.geminiApiKey })
                                                            const models = await llmService.listModels()
                                                            setFormData(prev => ({ ...prev, availableModels: models }))
                                                            setTestResult({ success: true, message: `Found ${models.length} models` })
                                                        } catch (e) {
                                                            setTestResult({ success: false, message: e.message })
                                                        } finally {
                                                            setTesting(false)
                                                        }
                                                    }}
                                                    disabled={!formData.geminiApiKey || testing}
                                                    className="absolute right-1 top-1 p-1.5 rounded hover:bg-black/5 dark:hover:bg-white/5 text-xs text-google-blue"
                                                >
                                                    Refresh
                                                </button>
                                            </div>
                                        </div>
                                    </div>
                                )}

                                {testResult && (
                                    <div className={`flex items-center gap-2 text-sm ${testResult.success ? 'text-green-600' : 'text-red-500'}`}>
                                        {testResult.success ? <Check className="w-4 h-4" /> : <AlertCircle className="w-4 h-4" />}
                                        {testResult.message}
                                    </div>
                                )}

                                <div className="flex items-center justify-between">
                                    <a
                                        href={currentProvider === 'gemini' ? "https://aistudio.google.com/app/apikey" : "https://console.anthropic.com/settings/keys"}
                                        target="_blank"
                                        rel="noopener noreferrer"
                                        className="text-sm text-google-blue hover:underline"
                                    >
                                        Get API key →
                                    </a>
                                    <button
                                        onClick={testApiKey}
                                        disabled={testing}
                                        className="btn-secondary text-sm"
                                    >
                                        {testing ? 'Testing...' : 'Test Key'}
                                    </button>
                                </div>
                            </div>
                        </div>
                    </section>

                    {/* Appearance */}
                    <section className="bg-light-panel dark:bg-dark-surface rounded-xl p-6">
                        <div className="flex items-center gap-3 mb-4">
                            <div className="w-10 h-10 rounded-lg bg-purple-500/10 flex items-center justify-center">
                                {theme === 'dark' ? <Moon className="w-5 h-5 text-purple-500" /> : <Sun className="w-5 h-5 text-purple-500" />}
                            </div>
                            <div>
                                <h2 className="font-medium">Appearance</h2>
                                <p className="text-xs text-light-muted dark:text-dark-muted">Theme preferences</p>
                            </div>
                        </div>

                        <div className="grid grid-cols-2 gap-3">
                            <button
                                onClick={() => setTheme('light')}
                                className={`p-4 rounded-xl border text-left transition-all ${theme === 'light'
                                    ? 'border-google-blue bg-google-blue/5'
                                    : 'border-light-border dark:border-dark-border hover:border-light-muted'
                                    }`}
                            >
                                <Sun className="w-5 h-5 mb-2" />
                                <p className="font-medium text-sm">Light</p>
                            </button>
                            <button
                                onClick={() => setTheme('dark')}
                                className={`p-4 rounded-xl border text-left transition-all ${theme === 'dark'
                                    ? 'border-google-blue bg-google-blue/5'
                                    : 'border-light-border dark:border-dark-border hover:border-light-muted'
                                    }`}
                            >
                                <Moon className="w-5 h-5 mb-2" />
                                <p className="font-medium text-sm">Dark</p>
                            </button>
                        </div>
                    </section>

                    {/* GenTabs */}
                    <section className="bg-light-panel dark:bg-dark-surface rounded-xl p-6">
                        <div className="flex items-center gap-3 mb-4">
                            <div className="w-10 h-10 rounded-lg bg-green-500/10 flex items-center justify-center">
                                <Sparkles className="w-5 h-5 text-green-500" />
                            </div>
                            <div>
                                <h2 className="font-medium">GenTabs</h2>
                                <p className="text-xs text-light-muted dark:text-dark-muted">AI app generation settings</p>
                            </div>
                        </div>

                        <div className="space-y-4">
                            <label className="flex items-center justify-between">
                                <span className="text-sm">Auto-suggestions</span>
                                <button
                                    onClick={() => setFormData({ ...formData, autoSuggestions: !formData.autoSuggestions })}
                                    className={`w-10 h-5 rounded-full transition-colors ${formData.autoSuggestions ? 'bg-google-blue' : 'bg-light-border dark:bg-dark-border'
                                        }`}
                                >
                                    <div className={`w-4 h-4 rounded-full bg-white shadow transition-transform ${formData.autoSuggestions ? 'translate-x-5' : 'translate-x-0.5'
                                        }`} />
                                </button>
                            </label>

                            <label className="flex items-center justify-between">
                                <span className="text-sm">Show source attributions</span>
                                <button
                                    onClick={() => setFormData({ ...formData, showSources: !formData.showSources })}
                                    className={`w-10 h-5 rounded-full transition-colors ${formData.showSources ? 'bg-google-blue' : 'bg-light-border dark:bg-dark-border'
                                        }`}
                                >
                                    <div className={`w-4 h-4 rounded-full bg-white shadow transition-transform ${formData.showSources ? 'translate-x-5' : 'translate-x-0.5'
                                        }`} />
                                </button>
                            </label>
                        </div>
                    </section>

                    {/* Privacy */}
                    <section className="bg-light-panel dark:bg-dark-surface rounded-xl p-6">
                        <div className="flex items-center gap-3 mb-4">
                            <div className="w-10 h-10 rounded-lg bg-red-500/10 flex items-center justify-center">
                                <Trash2 className="w-5 h-5 text-red-500" />
                            </div>
                            <div>
                                <h2 className="font-medium">Privacy</h2>
                                <p className="text-xs text-light-muted dark:text-dark-muted">Data management</p>
                            </div>
                        </div>

                        <button className="px-4 py-2 rounded-lg bg-red-500/10 text-red-500 text-sm font-medium hover:bg-red-500/20 transition-colors">
                            Clear All Data
                        </button>
                    </section>

                    {/* Save */}
                    <div className="flex justify-end gap-3">
                        <button
                            onClick={() => setRightPanelMode('browser')}
                            className="btn-secondary"
                        >
                            Cancel
                        </button>
                        <button onClick={handleSave} className="btn-primary">
                            <Check className="w-4 h-4" />
                            Save Changes
                        </button>
                    </div>
                </div>
            </div>
        </div>
    )
}
