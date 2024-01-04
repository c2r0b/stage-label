//
//  ContentView.swift
//  Stage Name
//
//  Created by c2r0b on 24/12/23.
//
import SwiftUI
import Quartz
import os
import Swindler

extension Color {
    var nsColor: NSColor {
        return NSColor(self)
    }
}

class WindowListViewModel: ObservableObject {
    @Published var windowDetails: [WindowInfo] = []
    @Published var groupedWindows: [[WindowInfo]] = []
    var invisibleWindows: [InvisibleWindow] = []
    var textFieldValues: [String: String] = [:]
    
    @Published var textFieldColor: Color = .white
    @Published var backgroundColor: Color = .black
    @Published var backgroundOpacity: Double = 1.0 // Default to full opacity
    @Published var textFieldSize: CGFloat = 14
    @Published var isFadeEnabled = true
    
    var isStageMangerVisible: [String: Bool] = [:]
    
    // Add a mapping from group identifiers to InvisibleWindow
    var windowGroupMapping: [UUID: InvisibleWindow] = [:]
    var groupIdentifierMapping: [String: UUID] = [:]
    
    private var observer: AXObserver?
    private var permissionCheckTimer: Timer?
    
    private var state: Swindler.State?
    
    // Track the screens of the windows
    private var windowScreens: [Int: Swindler.Screen] = [:]
    
    // Mode for when a Stage Manager managed app icon is clicked
    @Published var isZoomedMode: Bool = false
    
    @Published var isAccessibilityPermissionGranted = false
    
    init() {
        // check accessibility permission
        if !AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary) {
            print("Accessibility permissions not granted. Prompting user...")
        }
        
        // Start a timer to periodically check for Accessibility permissions
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkAccessibilityPermissions()
        }
        
        loadTextFieldValues()
        loadTextFieldSize()
        loadColors()
        startWindowChangeMonitoring()
        fetchWindows()
    }
    
    // Method to save the textFieldValues dictionary
    func saveTextFieldValues() {
        if let encoded = try? JSONEncoder().encode(textFieldValues) {
            print("Saved textFields")
            UserDefaults.standard.set(encoded, forKey: "textFieldValues")
        }
    }

    // Method to load the textFieldValues dictionary
    func loadTextFieldValues() {
            if let savedData = UserDefaults.standard.data(forKey: "textFieldValues"),
               let decodedDictionary = try? JSONDecoder().decode([String: String].self, from: savedData) {
                textFieldValues = decodedDictionary
            }
        }
    
    deinit {
        permissionCheckTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    func openSystemPreferencesAccessibility() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
    
    private func checkAccessibilityPermissions() {
        if AXIsProcessTrusted() {
            // Permissions are granted, proceed with functionality
            permissionCheckTimer?.invalidate()
            // Call any function that needs to be executed after getting permissions
            setupAccessibilityObserver()
            isAccessibilityPermissionGranted = true
        } else {
            print("Waiting for Accessibility permissions...")
        }
    }

    private func setupAccessibilityObserver() {
        print("Initialize Swindler...")
        Swindler.initialize().done { state in
            self.state = state
            self.setupWindowEventHandlers(state)
            print("Swindler initialized")
        }.catch { error in
            print("Error initializing Swindler: \(error)")
        }
    }
    
    private func setupWindowEventHandlers(_ state: Swindler.State) {
        // Check if a window is on top of stage manager
        state.on { (event: WindowFrameChangedEvent) in
                let window = event.window
            let screenFrame = window.screen?.applicationFrame
            
            print("Icon clicked?: \(window.title.value)")
                // Check if the window overlaps with the stage manager area
            if self.isLikelyOnStageManagerArea(x: window.frame.value.origin.x - (screenFrame?.origin.x)!,
                                               y: window.frame.value.origin.y - (screenFrame?.origin.y)!,
                                                   width: window.frame.value.width,
                                                   height: window.frame.value.height) {
                self.hideInvisibleWindowsOnScreen(screenFrame!)
                } else {
                    self.showInvisibleWindowsOnScreen(screenFrame!)
                    
                    
                    let currentScreen = window.screen
                // Check if the window has moved to a different screen
                if let originalScreen = self.windowScreens[window.hashValue],
                   originalScreen !== currentScreen {
                    
                    print("Window moved to a different screen: \(window.title.value)")
                    self.fetchWindows()
                }
                
                // Update the tracked screen for this window
                self.windowScreens[window.hashValue] = currentScreen
                
                }
                }
        
        state.on { [weak self] (event: FrontmostApplicationChangedEvent) in
            guard event.external == true, let self = self else {
                // Ignore events that were caused by us.
                return
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { // Adjust the delay as needed
                let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
                if let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [NSDictionary] {
                    for window in windowList {
                        if let name = window[kCGWindowOwnerName as String] as? String,
                           let pid = window[kCGWindowOwnerPID as String] as? Int,
                           let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                           let x = bounds["X"] as? CGFloat,
                           let y = bounds["Y"] as? CGFloat,
                           let width = bounds["Width"] as? CGFloat,
                           let height = bounds["Height"] as? CGFloat {
                            if (pid == event.oldValue!.processIdentifier) {
                                print("Frontmost changed, windows: \(name), \(width)")
                                if self.isLikelyStageManagerGroup(x: x, y: y, width: width, height: height) {
                                    print("Old application is now likely a Stage Manager group: \(name) \(width)")
                                    self.windowDidChange()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func hideInvisibleWindowsOnScreen(_ screenFrame: CGRect) {
        DispatchQueue.main.async {
            for window in self.invisibleWindows {
                if window.isOnScreen(screenFrame) {
                    window.animator().alphaValue = 0 // Hide the window
                }
            }
        }
    }

    func showInvisibleWindowsOnScreen(_ screenFrame: CGRect) {
        DispatchQueue.main.async {
            for window in self.invisibleWindows {
                if window.isOnScreen(screenFrame) {
                    window.animator().alphaValue = 1 // Show the window
                }
            }
        }
    }
    
    @objc private func windowActivated(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        let pid = app.processIdentifier
        print("Activated application PID: \(pid)")
        
        // Assuming your groupedWindows array contains WindowInfo items with valid PIDs
        if groupedWindows.flatMap({ $0 }).contains(where: { $0.pid == pid }) {
            print("Moved possibly grouped window of app with PID: \(pid)")
            windowDidChange()
        }
    }
        
    func startWindowChangeMonitoring() {
        // Set up an observer for when the active application changes
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(windowActivated),
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
    
    func saveTextFieldSize() {
        print("Save font size")
        UserDefaults.standard.set(textFieldSize, forKey: "textFieldSize")
    }

    func loadTextFieldSize() {
        print("Load font size")
        textFieldSize = UserDefaults.standard.double(forKey: "textFieldSize")
        if textFieldSize == 0 {
            textFieldSize = 14  // Default size
        }
    }
    
    func saveColors() {
            UserDefaults.standard.setColor(textFieldColor.nsColor, forKey: "textFieldColor")
            UserDefaults.standard.setColor(backgroundColor.nsColor, forKey: "backgroundColor")
        UserDefaults.standard.set(backgroundOpacity, forKey: "backgroundOpacity")
        updateAllTextFieldStyles()
        }

        func loadColors() {
            if let savedTextFieldColor = UserDefaults.standard.color(forKey: "textFieldColor") {
                textFieldColor = Color(savedTextFieldColor)
            }
            if let savedBackgroundColor = UserDefaults.standard.color(forKey: "backgroundColor") {
                backgroundColor = Color(savedBackgroundColor)
            }
            if let savedBackgroundOpacity = UserDefaults.standard.object(forKey: "backgroundOpacity") as? Double {
                backgroundOpacity = savedBackgroundOpacity
            }
        }
    
    
    func saveOpacity() {
        UserDefaults.standard.set(backgroundOpacity, forKey: "backgroundOpacity")
    }

    func loadOpacity() {
        backgroundOpacity = UserDefaults.standard.double(forKey: "backgroundOpacity")
        if backgroundOpacity == 0, !UserDefaults.standard.contains(key: "backgroundOpacity") {
            backgroundOpacity = 1.0 // Set default opacity to 1.0 if not set before
        }
    }
    
    @objc func windowDidChange() {
        os_log("windowDidMove called")
        
        // Fade out existing windows
        fadeOutInvisibleWindows()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Adjust the delay as needed
            os_log("Calling fetchWindows from windowDidMove on main thread")
            self.fetchWindows()
        }
    }
    
    
    func fadeOutInvisibleWindows() {
        if !self.isFadeEnabled {
            return
        }
        DispatchQueue.main.async {
            for window in self.invisibleWindows {
                NSAnimationContext.beginGrouping()
                NSAnimationContext.current.duration = 0.3  // Fade-out duration
                window.animator().alphaValue = 0  // Fade to transparent
                NSAnimationContext.endGrouping()
            }
        }
    }

    private func fetchWindows() {
        os_log("fetchWindows called on thread: %@", Thread.current.description)
        DispatchQueue.global(qos: .userInitiated).async {
            os_log("Fetching windows on background thread")
            
            var details: [WindowInfo] = []
            let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
            if let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [NSDictionary] {
                for window in windowList {
                    if let name = window[kCGWindowOwnerName as String] as? String,
                       let pid = window[kCGWindowOwnerPID as String] as? Int,
                       let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                       let x = bounds["X"] as? CGFloat,
                       let y = bounds["Y"] as? CGFloat,
                       let width = bounds["Width"] as? CGFloat,
                       let height = bounds["Height"] as? CGFloat,
                       let layer = window[kCGWindowLayer as String] as? Int,
                       layer <= 0, width > 10, height > 10 {
                        
                        if !name.contains("WindowManager") {
                            
                            let windowInfo = WindowInfo(groupId: UUID(), name: name, pid: pid, x: x, y: y, width: width, height: height)
                            if self.isLikelyStageManagerGroup(x: x, y: y, width: width, height: height) {
                                
                                print("Window name: \(name), x: \(x), y: \(y), width: \(width), height: \(height)")
                                details.append(windowInfo)
                            }
                        }
                    }
                }
            }
            DispatchQueue.main.async {
                os_log("Updating UI on main thread")
                
                // Clearing the existing lists
                self.windowDetails = []
                self.groupedWindows = []
                
                self.windowDetails = details
                self.groupedWindows = self.groupWindowsByProximity()
                self.createInvisibleWindowsForGroups()
            }
            
        }
    }
    
    private func isLikelyOnStageManagerArea(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> Bool {
        let thresholdWidth: CGFloat = 300
        let leftSideThreshold: CGFloat = 140
            return width > thresholdWidth && x <= leftSideThreshold
    }
    
    private func isLikelyStageManagerGroup(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> Bool {
        let thresholdWidth: CGFloat = 300 // Example threshold for width
        return NSScreen.screens.contains(where: { screen in
            let screenBounds = screen.frame
            let leftSideThreshold: CGFloat = screenBounds.origin.x + (screenBounds.width / 4)
            return width <= thresholdWidth && x <= leftSideThreshold
        })
    }
    
    
    func updateAllTextFieldStyles() {
            for window in invisibleWindows {
                window.updateTextFieldAppearance()
            }
        }

    private func identifyGroup(for window: WindowInfo) -> String {
        // Example identifier based on the name and position
        // Adjust this logic to suit your application's needs
        return "\(window.name)"
    }
    
    private func groupWindowsByProximity() -> [[WindowInfo]] {
        let proximityThreshold: CGFloat = 80 // Define your threshold here
        var groups: [[WindowInfo]] = []
        var visited: Set<Int> = []

        for (index, window) in windowDetails.enumerated() {
            if visited.contains(index) { continue }

            var group: [WindowInfo] = [window]
            visited.insert(index)

            for (otherIndex, otherWindow) in windowDetails.enumerated() {
                if visited.contains(otherIndex) { continue }

                let distance = distanceBetween(window.center, otherWindow.center)
                let windowFrame = NSRect(x: window.x, y: window.y, width: window.width, height: window.height)
                let otherWindowFrame = NSRect(x: otherWindow.x, y: otherWindow.y, width: otherWindow.width, height: otherWindow.height)

                // Check if the windows are within proximity and intersect on the screen
                if distance <= proximityThreshold && windowFrame.intersects(otherWindowFrame) {
                    group.append(otherWindow)
                    visited.insert(otherIndex)
                }
            }

            groups.append(group)
        }

        
        var updatedGroups: [[WindowInfo]] = []
        for group in groups {
            let identifier = identifyGroup(for: group.first!)
            let groupId: UUID

            if let existingGroupId = self.groupIdentifierMapping[identifier] {
                groupId = existingGroupId // Use existing groupId
            } else {
                groupId = UUID() // Create a new groupId
                self.groupIdentifierMapping[identifier] = groupId
            }

            var updatedGroup: [WindowInfo] = []
            for var window in group {
                window.groupId = groupId
                updatedGroup.append(window)
            }

            updatedGroups.append(updatedGroup)
        }


        return updatedGroups
    }
    
    // Method to safely close and remove a window
    private func closeAndRemoveWindow(with groupId: UUID) {
        guard let window = windowGroupMapping[groupId] else { return }
        window.close()
        window.orderOut(nil)
        NotificationCenter.default.removeObserver(window)
        windowGroupMapping.removeValue(forKey: groupId)
        invisibleWindows.removeAll(where: { $0.groupId == groupId })
    }
    
    func createInvisibleWindowsForGroups() {
        DispatchQueue.main.async { [self] in
            var groupCounter = 1
            // Update existing windows or create new ones
            for group in self.groupedWindows {
                guard let groupId = group.first?.groupId,
                      let identifier = groupIdentifierMapping.first(where: { $1 == groupId })?.key else { continue }
                
                let existingText = self.textFieldValues[identifier] ?? "Stage \(groupCounter)"
                if (self.textFieldValues[identifier] == nil) {
                    groupCounter += 1
                }
                
                guard let windowInfo = group.first,
                      let screen = self.getScreenWithMaxIntersection(for: windowInfo) else { continue }
                
                // Calculate the label frame based on the screen and group frame
                let labelFrame = self.calculateLabelFrame(for: windowInfo, on: screen)

                if let existingWindow = self.windowGroupMapping[groupId] {
                    // Update the existing window
                    existingWindow.setFrame(labelFrame, display: true)
                    existingWindow.orderFront(nil)
                    existingWindow.updateTextField(with: existingText)
                    
                    // Fade in the window
                    if self.isFadeEnabled {
                        NSAnimationContext.runAnimationGroup({ context in
                            context.duration = 0.5  // Adjust fade-in duration as needed
                            existingWindow.animator().alphaValue = 1
                        })
                    }
                } else {
                    // Create a new window
                    let window = InvisibleWindow(label: existingText, frame: labelFrame, groupId: groupId, viewModel: self)
                    window.orderFront(nil)
                    self.windowGroupMapping[groupId] = window
                    self.invisibleWindows.append(window)
                }
            }
            
            // Close and remove windows that are no longer needed
            self.removeUnusedWindows()
        }
    }
    
    func removeUnusedWindows() {
        let currentGroupIds = Set(self.groupedWindows.flatMap { $0.map { $0.groupId } })
        for (groupId, window) in self.windowGroupMapping {
            if !currentGroupIds.contains(groupId) {
                window.orderOut(nil)
                self.windowGroupMapping.removeValue(forKey: groupId)
            }
        }
    }
    
    var primaryScreen: NSScreen? {
        NSScreen.screens.first(where: { $0.frame.origin == .zero })
    }
    
    func calculateLabelFrame(for windowInfo: WindowInfo, on screen: NSScreen) -> NSRect {
        let windowRect = NSRect(x: windowInfo.x, y: windowInfo.y, width: windowInfo.width, height: windowInfo.height)
        let labelHeight: CGFloat = 25

        var labelFrame = NSRect(
            x: screen.frame.origin.x,
            y: windowRect.maxY,
            width: 150,
            height: labelHeight
        )

        let isPrimaryScreen = (screen == self.primaryScreen)
        let adjustment: CGFloat = isPrimaryScreen ? 0 : 232
        labelFrame.origin.y = screen.frame.origin.y + screen.frame.size.height - labelFrame.maxY - adjustment

        return labelFrame
    }


    func getScreenWithMaxIntersection(for windowInfo: WindowInfo) -> NSScreen? {
        let windowRect = NSRect(x: windowInfo.x, y: windowInfo.y, width: windowInfo.width, height: windowInfo.height)
        var maxIntersectionArea: CGFloat = 0.0
        var screenWithMaxIntersection: NSScreen?

        for screen in NSScreen.screens {
            let intersectionRect = windowRect.intersection(screen.frame)
            let intersectionArea = intersectionRect.size.width * intersectionRect.size.height

            if intersectionArea > maxIntersectionArea {
                maxIntersectionArea = intersectionArea
                screenWithMaxIntersection = screen
            }
        }

        return screenWithMaxIntersection
    }

    private func distanceBetween(_ point1: CGPoint, _ point2: CGPoint) -> CGFloat {
        return sqrt(pow(point2.x - point1.x, 2) + pow(point2.y - point1.y, 2))
    }
}
