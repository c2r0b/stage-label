//
//  Extensions.swift
//  Stage Label
//
//  Created by c2r0b on 03/01/24.
//

import SwiftUI

extension UserDefaults {
    func setColor(_ color: NSColor, forKey key: String) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
            set(data, forKey: key)
        } catch {
            print("Error saving color: \(error)")
        }
    }

    func color(forKey key: String) -> NSColor? {
        guard let data = data(forKey: key) else { return nil }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
        } catch {
            print("Error loading color: \(error)")
            return nil
        }
    }
    
    
    func contains(key: String) -> Bool {
        return UserDefaults.standard.object(forKey: key) != nil
    }
}
