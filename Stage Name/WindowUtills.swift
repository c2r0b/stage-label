//
//  WindowUtills.swift
//  Stage Label
//
//  Created by c2r0b on 19/04/24.
//

import SwiftUI
import os

func getAllWindows() -> [NSDictionary]? {
    let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
    if let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [NSDictionary] {
        var windows: [NSDictionary] = []
        for window in windowList {
            if let name = window[kCGWindowOwnerName as String] as? String,
               let (_, _, width, height) = getWindowPosition(window: window),
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

func getWindowsFromPID(pid: Int32) -> [NSDictionary] {
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

func getWindowPosition(window: NSDictionary) -> (CGFloat, CGFloat, CGFloat, CGFloat)? {
    if let bounds = window["kCGWindowBounds" as String] as? NSDictionary,
       let x = bounds["X"] as? CGFloat,
       let y = bounds["Y"] as? CGFloat,
       let width = bounds["Width"] as? CGFloat,
       let height = bounds["Height"] as? CGFloat {
        return (x, y, width, height)
    }
    return nil
}

func getWindowScreen(window: NSDictionary) -> NSScreen? {
    if let (x, y, width, height) = getWindowPosition(window: window) {
        let windowFrame = CGRect(x: x, y: y, width: width, height: height)
        return NSScreen.screens.first { $0.frame.intersects(windowFrame) }
    }
    return nil
}

func fadeOutWindows(windows: [InvisibleWindow]) {
    DispatchQueue.main.async {
        for window in windows {
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0.3  // Fade-out duration
            window.animator().alphaValue = 0  // Fade to transparent
            NSAnimationContext.endGrouping()
        }
    }
}

func isLikelyOnStageManagerArea(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> Bool {
    let thresholdWidth: CGFloat = 300
    return NSScreen.screens.contains(where: { screen in
        let screenBounds = screen.frame
        let leftSideThreshold: CGFloat = screenBounds.origin.x + 140
        return width > thresholdWidth && x <= leftSideThreshold
    })
}

func hideInvisibleWindowsIfOnScreen(_ screenFrame: CGRect, windows: [InvisibleWindow]) {
    DispatchQueue.main.async {
        for window in windows {
            if window.isOnScreen(screenFrame) {
                window.animator().alphaValue = 0 // Hide the window
            }
        }
    }
}

func showInvisibleWindows(windows: [InvisibleWindow]) {
    DispatchQueue.main.async {
        for window in windows {
            window.animator().alphaValue = 1 // Show the window
        }
    }
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
