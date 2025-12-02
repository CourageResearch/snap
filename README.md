# Snap

Windows-style window snapping for macOS.

## Features

- **Smart snapping**: Snap to halves, then use up/down to go to quarters (just like Windows)
- **Menu bar app**: Runs quietly in your menu bar
- **Keyboard-driven**: Fast shortcuts for all snap positions

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl + Option + ←` | Snap left half |
| `Ctrl + Option + →` | Snap right half |
| `Ctrl + Option + ↑` | Quarter top (if in half) or maximize |
| `Ctrl + Option + ↓` | Quarter bottom (if in half) |
| `Ctrl + Option + Enter` | Maximize |
| `Ctrl + Option + C` | Center (70%) |

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

## Installation

1. Download `Snap.app` from Releases (or build from source)
2. Move to Applications folder
3. Open Snap
4. Grant Accessibility permissions when prompted

## Build from Source

```bash
swift build -c release
```

The binary will be at `.build/release/Snap`.

## Requirements

- macOS 12.0+
- Accessibility permissions

## License

MIT
