//
//  WindowManager.swift
//  Stage Label
//
//  Created by c2r0b on 19/04/24.
//

import SwiftUI
import Quartz
import os

class WindowManager {
    public var windowDetails: [WindowInfo] = []
    public var windowScreen: [CGWindowID: NSScreen] = [:]
    public var invisibleWindows: [InvisibleWindow] = []
    public var groupedWindows: [[WindowInfo]] = []
    public var wasWindowStageManaged: [CGWindowID: Bool] = [:]
    public var updating: Bool = false
    
    // Add a mapping from group identifiers to InvisibleWindow
    var windowGroupMapping: [UUID: InvisibleWindow] = [:]
    var groupIdentifierMapping: [String: UUID] = [:]
    
    func fetchWindows() {
        DispatchQueue.global(qos: .userInitiated).async {
            var details: [WindowInfo] = []
            if let windowList = getAllWindows() {
                for window in windowList {
                    if let windowID = window[kCGWindowNumber as String] as? CGWindowID,
                       let name = window[kCGWindowOwnerName as String] as? String,
                       let pid = window[kCGWindowOwnerPID as String] as? Int,
                       let (x, y, width, height) = getWindowPosition(window: window) {
                                
                            // Save window screen
                            let windowScreen = getWindowScreen(window: window)
                            self.windowScreen[windowID] = windowScreen
                                        
                            let windowInfo = WindowInfo(id: windowID, groupId: UUID(), name: name, pid: pid, x: x, y: y, width: width, height: height)
                            
                            let isStageManaged = isLikelyStageManagerGroup(x: x, y: y, width: width, height: height)
                            self.wasWindowStageManaged[windowID] = isStageManaged
                            if isStageManaged == true {
                                details.append(windowInfo)
                            }
                    }
                }
            }
            DispatchQueue.main.async {
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
    
    func filterWindowsOnActiveScreen(windows: [NSDictionary]) -> [NSDictionary] {
        var resultWindows: [NSDictionary] = []
        let activeScreen = getActiveScreen()
        
        for window in windows {
            let windowScreen = getWindowScreen(window: window)
            if windowScreen == activeScreen {
                resultWindows.append(window)
            }
        }
        return resultWindows
    }
    
    private func identifyGroup(for group: [WindowInfo]) -> String {
        let sortedIDs = group.map { $0.id }.sorted().map { String($0) }
        return sortedIDs.joined(separator: "-")
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
    
    // Method to safely close and remove a window
    private func closeAndRemoveWindow(with groupId: UUID) {
        guard let window = self.windowGroupMapping[groupId] else { return }
        window.close()
        window.orderOut(nil)
        NotificationCenter.default.removeObserver(window)
        windowGroupMapping.removeValue(forKey: groupId)
        invisibleWindows.removeAll(where: { $0.groupId == groupId })
    }
    
    func groupWindowsByOverlap() -> [[WindowInfo]] {
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
    
    func updateAllTextFieldStyles() {
        for window in invisibleWindows {
            window.updateTextFieldAppearance()
        }
    }
    
    func createInvisibleWindowsForGroups() {
        DispatchQueue.main.async { [self] in
            var groupCounter = 1
            // Update existing windows or create new ones
            for group in self.groupedWindows {
                guard let groupId = group.first?.groupId,
                      let identifier = groupIdentifierMapping.first(where: { $1 == groupId })?.key else { continue }
                print("Identify \(groupId) as \(identifier) with text \( String(describing: UserPreferencesManager.shared.textFieldValues[identifier]))")
                
                let preferences = UserPreferencesManager.shared
                let existingText = preferences.textFieldValues[identifier] ?? "Stage \(groupCounter)"
                groupCounter += 1
                
                // Select the window with the lowest y at the bottom
                let windowInfo = group.max(by: { $0.y < $1.y })
                for window in group {
                    print("Group #\(groupCounter) has windows \(window.name)")
                }
                
                guard let selectedWindowInfo = windowInfo,
                      let screen = getScreenWithMaxIntersection(for: selectedWindowInfo) else { continue }
                
                // Calculate the label frame based on the screen and group frame
                let labelFrame = calculateLabelFrame(for: selectedWindowInfo, on: screen)

                if let existingWindow = self.windowGroupMapping[groupId] {
                    // Update the existing window
                    existingWindow.setFrame(labelFrame, display: true)
                    existingWindow.orderFront(nil)
                    existingWindow.updateTextField(with: existingText)
                    
                    // Fade in the window
                    if preferences.isFadeEnabled {
                        NSAnimationContext.runAnimationGroup({ context in
                            context.duration = 0.5  // Adjust fade-in duration as needed
                            existingWindow.animator().alphaValue = 1
                        })
                    }
                } else {
                    // Create a new window
                    let window = InvisibleWindow(label: existingText, frame: labelFrame, groupId: groupId, windowManager: self)
                    window.orderFront(nil)
                    self.windowGroupMapping[groupId] = window
                    self.invisibleWindows.append(window)
                }
            }
            
            // Close and remove windows that are no longer needed
            self.removeUnusedWindows()
        }
    }
}
