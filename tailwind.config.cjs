/** @type {import('tailwindcss').Config} */
module.exports = {
    content: [
        "./index.html",
        "./src/**/*.{js,jsx}"
    ],
    darkMode: 'class',
    theme: {
        extend: {
            colors: {
                // Google-style colors
                google: {
                    blue: '#1a73e8',
                    red: '#ea4335',
                    yellow: '#fbbc04',
                    green: '#34a853',
                },
                // Light mode
                light: {
                    bg: '#ffffff',
                    panel: '#f8f9fa',
                    surface: '#ffffff',
                    border: '#dadce0',
                    text: '#202124',
                    muted: '#5f6368',
                },
                // Dark mode
                dark: {
                    bg: '#1a1a1a',
                    panel: '#0f0f0f',
                    surface: '#292929',
                    border: '#3c4043',
                    text: '#e8eaed',
                    muted: '#9aa0a6',
                },
            },
            fontFamily: {
                sans: ['Google Sans', 'Roboto', '-apple-system', 'sans-serif'],
                mono: ['Roboto Mono', 'monospace'],
            },
            animation: {
                'fade-in': 'fadeIn 0.2s ease-out',
                'slide-up': 'slideUp 0.3s ease-out',
                'slide-in-left': 'slideInLeft 0.3s ease-out',
                'slide-in-right': 'slideInRight 0.3s ease-out',
                'pulse-dot': 'pulseDot 1.4s ease-in-out infinite',
                'progress': 'progress 2s ease-in-out infinite',
            },
            keyframes: {
                fadeIn: {
                    '0%': { opacity: '0' },
                    '100%': { opacity: '1' },
                },
                slideUp: {
                    '0%': { opacity: '0', transform: 'translateY(10px)' },
                    '100%': { opacity: '1', transform: 'translateY(0)' },
                },
                slideInLeft: {
                    '0%': { opacity: '0', transform: 'translateX(-20px)' },
                    '100%': { opacity: '1', transform: 'translateX(0)' },
                },
                slideInRight: {
                    '0%': { opacity: '0', transform: 'translateX(20px)' },
                    '100%': { opacity: '1', transform: 'translateX(0)' },
                },
                pulseDot: {
                    '0%, 80%, 100%': { transform: 'scale(0.8)', opacity: '0.5' },
                    '40%': { transform: 'scale(1)', opacity: '1' },
                },
                progress: {
                    '0%': { width: '0%' },
                    '50%': { width: '70%' },
                    '100%': { width: '100%' },
                },
            },
        },
    },
    plugins: [],
}
