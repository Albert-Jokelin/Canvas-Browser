export class GeminiProvider {
    constructor() {
        this.apiKey = null
        this.model = 'gemini-1.5-flash-latest'
        this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models'
    }

    initialize(config) {
        if (typeof config === 'string') {
            this.apiKey = config
        } else if (config) {
            this.apiKey = config.apiKey
            if (config.model) this.model = config.model
        }

        if (!this.apiKey) throw new Error('API key required')
    }

    async listModels() {
        if (!this.apiKey) throw new Error('Gemini not initialized')

        const url = `${this.baseUrl}?key=${this.apiKey}`
        const response = await fetch(url)

        if (!response.ok) {
            throw new Error(`Failed to list models: ${response.statusText}`)
        }

        const data = await response.json()
        if (!data.models) return []

        return data.models
            .filter(m => m.supportedGenerationMethods?.includes('generateContent'))
            .map(m => m.name.replace('models/', ''))
            .sort()
    }

    isInitialized() {
        return this.apiKey !== null
    }

    async _callApi(messages, systemPrompt = '', jsonMode = false) {
        if (!this.apiKey) throw new Error('Gemini not initialized')

        const contents = messages.map(m => ({
            role: m.role === 'user' ? 'user' : 'model',
            parts: [{ text: m.content }]
        }))

        const payload = {
            contents,
            generationConfig: {
                maxOutputTokens: 4096,
                temperature: 0.7
            }
        }

        if (systemPrompt) {
            payload.systemInstruction = {
                parts: [{ text: systemPrompt }]
            }
        }

        if (jsonMode) {
            payload.generationConfig.responseMimeType = 'application/json'
        }

        const url = `${this.baseUrl}/${this.model}:generateContent?key=${this.apiKey}`

        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        })

        if (!response.ok) {
            const error = await response.json().catch(() => ({ error: { message: response.statusText } }))
            throw new Error(`Gemini API Error: ${error.error?.message || response.statusText}`)
        }

        const data = await response.json()

        if (!data.candidates?.[0]?.content?.parts?.[0]?.text) {
            // Sometimes safety settings block it.
            if (data.promptFeedback?.blockReason) {
                throw new Error(`Blocked by safety settings: ${data.promptFeedback.blockReason}`)
            }
            throw new Error('No response from Gemini')
        }

        return data.candidates[0].content.parts[0].text
    }

    async chat(userMessage, chatHistory = [], pageContext = []) {
        const systemPrompt = `You are Canvas, an AI assistant integrated into a web browser. You help users by:
1. Answering questions about web pages they're viewing
2. Suggesting and creating GenTabs (interactive web applications) based on their browsing
3. Navigating to URLs when requested

When the user asks to visit a URL, respond with: [NAVIGATE: url]
When you detect they might benefit from a GenTab, suggest it naturally.

Current browsing context (recently visited pages):
${pageContext.map(p => `- ${p.title}: ${p.url}`).join('\n') || 'No pages visited yet'}

Be helpful, concise, and proactive in suggestions.`

        const messages = chatHistory.slice(-10).map(m => ({
            role: m.role,
            content: m.content
        }))
        messages.push({ role: 'user', content: userMessage })

        return this._callApi(messages, systemPrompt)
    }

    async analyzeForSuggestions(pageContext, chatHistory = []) {
        const prompt = `Analyze this browsing session and suggest 2-3 relevant GenTab applications.

Recently visited pages:
${pageContext.map(p => `- ${p.title}: ${p.url}\n  Summary: ${p.summary || 'No summary'}`).join('\n')}

Recent chat:
${chatHistory.slice(-5).map(m => `${m.role}: ${m.content}`).join('\n')}

Return suggestions as JSON array:
[
  {
    "type": "Trip Planner",
    "title": "Japan Trip Itinerary",
    "description": "Organize your Japan research into an interactive itinerary",
    "icon": "🗺️",
    "priority": "high"
  }
]

Return ONLY valid JSON, no other text.`

        const text = await this._callApi([{ role: 'user', content: prompt }], '', true)

        try {
            // If jsonMode works, text should be pure JSON. 
            // But sometimes it wraps in markdown code block even with mimeType set (rarely for 1.5 flash, but good to be safe)
            const jsonText = text.replace(/```json\n?|\n?```/g, '').trim()
            return JSON.parse(jsonText)
        } catch {
            return []
        }
    }

    async generateGenTab(request, pageContext, type = 'custom') {
        const contextInfo = pageContext.map(p => `
- ${p.title}
  URL: ${p.url}
  Summary: ${p.summary || 'No summary available'}
`).join('\n')

        const prompt = `You are building a GenTab - an interactive web application inside a browser.

User Request: "${request}"

Context from browsing history:
${contextInfo}

Generate a complete, production-ready React component that:
1. Is a fully functional, interactive application
2. Uses modern React hooks (useState, useEffect, useMemo, useCallback)
3. Is styled beautifully with Tailwind CSS utility classes
4. Incorporates data from the context pages above
5. Includes source attribution (shows which data came from which URL)
6. Has smooth animations and excellent UX
7. Works in both light and dark mode

IMPORTANT:
- Component must be named "GenTab"
- Use export default GenTab at the end
- Use ONLY these available libraries:
  - React (useState, useEffect, useMemo, useCallback, useRef)
  - lucide-react (for icons: import { Icon } from 'lucide-react')
  - recharts (for charts: import { LineChart, BarChart, ... } from 'recharts')
- DO NOT use any other imports or external APIs
- Include inline data extracted from context (hardcode the data)
- Make it visually stunning with gradients, shadows, and animations

Return ONLY the complete React component code inside a code block.
Start with: \`\`\`jsx
End with: \`\`\`

Also provide:
Title: [short title for this GenTab]
Description: [one sentence description]`

        const text = await this._callApi([{ role: 'user', content: prompt }])

        const codeMatch = text.match(/```(?:jsx|javascript|js)?\n?([\s\S]*?)\n?```/)
        if (!codeMatch) throw new Error('No code found in response')

        const titleMatch = text.match(/Title:\s*(.+)/i)
        const descMatch = text.match(/Description:\s*(.+)/i)

        return {
            id: Date.now().toString(),
            name: titleMatch ? titleMatch[1].trim() : 'Generated App',
            type,
            description: descMatch ? descMatch[1].trim() : '',
            component_code: codeMatch[1].trim(),
            sources: pageContext.map(p => ({ url: p.url, title: p.title })),
            created_at: Date.now(),
            modified_at: Date.now()
        }
    }

    async refineGenTab(currentCode, request, sources = []) {
        const prompt = `Refine this GenTab component based on user request.

Current code:
\`\`\`jsx
${currentCode}
\`\`\`

User wants: "${request}"

Requirements:
- Maintain all existing functionality unless explicitly asked to remove
- Keep component named "GenTab" with export default
- Use only React hooks and Tailwind CSS
- Ensure smooth transitions for UI updates
- Keep source attributions intact

Return the complete updated component code inside a code block.
Also briefly describe what you changed:
Changes: [summary of changes]`

        const text = await this._callApi([{ role: 'user', content: prompt }])

        const codeMatch = text.match(/```(?:jsx|javascript|js)?\n?([\s\S]*?)\n?```/)
        if (!codeMatch) throw new Error('No code found in response')

        const changesMatch = text.match(/Changes:\s*(.+)/i)

        return {
            code: codeMatch[1].trim(),
            changes: changesMatch ? changesMatch[1].trim() : 'Applied changes'
        }
    }
}
