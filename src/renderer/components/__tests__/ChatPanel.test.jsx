import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { ChatPanel } from '../ChatPanel'
import { AppProvider, useAppContext } from '../../context/AppContext'

// Mock subcomponents
vi.mock('../SuggestionCard', () => ({
    SuggestionCard: () => <div data-testid="suggestion-card">Suggestion</div>
}))

vi.mock('../services/llm', () => ({
    llmService: {
        isInitialized: vi.fn(),
        chat: vi.fn(),
        analyzeForSuggestions: vi.fn(),
        generateGenTab: vi.fn()
    }
}))

// Mock context hook
vi.mock('../../context/AppContext', async (importOriginal) => {
    const actual = await importOriginal()
    return {
        ...actual,
        useAppContext: vi.fn()
    }
})

describe('ChatPanel', () => {
    const mockSetRightPanelMode = vi.fn()
    const mockSetCurrentUrl = vi.fn()
    const mockUpdateTab = vi.fn()
    const mockAddMessage = vi.fn()
    const mockSetInput = vi.fn()

    const defaultContext = {
        chatMessages: [],
        addMessage: mockAddMessage,
        clearChat: vi.fn(),
        isTyping: false,
        setIsTyping: vi.fn(),
        suggestions: [],
        setSuggestions: vi.fn(),
        settings: { autoSuggestions: true },
        setCurrentUrl: mockSetCurrentUrl,
        setRightPanelMode: mockSetRightPanelMode,
        pageContext: [],
        activeTabId: '1',
        updateTab: mockUpdateTab,
        isGenerating: false,
        setIsGenerating: vi.fn(),
        saveGenTab: vi.fn(),
        openGenTab: vi.fn()
    }

    beforeEach(() => {
        vi.clearAllMocks()
        useAppContext.mockReturnValue(defaultContext)
    })

    it('renders input field', () => {
        render(<ChatPanel />)
        expect(screen.getByPlaceholderText(/Type a prompt/i)).toBeInTheDocument()
    })

    it('detects URL like www.google.com and switches mode', async () => {
        render(<ChatPanel />)

        const input = screen.getByPlaceholderText(/Type a prompt/i)
        fireEvent.change(input, { target: { value: 'www.google.com' } })

        // Using closest form since button might not have accessible name
        const form = input.closest('form')
        fireEvent.submit(form)

        // Check if navigation happened
        expect(mockSetCurrentUrl).toHaveBeenCalledWith(expect.stringMatching(/https:\/\/www.google.com/))
        expect(mockSetRightPanelMode).toHaveBeenCalledWith('browser')
        // Should NOT call chat API
        expect(mockAddMessage).toHaveBeenCalledWith(expect.stringMatching('user'), expect.stringMatching(/Navigate to/))
    })

    it('detects regular text as chat', async () => {
        render(<ChatPanel />)

        const input = screen.getByPlaceholderText(/Type a prompt/i)
        fireEvent.change(input, { target: { value: 'Hello world' } })

        const form = input.closest('form')
        fireEvent.submit(form)

        // Should NOT navigate
        expect(mockSetCurrentUrl).not.toHaveBeenCalled()
        expect(mockSetRightPanelMode).not.toHaveBeenCalled()
        // Should add message
        expect(mockAddMessage).toHaveBeenCalledWith('user', 'Hello world')
    })
})
