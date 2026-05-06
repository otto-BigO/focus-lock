# FocusLock

A minimal macOS focus app that blocks distracting apps and websites for a timed session.

## What it does

FocusLock helps you lock in for a set amount of time by:

- blocking selected apps during a focus session
- blocking selected websites using `/etc/hosts`
- showing a timer and session progress UI
- restoring access automatically when the session ends
- showing a completion notification when you're done

## Features

- macOS app picker for installed apps
- website presets for common distractions
- custom website blocking
- glassy SwiftUI interface
- session countdown with progress ring
- automatic re-blocking if a blocked app is reopened

## How it works

- **Apps:** FocusLock watches for running/just-launched apps and force-quits the ones you selected.
- **Websites:** It temporarily writes blocked domains to `/etc/hosts`, then removes them when the session ends.

## Permissions

FocusLock needs:

- **Accessibility access** — to quit blocked apps
- **Admin access** — to update `/etc/hosts` for website blocking
- **Notification permission** — to alert you when a session is complete

## Tech

- SwiftUI
- AppKit
- macOS Accessibility APIs
- UserNotifications

## Status

Work in progress, but the core idea is already there: make distraction harder and focus easier.
