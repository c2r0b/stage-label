//
//  Stage_NameApp.swift
//  Stage Name
//
//  Created by c2r0b on 24/12/23.
//

import SwiftUI
import Cocoa

class WindowController: ObservableObject {
    private var settingsWindow: NSWindow?

    func openSettingsWindow(with viewModel: WindowListViewModel) {
        // Check if the settings window is already displayed
        if settingsWindow == nil {
            let settingsView = SettingsView(viewModel: viewModel)
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 580, height: 450),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
            settingsWindow?.center()
            settingsWindow?.title = "Stage Label Settings"
            settingsWindow?.setFrameAutosaveName("Settings")
            settingsWindow?.contentView = NSHostingView(rootView: settingsView)
            settingsWindow?.isReleasedWhenClosed = false
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeSettingsWindow() {
        settingsWindow?.close()
        settingsWindow = nil // Ensure the window is deinitialized
    }
}

@main
struct UtilityApp: App {
    @StateObject private var viewModel = WindowListViewModel()
    @StateObject private var windowController = WindowController()
    
    var body: some Scene {
        MenuBarExtra("Stage Label", systemImage: "character.cursor.ibeam") {
            AppMenu(windowController: windowController, viewModel: viewModel)
        }
    }
}
