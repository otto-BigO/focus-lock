# FocusLock

A macOS focus app that blocks distracting apps and websites for a timed session.

## What it does

During a session, FocusLock:

- blocks the apps you picked
- blocks the websites you picked using `/etc/hosts`
- shows a timer and session progress
- restores access when the session ends
- notifies you when you're done

## Features

- macOS app picker for installed apps
- website presets for common distractions
- custom website blocking
- SwiftUI interface
- session countdown with progress ring
- automatic re-blocking if a blocked app is reopened

## How it works

- **Apps:** FocusLock watches for running and just-launched apps and force-quits the ones you selected.
- **Websites:** It writes blocked domains to `/etc/hosts` for the session, then removes them when the timer ends.

## Permissions

FocusLock needs:

- **Accessibility access** to quit blocked apps
- **Admin access** to update `/etc/hosts` for website blocking
- **Notification permission** to alert you when a session ends

## Tech

- SwiftUI
- AppKit
- macOS Accessibility APIs
- UserNotifications

## Status

Work in progress. App blocking, website blocking, and the session timer already work.
