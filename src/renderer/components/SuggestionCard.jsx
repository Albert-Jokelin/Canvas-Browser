import { X, ArrowRight, Loader2 } from 'lucide-react'

export function SuggestionCard({ suggestion, onGenerate, onDismiss, isLoading }) {
    return (
        <div className="suggestion-card flex items-start gap-3 animate-slide-in-left">
            <span className="text-2xl">{suggestion.icon}</span>
            <div className="flex-1 min-w-0">
                <h4 className="font-medium text-sm text-light-text dark:text-dark-text">
                    {suggestion.type}
                </h4>
                <p className="text-xs text-light-muted dark:text-dark-muted line-clamp-2">
                    {suggestion.description}
                </p>
            </div>
            <div className="flex items-center gap-1 shrink-0">
                <button
                    onClick={onGenerate}
                    disabled={isLoading}
                    className="px-2.5 py-1.5 rounded-lg bg-google-blue text-white text-xs font-medium 
                     hover:bg-blue-600 transition-colors flex items-center gap-1 disabled:opacity-50"
                >
                    {isLoading ? (
                        <Loader2 className="w-3 h-3 animate-spin" />
                    ) : (
                        <>
                            Generate
                            <ArrowRight className="w-3 h-3" />
                        </>
                    )}
                </button>
                <button
                    onClick={onDismiss}
                    className="p-1 rounded hover:bg-black/5 dark:hover:bg-white/5"
                >
                    <X className="w-3.5 h-3.5 text-light-muted dark:text-dark-muted" />
                </button>
            </div>
        </div>
    )
}
