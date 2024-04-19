//
//  ScreenUtils.swift
//  Stage Label
//
//  Created by c2r0b on 19/04/24.
//

import Swift
import Quartz
import os

var primaryScreen: NSScreen? {
    NSScreen.screens.first(where: { $0.frame.origin == .zero })
}

func distanceBetween(_ point1: CGPoint, _ point2: CGPoint) -> CGFloat {
    return sqrt(pow(point2.x - point1.x, 2) + pow(point2.y - point1.y, 2))
}

func getActiveScreen() -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    return NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
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
