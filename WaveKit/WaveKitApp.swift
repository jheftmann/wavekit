import SwiftUI

@main
struct WaveKitApp: App {
    @StateObject private var api = SurflineAPI.shared
    @StateObject private var favoritesStore = FavoritesStore.shared
    @StateObject private var authManager = AuthManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                api: api,
                favoritesStore: favoritesStore,
                authManager: authManager
            )
        } label: {
            #if DEBUG
            Label("WaveKit", systemImage: "water.waves.slash")
            #else
            Label("WaveKit", systemImage: "water.waves")
            #endif
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

extension View {
    func enableKeyboardInput() -> some View {
        modifier(KeyboardInputModifier())
    }
}
