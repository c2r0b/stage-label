//
//  ContentView.swift
//  Stage Name
//
//  Created by c2r0b on 24/12/23.
//
import SwiftUI
import Quartz
import os

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
    
    // Add a mapping from group identifiers to InvisibleWindow
    var windowGroupMapping: [UUID: InvisibleWindow] = [:]
    var groupIdentifierMapping: [String: UUID] = [:]
    
    private var wasWindowStageManaged: [CGWindowID: Bool] = [:]
    
    private var windowScreen: [CGWindowID: NSScreen] = [:]
    private var lastKnownScreen: NSScreen?
    
    private var pollTimer: Timer?
    
    private var lastActiveAppPID: Int32 = 0
    private var updating: Bool = false
    
    init() {
        DispatchQueue.main.async {
            self.loadTextFieldValues()
            self.loadTextFieldSize()
            self.loadColors()
            self.startWindowChangeMonitoring()
            self.fetchWindows()
            self.startPolling()
        }
    }
    
    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkFrontmostWindow()
        }
    }
    
    func getScreenOf(window: NSWindow) -> NSScreen? {
        return window.screen
    }
    
    func getActiveScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
    }
    
    private func getAllWindows() -> [NSDictionary]? {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        if let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [NSDictionary] {
            var windows: [NSDictionary] = []
            for window in windowList {
                if let name = window[kCGWindowOwnerName as String] as? String,
                   let (_, _, width, height) = self.getWindowPosition(window: window),
                   let layer = window[kCGWindowLayer as String] as? Int,
                   layer <= 0, width > 10, height > 10 {
                    
                    if !name.contains("WindowManager") {
                        windows.append(window)
                    }
                }
            }
            return windows
        }
        return nil
    }
    
    private func getWindowsFromPID(pid: Int32) -> [NSDictionary] {
        var windows: [NSDictionary] = []
        if let windowList = getAllWindows() {
            for window in windowList {
                if let windowPID = window[kCGWindowOwnerPID as String] as? Int {
                    if windowPID == pid {
                        windows.append(window)
                    }
                }
            }
        }
        return windows
    }
    
    private func getWindowPosition(window: NSDictionary) -> (CGFloat, CGFloat, CGFloat, CGFloat)? {
        if let bounds = window[kCGWindowBounds as String] as? NSDictionary,
            let x = bounds["X"] as? CGFloat,
            let y = bounds["Y"] as? CGFloat,
            let width = bounds["Width"] as? CGFloat,
           let height = bounds["Height"] as? CGFloat {
            return ( x, y, width, height )
        }
        return nil
        
    }
    
    private func getWindowScreen(window: NSDictionary) -> NSScreen? {
        if let (x, y, width, height) = getWindowPosition(window: window) {
            let windowFrame = CGRect(x: x, y: y, width: width, height: height)
            return NSScreen.screens.first { $0.frame.intersects(windowFrame) }
        }
        return nil
    }
    
    private func checkFrontmostWindow() {
        DispatchQueue.main.async {
            var screenChanged = false
            let activeScreen = self.getActiveScreen()
            if (activeScreen != self.lastKnownScreen) {
                self.lastKnownScreen = activeScreen
                screenChanged = true
            }
            
            guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
                return
            }
            
            let frontmostAppPid = frontmostApp.processIdentifier
            
            if let windows = self.getAllWindows() {
             for window in windows {
                 if let windowID = window[kCGWindowNumber as String] as? CGWindowID,
                     let name = window[kCGWindowOwnerName as String] as? String,
                    let (x, y, width, height) = self.getWindowPosition(window: window) {
                     let wasStageManaged = self.wasWindowStageManaged[windowID]
                         let isStageManaged = self.isLikelyStageManagerGroup(x: x, y:y, width: width, height: height)
                         self.wasWindowStageManaged[windowID] = isStageManaged
                         
                        // Check if the minimized state changed
                         if wasStageManaged != isStageManaged {
                             print("Window \(name) minimized state changed")
                             self.windowDidChange()
                             return
                         }
                     }
                 }
             }
            
            for window in self.getWindowsFromPID(pid: frontmostAppPid) {
                if let windowID = window[kCGWindowNumber as String] as? CGWindowID,
                   let name = window[kCGWindowOwnerName as String] as? String,
                   let (x, y, width, height) = self.getWindowPosition(window: window) {
                    
                    // Check if the window screen changed
                    if screenChanged {
                        let windowScreen = self.getWindowScreen(window: window)
                        if windowScreen != self.windowScreen[windowID] {
                            print("Application was likely moved to another screen:\(name) \(String(describing: self.windowScreen[windowID])) \(String(describing: windowScreen))")
                            self.windowDidChange()
                        }
                    }
                    
                    // Check if window is on top of stage manager
                    if !self.isLikelyStageManagerGroup(x: x, y:y, width: width, height: height) {
                        if self.isLikelyOnStageManagerArea(x: x, y:y, width: width, height: height) {
                            let windowFrame = CGRect(x: x, y: y, width: width, height: height)
                            print("Is on top of stage manager area: \(name) \(x)")
                            self.hideInvisibleWindowsOnScreen(windowFrame)
                            return
                        }
                    }
                }
            }
            if self.updating == false {
                self.showInvisibleWindows()
            }
        }
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
        NSWorkspace.shared.notificationCenter.removeObserver(self)
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

    func showInvisibleWindows() {
        DispatchQueue.main.async {
            for window in self.invisibleWindows {
                    window.animator().alphaValue = 1 // Show the window
                }
        }
    }
    
    private func filterWindowsOnActiveScreen(windows: [NSDictionary]) -> [NSDictionary] {
        var resultWindows: [NSDictionary] = []
        let activeScreen = self.getActiveScreen()
        
        for window in windows {
                let windowScreen = self.getWindowScreen(window: window)
                if windowScreen == activeScreen {
                    resultWindows.append(window)
                }
        }
        return resultWindows
    }
    
    @objc private func focusedWindowChanged(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        let currentPid = app.processIdentifier
        print("Activated application PID: \(currentPid)")
        
        // Check if the currently focused app was in stage manager
        for window in self.filterWindowsOnActiveScreen(windows: self.getWindowsFromPID(pid: currentPid)) {
                if let name = window[kCGWindowOwnerName as String] as? String,
                   let (x, y, width, height) = getWindowPosition(window: window) {
                    
                        print("Frontmost changed, (new) windows: \(name), \(width)")
                        if self.isLikelyStageManagerGroup(x: x, y: y, width: width, height: height) {
                            print("New application was likely a Stage Manager group: \(name) \(width)")
                            self.windowDidChange()
                            return
                        }
                }
        }
        
        // Check if the previously focused app is now in stage manager
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.lastActiveAppPID = currentPid
            for window in self.filterWindowsOnActiveScreen(windows: self.getWindowsFromPID(pid: self.lastActiveAppPID)) {
                    if let name = window[kCGWindowOwnerName as String] as? String,
                       let (x, y, width, height) = self.getWindowPosition(window: window) {
                        
                            print("Frontmost changed, (old) windows: \(name), \(width)")
                            if self.isLikelyStageManagerGroup(x: x, y: y, width: width, height: height) {
                                print("Old application is now likely a Stage Manager group: \(name) \(width)")
                                self.windowDidChange()
                                return
                            }
                    }
                }
        }
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
        if updating == true {
            return
        }
        
        // Fade out existing windows
        fadeOutInvisibleWindows()
        updating = true
        
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
            if let windowList = self.getAllWindows() {
                for window in windowList {
                    if let windowID = window[kCGWindowNumber as String] as? CGWindowID,
                       let name = window[kCGWindowOwnerName as String] as? String,
                       let pid = window[kCGWindowOwnerPID as String] as? Int,
                       let (x, y, width, height) = self.getWindowPosition(window: window) {
                                
                            // Save window screen
                            let windowScreen = self.getWindowScreen(window: window)
                            self.windowScreen[windowID] = windowScreen
                                        
                            let windowInfo = WindowInfo(id: windowID, groupId: UUID(), name: name, pid: pid, x: x, y: y, width: width, height: height)
                            
                            let isStageManaged = self.isLikelyStageManagerGroup(x: x, y: y, width: width, height: height)
                            self.wasWindowStageManaged[windowID] = isStageManaged
                            print("Window saved screen: \(name) \(isStageManaged) \(String(describing: windowScreen))")
                            if isStageManaged == true {
                                print("Window name: \(name), x: \(x), y: \(y), width: \(width), height: \(height)")
                                details.append(windowInfo)
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
                self.groupedWindows = self.groupWindowsByOverlap()
                self.createInvisibleWindowsForGroups()
                self.updating = false
            }
            
        }
    }
    
    private func isLikelyOnStageManagerArea(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> Bool {
        let thresholdWidth: CGFloat = 300
        return NSScreen.screens.contains(where: { screen in
            let screenBounds = screen.frame
            let leftSideThreshold: CGFloat = screenBounds.origin.x + 140
            return width > thresholdWidth && x <= leftSideThreshold
        })
    }
    
    private func isLikelyStageManagerGroup(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> Bool {
        let thresholdWidth: CGFloat = 300 // Example threshold for width
        return NSScreen.screens.contains(where: { screen in
            let screenBounds = screen.frame
            let leftSideThreshold: CGFloat = screenBounds.origin.x + 250
            return width <= thresholdWidth && x <= leftSideThreshold
        })
    }
    
    
    func updateAllTextFieldStyles() {
            for window in invisibleWindows {
                window.updateTextFieldAppearance()
            }
        }

    private func identifyGroup(for group: [WindowInfo]) -> String {
        let sortedIDs = group.map { $0.id }.sorted().map { String($0) }
        return sortedIDs.joined(separator: "-")
    }
    
    private func groupWindowsByOverlap() -> [[WindowInfo]] {
        var groups: [[WindowInfo]] = []
        
        // Step 1: Identify all pairs of overlapping windows
        var overlaps = [(Int, Int)]()
        for i in 0..<windowDetails.count {
            for j in (i+1)..<windowDetails.count {
                let windowFrame1 = NSRect(x: windowDetails[i].x, y: windowDetails[i].y, width: windowDetails[i].width, height: windowDetails[i].height)
                let windowFrame2 = NSRect(x: windowDetails[j].x, y: windowDetails[j].y, width: windowDetails[j].width, height: windowDetails[j].height)
                if windowFrame1.intersects(windowFrame2) {
                    overlaps.append((i, j))
                }
            }
        }
        
        for window in windowDetails {
            print("WindowDetails \(window.name)")
        }

        // Step 2: Group windows using a union-find algorithm
        var parent = Array(0..<windowDetails.count) // Each window initially in its own group
        func find(_ i: Int) -> Int {
            if parent[i] != i {
                parent[i] = find(parent[i])
            }
            return parent[i]
        }
        func union(_ i: Int, _ j: Int) {
            parent[find(i)] = find(j)
        }
        for (i, j) in overlaps {
            union(i, j)
        }

        // Step 3: Create final groups
        var groupDict = [Int: [WindowInfo]]()
        for (index, window) in windowDetails.enumerated() {
            let groupId = find(index)
            groupDict[groupId, default: []].append(window)
        }
        groups = Array(groupDict.values)
        
        // Sort each group by window ID
        for i in 0..<groups.count {
            groups[i].sort(by: { $0.id < $1.id })
        }

        // Assign group identifiers
        var updatedGroups: [[WindowInfo]] = []
        for group in groups {
            let identifier = identifyGroup(for: group)
            let groupId: UUID

            if let existingGroupId = self.groupIdentifierMapping[identifier] {
                groupId = existingGroupId
            } else {
                groupId = UUID()
                self.groupIdentifierMapping[identifier] = groupId
            }

            var updatedGroup: [WindowInfo] = []
            for var window in group {
                window.groupId = groupId
                updatedGroup.append(window)
            }

            updatedGroups.append(updatedGroup)
        }
        
        // sort group by identifier
        updatedGroups.sort(by: { identifyGroup(for: $0) < identifyGroup(for: $1) })

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
                print("Identify \(groupId) as \(identifier) with text \( String(describing: self.textFieldValues[identifier]))")
                
                let existingText = self.textFieldValues[identifier] ?? "Stage \(groupCounter)"
                groupCounter += 1
                
                // Select the window with the lowest y at the bottom
                let windowInfo = group.max(by: { $0.y < $1.y })
                for window in group {
                    print("Group #\(groupCounter) has windows \(window.name)")
                }
                
                guard let selectedWindowInfo = windowInfo,
                      let screen = self.getScreenWithMaxIntersection(for: selectedWindowInfo) else { continue }
                
                // Calculate the label frame based on the screen and group frame
                let labelFrame = self.calculateLabelFrame(for: selectedWindowInfo, on: screen)

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

        // Calculate the Y position of the label
        var labelYPosition: CGFloat = 0
        let screenVerticalCenter = screen.frame.height / 2
        print("YPOS: \(windowInfo.name) has max \(windowRect.maxY), min \(windowRect.minY), screen center is \(screenVerticalCenter), it is UP? \(windowRect.minY < screenVerticalCenter - 100)")
        if (windowRect.minY < screenVerticalCenter - 150) {
            labelYPosition = (screen.frame.height - windowRect.minY - windowRect.height - labelHeight + 5)
        }
        else {
            labelYPosition = screen.frame.height - (windowRect.maxY + labelHeight + 5)
        }

        var labelFrame = NSRect(
            x: screen.frame.origin.x,
            y: labelYPosition,
            width: 150,
            height: labelHeight
        )

        // Adjust label frame origin based on the screen origin
        labelFrame.origin.y += screen.frame.origin.y

        print("\(windowInfo.name) - Label Y Position: \(labelYPosition), Screen Origin Y: \(screen.frame.origin.y), Window MinY: \(windowRect.minY)")
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
