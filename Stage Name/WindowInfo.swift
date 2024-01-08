//
//  WindowInfo.swift
//  Stage Label
//
//  Created by c2r0b on 03/01/24.
//

import SwiftUI

struct WindowInfo: Identifiable, Hashable {
    let id: CGWindowID  // Unique identifier for the window
    var groupId: UUID // Identifier for the group
    let name: String
    let pid: Int
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat

    var center: CGPoint {
        return CGPoint(x: x + width / 2, y: y + height / 2)
    }
}

extension WindowInfo {
    func screen() -> NSScreen? {
        let windowCenter = self.center
        return NSScreen.screens.first(where: { $0.frame.contains(windowCenter) })
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id) // Use the unique identifier for hashing
    }
    
    static func ==(lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        return lhs.id == rhs.id // Two WindowInfos are equal if their IDs are equal
    }
}
