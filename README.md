# ZenMux Bar

A native macOS menu bar application to monitor your ZenMux subscription, quotas, and PAYG balance.

## Features
- **Real-time Monitoring**: View your 5-hour, 7-day, and monthly quotas.
- **Balance Tracking**: Check your PAYG credits (Total, Top-up, Bonus).
- **Flow Rates**: Keep an eye on current base and effective flow rates.
- **Beautiful UI**: SwiftUI-based design inspired by the macOS Weather app, featuring cards and progress bars.
- **Secure**: Stores your Management API Key in `UserDefaults`.

## How to Run (Xcode)

1. **Create a new Project**:
   - Open Xcode and choose "App" project for macOS.
   - Name it `ZenMuxBar`.
   - Interface: SwiftUI.
   - Language: Swift.

2. **Add Source Files**:
   - Delete the default `ContentView.swift` and `ZenMuxBarApp.swift` if they exist.
   - Add the following files from this directory to your Xcode project:
     - `Models.swift`
     - `ZenMuxClient.swift`
     - `DashboardView.swift`
     - `ZenMuxBarApp.swift`

3. **Configure as Menu Bar App**:
   - In your project's `Info.plist` (or the Info tab of the Target), add the key:
     `Application is agent (UIElement)` and set it to `YES`. This prevents the app from appearing in the Dock.

4. **Run**:
   - Press `Cmd + R` to build and run.
   - Click the "Z" icon in your menu bar.
   - Go to Settings (gear icon) to paste your `ZENMUX_MANAGEMENT_API_KEY`.

## Requirements
- macOS 13.0 (Ventura) or later (for `MenuBarExtra`).
- Xcode 14.0 or later.
