# StreakByte

A tiny native macOS menu-bar companion for building a one-LeetCode-question-per-day habit.

## What it does

- Opens a small dashboard and also lives quietly in the menu bar
- Sends a daily local notification at your chosen time
- Opens the LeetCode Easy problem list in one click
- Tracks today, current streak, personal best, and the last seven days
- Gets increasingly judgmental later in the evening
- Stores everything locally on your Mac

## Run it

Requires macOS 13 or newer. Full Xcode is **not** required.

```bash
chmod +x build.sh
./build.sh
open build/StreakByte.app
```

The first launch opens the dashboard and asks for notification permission. Close or hide the window whenever you like; the flame icon remains in the menu bar.

To start it automatically: **System Settings → General → Login Items**, click `+`, then choose `build/StreakByte.app`.

## Why a menu-bar app first?

macOS absolutely supports desktop widgets, but a real WidgetKit extension must be built and signed through full Xcode. This version works with the command-line tools already installed on this Mac and stays visible from every workspace. The model and UI are intentionally kept in SwiftUI so a WidgetKit target can be added later without redesigning the app.

## Deliberate v1 trade-off

Completion is a one-click check-in instead of scraping LeetCode. It is private, reliable, and needs no LeetCode credentials. A future version could verify submissions through LeetCode's public profile data, but that would require a username and network access.
