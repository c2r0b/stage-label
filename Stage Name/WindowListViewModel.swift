//
//  WindowListViewModel.swift
//  Stage Label
//
//  Created by c2r0b on 19/04/24.
//

import SwiftUI
import Quartz
import os

class WindowListViewModel: ObservableObject {
    public var windowManager = WindowManager()
    
    private var lastActiveAppPID: Int32 = 0
    private var lastKnownScreen: NSScreen?
    private var updating: Bool = false
    private var pollTimer: Timer?
    
    init() {
        DispatchQueue.main.async {
            self.setupObservers()
            self.fetchInitialData()
        }
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    private func setupObservers() {
        self.startWindowChangeMonitoring()
        self.startPolling()
    }
    
    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkFrontmostWindow()
        }
    }
    
    private func fetchInitialData() {
        UserPreferencesManager.shared.loadTextFieldValues()
        UserPreferencesManager.shared.loadTextFieldSize()
        UserPreferencesManager.shared.loadColors()
        self.windowManager.fetchWindows()
    }
    
    func startWindowChangeMonitoring() {
        // Set up an observer for when the active application changes
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(focusedWindowChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        // Observe application hiding
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(windowDidChange),
            name: NSWorkspace.didHideApplicationNotification,
            object: nil
        )
        
        // Observe application unhiding
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(windowDidChange),
            name: NSWorkspace.didUnhideApplicationNotification,
            object: nil
        )
        
        // Observe screen configuration changes
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(windowDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        // Subscribe to application launch and termination notifications
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(windowDidChange), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(windowDidChange), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        
    }
    
    @objc func windowDidChange() {
        os_log("windowDidMove called")
        if self.windowManager.updating == true {
            return
        }
        
        // Fade out existing windows
        if (UserPreferencesManager.shared.isFadeEnabled) {
            fadeOutWindows(windows: self.windowManager.invisibleWindows)
        }
        self.windowManager.updating = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Adjust the delay as needed
            os_log("Calling fetchWindows from windowDidMove on main thread")
            self.windowManager.fetchWindows()
        }
    }
    
    func checkFrontmostWindow() {
        DispatchQueue.main.async {
            var screenChanged = false
            let activeScreen = getActiveScreen()
            if (activeScreen != self.lastKnownScreen) {
                self.lastKnownScreen = activeScreen
                screenChanged = true
            }
            
            guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
                return
            }
            
            let frontmostAppPid = frontmostApp.processIdentifier
            
            if let windows = getAllWindows() {
                for window in windows {
                    if let windowID = window[kCGWindowNumber as String] as? CGWindowID,
                       let name = window[kCGWindowOwnerName as String] as? String,
                       let (x, y, width, height) = getWindowPosition(window: window) {
                        let wasStageManaged = self.windowManager.wasWindowStageManaged[windowID]
                        let isStageManaged = isLikelyStageManagerGroup(x: x, y:y, width: width, height: height)
                        self.windowManager.wasWindowStageManaged[windowID] = isStageManaged
                        
                        // Check if the minimized state changed
                        if wasStageManaged != isStageManaged {
                            print("Window \(name) minimized state changed")
                            self.windowDidChange()
                            return
                        }
                    }
                }
            }
            
            for window in getWindowsFromPID(pid: frontmostAppPid) {
                if let windowID = window[kCGWindowNumber as String] as? CGWindowID,
                   let name = window[kCGWindowOwnerName as String] as? String,
                   let (x, y, width, height) = getWindowPosition(window: window) {
                    
                    // Check if the window screen changed
                    if screenChanged {
                        let windowScreen = getWindowScreen(window: window)
                        if windowScreen != self.windowManager.windowScreen[windowID] {
                            print("Application was likely moved to another screen:\(name) \(String(describing: self.windowManager.windowScreen[windowID])) \(String(describing: windowScreen))")
                            self.windowDidChange()
                        }
                    }
                    
                    // Check if window is on top of stage manager
                    if !isLikelyStageManagerGroup(x: x, y:y, width: width, height: height) {
                        if isLikelyOnStageManagerArea(x: x, y:y, width: width, height: height) {
                            let windowFrame = CGRect(x: x, y: y, width: width, height: height)
                            print("Is on top of stage manager area: \(name) \(x)")
                            hideInvisibleWindowsIfOnScreen(windowFrame, windows: self.windowManager.invisibleWindows)
                            return
                        }
                    }
                }
            }
            if self.updating == false {
                showInvisibleWindows(windows: self.windowManager.invisibleWindows)
            }
        }
    }
    
    @objc private func focusedWindowChanged(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        let currentPid = app.processIdentifier
        print("Activated application PID: \(currentPid)")
        
        // Check if the currently focused app was in stage manager
        for window in self.windowManager.filterWindowsOnActiveScreen(windows: getWindowsFromPID(pid: currentPid)) {
            if let name = window[kCGWindowOwnerName as String] as? String,
               let (x, y, width, height) = getWindowPosition(window: window) {
                
                print("Frontmost changed, (new) windows: \(name), \(width)")
                if isLikelyStageManagerGroup(x: x, y: y, width: width, height: height) {
                    print("New application was likely a Stage Manager group: \(name) \(width)")
                    self.windowDidChange()
                    return
                }
            }
        }
        
        // Check if the previously focused app is now in stage manager
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.lastActiveAppPID = currentPid
            for window in self.windowManager.filterWindowsOnActiveScreen(windows: getWindowsFromPID(pid: self.lastActiveAppPID)) {
                if let name = window[kCGWindowOwnerName as String] as? String,
                   let (x, y, width, height) = getWindowPosition(window: window) {
                    
                    print("Frontmost changed, (old) windows: \(name), \(width)")
                    if isLikelyStageManagerGroup(x: x, y: y, width: width, height: height) {
                        print("Old application is now likely a Stage Manager group: \(name) \(width)")
                        self.windowDidChange()
                        return
                    }
                }
            }
        }
    }
}
