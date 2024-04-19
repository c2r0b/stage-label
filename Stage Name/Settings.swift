//
//  Settings.swift
//  Stage Label
//
//  Created by c2r0b on 03/01/24.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: WindowListViewModel
    
    @State private var textFieldColor = UserPreferencesManager.shared.textFieldColor
    @State private var textFieldSize = UserPreferencesManager.shared.textFieldSize
    @State private var backgroundColor = UserPreferencesManager.shared.backgroundColor
    @State private var backgroundOpacity = UserPreferencesManager.shared.backgroundOpacity
    @State private var isFadeEnabled = UserPreferencesManager.shared.isFadeEnabled

    var body: some View {
        TabView {
            // Appearance Tab
            VStack(spacing: 5) {
                Spacer()

                HStack {
                    VStack {
                        Text("Text Color")
                        ColorSlider(selectedColor: $textFieldColor)
                            .onChange(of: textFieldColor) { newValue in
                                UserPreferencesManager.shared.textFieldColor = newValue
                                UserPreferencesManager.shared.saveColors()
                                viewModel.windowManager.updateAllTextFieldStyles()
                            }
                    }
                    .padding(.trailing)

                    VStack {
                        Text("Text Size")
                        Slider(value: $textFieldSize, in: 12...24)
                            .onChange(of: textFieldSize) { newValue in
                                UserPreferencesManager.shared.textFieldSize = newValue
                                UserPreferencesManager.shared.saveTextFieldSize()
                                viewModel.windowManager.updateAllTextFieldStyles()
                            }
                    }
                }

                Spacer()

                HStack {
                    VStack {
                        Text("Background Color")
                        ColorSlider(selectedColor: $backgroundColor)
                            .onChange(of: backgroundColor) { newValue in
                                UserPreferencesManager.shared.backgroundColor = newValue
                                UserPreferencesManager.shared.saveColors()
                                viewModel.windowManager.updateAllTextFieldStyles()
                            }
                    }
                    .padding(.trailing)

                    VStack {
                        Text("Background Opacity")
                        Slider(value: $backgroundOpacity, in: 0.0...1.0)
                            .onChange(of: backgroundOpacity) { newValue in
                                UserPreferencesManager.shared.backgroundOpacity = newValue
                                UserPreferencesManager.shared.saveOpacity()
                                viewModel.windowManager.updateAllTextFieldStyles()
                            }
                    }
                }

                Spacer()

                Toggle("Enable Fade Effect", isOn: $isFadeEnabled)
                    .onChange(of: isFadeEnabled) { newValue in
                        UserPreferencesManager.shared.isFadeEnabled = newValue
                    }
                    .padding()
                Spacer()
            }
            .tabItem {
                Label("Appearance", systemImage: "paintbrush")
            }
            .padding()
            
            PermissionsView()
                .tabItem {
                    Label("Permissions", systemImage: "key")
                }
        }
        .padding()
        .frame(width: 500, height: 450)
    }
}
