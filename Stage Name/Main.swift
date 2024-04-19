//
//  ContentView.swift
//  Stage Name
//
//  Created by c2r0b on 24/12/23.
//
import SwiftUI
import Quartz
import os

class Test: ObservableObject {
    @Published var windowDetails: [WindowInfo] = []
    @Published var groupedWindows: [[WindowInfo]] = []
    var textFieldValues: [String: String] = [:]
    
    @Published var textFieldColor: Color = .white
    @Published var backgroundColor: Color = .black
    @Published var backgroundOpacity: Double = 1.0 // Default to full opacity
    @Published var textFieldSize: CGFloat = 14
    @Published var isFadeEnabled = true
    
    
    private var windowScreen: [CGWindowID: NSScreen] = [:]
    
    private var pollTimer: Timer?
    
    private var lastActiveAppPID: Int32 = 0
    private var updating: Bool = false
}
