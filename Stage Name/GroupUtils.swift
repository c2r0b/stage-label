//
//  GroupUtils.swift
//  Stage Label
//
//  Created by c2r0b on 19/04/24.
//

import Swift
import Quartz

func isLikelyStageManagerGroup(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> Bool {
    let thresholdWidth: CGFloat = 300 // Example threshold for width
    return NSScreen.screens.contains(where: { screen in
        let screenBounds = screen.frame
        let leftSideThreshold: CGFloat = screenBounds.origin.x + 250
        return width <= thresholdWidth && x <= leftSideThreshold
    })
}
