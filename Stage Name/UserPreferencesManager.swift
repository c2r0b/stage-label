//
//  UserPreferencesManager.swift
//  Stage Label
//
//  Created by c2r0b on 19/04/24.
//

import SwiftUI

class UserPreferencesManager {
    static let shared = UserPreferencesManager()
    
    var textFieldValues: [String: String] = [:]
    
    @Published var textFieldColor: Color = .white
    @Published var backgroundColor: Color = .black
    @Published var backgroundOpacity: Double = 1.0
    @Published var textFieldSize: CGFloat = 14
    @Published var isFadeEnabled = true
    
    func loadTextFieldValues() {
        if let savedData = UserDefaults.standard.data(forKey: "textFieldValues"),
           let decodedDictionary = try? JSONDecoder().decode([String: String].self, from: savedData) {
            textFieldValues = decodedDictionary
        }
    }
    
    func saveTextFieldValues() {
        if let encoded = try? JSONEncoder().encode(textFieldValues) {
            print("Saved textFields")
            UserDefaults.standard.set(encoded, forKey: "textFieldValues")
        }
    }
    
    func loadTextFieldSize() {
        print("Load font size")
        textFieldSize = UserDefaults.standard.double(forKey: "textFieldSize")
        if textFieldSize == 0 {
            textFieldSize = 14  // Default size
        }
    }
    
    func saveTextFieldSize() {
        print("Save font size")
        UserDefaults.standard.set(textFieldSize, forKey: "textFieldSize")
    }
    
    func saveColors() {
        UserDefaults.standard.setColor(textFieldColor.nsColor, forKey: "textFieldColor")
        UserDefaults.standard.setColor(backgroundColor.nsColor, forKey: "backgroundColor")
        UserDefaults.standard.set(backgroundOpacity, forKey: "backgroundOpacity")
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
}
