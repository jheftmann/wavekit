import SwiftUI

@main
struct WaveKitApp: App {
    @StateObject private var api = SurflineAPI.shared
    @StateObject private var favoritesStore = FavoritesStore.shared
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var locationManager = LocationManager.shared

    init() {
        Task {
            await SurflineAPI.shared.fetchForecasts(for: FavoritesStore.shared.spots)
            CalendarManager.shared.syncAll(forecasts: SurflineAPI.shared.forecasts)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                api: api,
                favoritesStore: favoritesStore,
                authManager: authManager,
                locationManager: locationManager
            )
            .onChange(of: api.lastUpdated) { _, _ in
                CalendarManager.shared.syncAll(forecasts: api.forecasts)
            }
        } label: {
            menuBarIcon
        }
        .menuBarExtraStyle(.window)

        // Settings Window
        Window("Settings", id: "settings") {
            SettingsView(
                authManager: authManager,
                favoritesStore: favoritesStore
            )
            .enableKeyboardInput()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // Login Window
        Window("Sign In", id: "login") {
            LoginView(authManager: authManager)
                .enableKeyboardInput()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // Add Spot Window
        Window("Add Spot", id: "addspot") {
            AddSpotView(favoritesStore: favoritesStore)
                .enableKeyboardInput()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

// Modifier that enables keyboard input for menu bar app windows
struct KeyboardInputModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .onAppear {
                // Set activation policy to regular so windows can receive keyboard input
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            }
            .onDisappear {
                // Check if any other windows are still open
                let hasVisibleWindows = NSApp.windows.contains { window in
                    window.isVisible &&
                    window.className != "NSStatusBarWindow" &&
                    !window.className.contains("MenuBarExtra")
                }

                // If no other windows, go back to accessory mode
                if !hasVisibleWindows {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
    }
}

// MARK: - Menu Bar Icon

private var menuBarNSImage: NSImage? {
    guard let url1x = Bundle.module.url(forResource: "menubar-default",    withExtension: "png", subdirectory: "Images"),
          let url2x = Bundle.module.url(forResource: "menubar-default@2x", withExtension: "png", subdirectory: "Images"),
          let rep1x = NSBitmapImageRep(contentsOfFile: url1x.path),
          let rep2x = NSBitmapImageRep(contentsOfFile: url2x.path) else { return nil }

    // Logical size in points = @1x pixel dimensions.
    // Set @2x rep's size to the same logical size so macOS knows it's
    // a high-DPI variant and picks it automatically on Retina displays.
    let logicalSize = NSSize(width: rep1x.pixelsWide, height: rep1x.pixelsHigh)
    rep2x.size = logicalSize

    let img = NSImage(size: logicalSize)
    img.addRepresentation(rep1x)
    img.addRepresentation(rep2x)
    img.isTemplate = true
    return img
}

private var menuBarIcon: some View {
    Group {
        if let img = menuBarNSImage {
            Image(nsImage: img)
        } else {
            Image(systemName: "water.waves")
        }
    }
}

extension View {
    func enableKeyboardInput() -> some View {
        modifier(KeyboardInputModifier())
    }
}
