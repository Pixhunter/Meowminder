# 🐱 Meowminder

A lightweight menu-bar app for macOS that reminds you to do the little things — drink water, feed the cat, take a break — with a full-screen alert you can't ignore.

## Features

- **Lives in your menu bar** — no Dock icon, no clutter. A walking cat icon shows it's running.
- **Custom reminder rules** — quantity goals (water, calories), checkmarks (feed the cat), start/stop timers (work sessions), or logged durations (sleep).
- **Hard-to-miss alerts** — a full-screen overlay with a pulsing border and sound, dismissed only by tapping a button.
- **Snooze, not just dismiss** — reschedule an alert instead of losing track of it.
- **Sleep-aware scheduling** — reminders pick up correctly after your Mac wakes, without spamming missed alerts.
- **100% local** — all data stays in a JSON file on your Mac. No accounts, no syncing, no tracking.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15+

## Getting Started

1. Open `Meowminder.xcodeproj` in Xcode.
2. Select the **Meowminder** scheme and hit **⌘R** to build and run.
3. Look for the cat in your menu bar — click it to add your first reminder.

## How It Works

Meowminder runs quietly in the background and checks your rules on a schedule. When one's due, a small alert pops up in the center of your screen — sized to stay out of your way, but backed by a full-screen click-catcher so you have to consciously respond. Accept it, snooze it, and get back to what you were doing.

## Data & Privacy

Everything — your rules, history, and settings — is stored locally at:
```
~/Library/Application Support/Meowminder/
```
Nothing leaves your Mac.

## Building a DMG

See the Xcode Organizer (**Product → Archive**) to export a signed app, then package it into a `.dmg` with Disk Utility or `hdiutil` for sharing.
