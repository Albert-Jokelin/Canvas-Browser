import { ClaudeProvider } from './providers/claude'
import { GeminiProvider } from './providers/gemini'

class LLMService {
    constructor() {
        this.provider = null
        this.providerType = 'claude'
    }

    initialize(config) {
        const { provider = 'claude', apiKey, model } = config

        if (this.providerType !== provider || !this.provider) {
            this.providerType = provider
            if (provider === 'gemini') {
                this.provider = new GeminiProvider()
            } else {
                this.provider = new ClaudeProvider()
            }
        }

        if (apiKey) {
            this.provider.initialize(config)
        }
    }

    async listModels() {
        if (!this.isInitialized()) throw new Error('AI not initialized')
        if (this.provider.listModels) {
            return this.provider.listModels()
        }
        return []
    }

    isInitialized() {
        return this.provider && this.provider.isInitialized()
    }

    // Proxy methods
    async chat(...args) {
        if (!this.isInitialized()) throw new Error('AI not initialized')
        return this.provider.chat(...args)
    }

    async analyzeForSuggestions(...args) {
        if (!this.isInitialized()) throw new Error('AI not initialized')
        return this.provider.analyzeForSuggestions(...args)
    }

    async generateGenTab(...args) {
        if (!this.isInitialized()) throw new Error('AI not initialized')
        return this.provider.generateGenTab(...args)
    }

    async refineGenTab(...args) {
        if (!this.isInitialized()) throw new Error('AI not initialized')
        return this.provider.refineGenTab(...args)
    }
}

export const llmService = new LLMService()
