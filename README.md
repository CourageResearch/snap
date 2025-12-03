# Snap

Windows-style window snapping for macOS.

## Features

- **Smart snapping**: Snap to halves, then use up/down to go to quarters (just like Windows)
- **Multi-monitor support**: Move windows between monitors seamlessly
- **Menu bar app**: Runs quietly in your menu bar with a custom icon
- **Preferences window**: Configure launch at login
- **Keyboard-driven**: Fast shortcuts for all snap positions

## Installation

### Homebrew (recommended)

```bash
brew tap CourageResearch/tap
brew install --cask snap
```

### Manual Download

1. Download `Snap.zip` from [Releases](https://github.com/CourageResearch/snap/releases)
2. Unzip and move `Snap.app` to Applications
3. Open Snap
4. Grant Accessibility permissions when prompted

## Keyboard Shortcuts

### Snapping

| Shortcut | Action |
|----------|--------|
| `Ctrl + Option + ←` | Snap left half |
| `Ctrl + Option + →` | Snap right half |
| `Ctrl + Option + ↑` | Quarter top (if in half) or maximize |
| `Ctrl + Option + ↓` | Quarter bottom (if in half) |
| `Ctrl + Option + Enter` | Maximize |
| `Ctrl + Option + C` | Center (70%) |

### Multi-Monitor

| Shortcut | Action |
|----------|--------|
| `Ctrl + Option + Shift + ←` | Move window to previous monitor |
| `Ctrl + Option + Shift + →` | Move window to next monitor |

**Bonus**: When snapped to the left edge, pressing `Ctrl + Option + ←` again moves the window to the right half of the previous monitor (and vice versa).

### Thirds

| Shortcut | Action |
|----------|--------|
| `Ctrl + Option + Cmd + 1` | Left third |
| `Ctrl + Option + Cmd + 2` | Center third |
| `Ctrl + Option + Cmd + 3` | Right third |
| `Ctrl + Option + Cmd + 4` | Left two-thirds |
| `Ctrl + Option + Cmd + 5` | Right two-thirds |

## How It Works

1. Press `Ctrl + Option + ←` to snap a window to the left half
2. Press `Ctrl + Option + ↑` to move it to the top-left quarter
3. Press `Ctrl + Option + →` to move it to the top-right quarter

No separate shortcuts for corners - it figures out what you want based on the current position.

## Build from Source

```bash
swift build -c release
cp .build/release/Snap Snap.app/Contents/MacOS/Snap
open Snap.app
```

## Requirements

- macOS 12.0+
- Accessibility permissions

## License

MIT
