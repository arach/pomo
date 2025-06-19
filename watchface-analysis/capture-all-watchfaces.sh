#!/bin/bash

# Function to get window bounds and capture screenshot
capture_watchface() {
    local name=$1
    echo "Capturing $name watchface..."
    
    # Get window position and size
    bounds=$(osascript -e '
    tell application "System Events"
        tell process "pomo"
            set frontmost to true
            delay 0.5
            set pos to position of window 1
            set sz to size of window 1
            return (item 1 of pos as string) & "," & (item 2 of pos as string) & "," & (item 1 of sz as string) & "," & (item 2 of sz as string)
        end tell
    end tell')
    
    # Capture screenshot using bounds
    screencapture -R$bounds -x "watchface-analysis/${name}-watchface.png"
    
    # Wait a bit
    sleep 0.5
}

# Function to press a key
press_key() {
    osascript -e "tell application \"System Events\" to keystroke \"$1\""
    sleep 1
}

# Make sure Pomo is in focus
osascript -e 'tell application "System Events" to tell process "pomo" to set frontmost to true'
sleep 1

# Capture all watchfaces by cycling through with 'T' key
# Based on the order in watchface-loader.ts:
# default, rolodex, terminal, retro-digital, retro-lcd, neon

# We're currently on neon, so let's cycle through
capture_watchface "neon-current"

# Press T to go to next (wraps to default)
press_key "t"
capture_watchface "default"

press_key "t"
capture_watchface "rolodex"

press_key "t"
capture_watchface "terminal"

press_key "t"
capture_watchface "retro-digital"

press_key "t"
capture_watchface "retro-lcd"

press_key "t"
capture_watchface "neon-final"

echo "All watchfaces captured!"