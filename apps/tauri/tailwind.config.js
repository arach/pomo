/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        background: 'hsl(240, 10%, 3.9%)',
        foreground: 'hsl(0, 0%, 98%)',
        border: 'hsl(240, 3.7%, 15.9%)',
        primary: {
          DEFAULT: 'hsl(217.2, 91.2%, 59.8%)',
          foreground: 'hsl(222.2, 47.4%, 11.2%)',
        },
        secondary: {
          DEFAULT: 'hsl(240, 3.7%, 15.9%)',
          foreground: 'hsl(0, 0%, 98%)',
        },
        muted: {
          DEFAULT: 'hsl(240, 3.7%, 15.9%)',
          foreground: 'hsl(240, 5%, 64.9%)',
        },
      },
      keyframes: {
        'fade-in': {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        'ping': {
          '75%, 100%': {
            transform: 'scale(2)',
            opacity: '0',
          },
        },
      },
      animation: {
        'fade-in': 'fade-in 0.2s ease-out',
        'ping': 'ping 1s cubic-bezier(0, 0, 0.2, 1) infinite',
      },
      animationDelay: {
        '200': '200ms',
        '400': '400ms',
      },
    },
  },
  plugins: [],
}