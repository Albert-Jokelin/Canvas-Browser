import Anthropic from '@anthropic-ai/sdk'

export class ClaudeProvider {
    constructor() {
        this.client = null
        this.model = 'claude-sonnet-4-20250514' // Keeping existing model ID from original file
    }

    initialize(apiKey) {
        if (!apiKey) throw new Error('API key required')
        this.client = new Anthropic({
            apiKey,
            dangerouslyAllowBrowser: true
        })
    }

    isInitialized() {
        return this.client !== null
    }

    async chat(userMessage, chatHistory = [], pageContext = []) {
        if (!this.client) throw new Error('Claude not initialized')

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

        const response = await this.client.messages.create({
            model: this.model,
            max_tokens: 1024,
            system: systemPrompt,
            messages
        })

        return response.content[0].text
    }

    async analyzeForSuggestions(pageContext, chatHistory = []) {
        if (!this.client) throw new Error('Claude not initialized')

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

        const response = await this.client.messages.create({
            model: this.model,
            max_tokens: 512,
            messages: [{ role: 'user', content: prompt }]
        })

        try {
            const text = response.content[0].text
            const match = text.match(/\[[\s\S]*\]/)
            return match ? JSON.parse(match[0]) : []
        } catch {
            return []
        }
    }

    async generateGenTab(request, pageContext, type = 'custom') {
        if (!this.client) throw new Error('Claude not initialized')

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

        const response = await this.client.messages.create({
            model: this.model,
            max_tokens: 4096,
            messages: [{ role: 'user', content: prompt }]
        })

        const text = response.content[0].text
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
        if (!this.client) throw new Error('Claude not initialized')

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

        const response = await this.client.messages.create({
            model: this.model,
            max_tokens: 4096,
            messages: [{ role: 'user', content: prompt }]
        })

        const text = response.content[0].text
        const codeMatch = text.match(/```(?:jsx|javascript|js)?\n?([\s\S]*?)\n?```/)
        if (!codeMatch) throw new Error('No code found in response')

        const changesMatch = text.match(/Changes:\s*(.+)/i)

        return {
            code: codeMatch[1].trim(),
            changes: changesMatch ? changesMatch[1].trim() : 'Applied changes'
        }
    }
}
