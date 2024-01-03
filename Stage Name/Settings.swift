//
//  Settings.swift
//  Stage Label
//
//  Created by c2r0b on 03/01/24.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: WindowListViewModel

    var body: some View {
        TabView {
            // Appearance Tab
            VStack(spacing: 5) {
                Spacer()
                
                HStack {
                    VStack {
                        Text("Text Color")
                        ColorSlider(selectedColor: $viewModel.textFieldColor)
                            .onChange(of: viewModel.textFieldColor) { _ in
                                viewModel.saveColors()
                                viewModel.updateAllTextFieldStyles()
                            }
                    }
                    .padding(.trailing)
                    
                    VStack {
                        Text("Text Size")
                        Slider(value: $viewModel.textFieldSize, in: 12...24)
                            .onChange(of: viewModel.textFieldSize) { _ in
                                viewModel.saveTextFieldSize()
                                viewModel.updateAllTextFieldStyles()
                            }
                    }
                }
                
                Spacer()
                    
                HStack {
                    VStack {
                        Text("Background Color")
                        ColorSlider(selectedColor: $viewModel.backgroundColor)
                            .onChange(of: viewModel.backgroundColor) { _ in
                                viewModel.saveColors()
                                viewModel.updateAllTextFieldStyles()
                            }
                    }
                    .padding(.trailing)
                        
                    VStack {
                        Text("Background Opacity")
                        Slider(value: $viewModel.backgroundOpacity, in: 0.0...1.0)
                            .onChange(of: viewModel.backgroundOpacity) { _ in
                                viewModel.saveOpacity()
                                viewModel.updateAllTextFieldStyles()
                            }
                    }
                }
                
                Spacer()
                
                Toggle("Enable Fade Effect", isOn: $viewModel.isFadeEnabled)
                    .onChange(of: viewModel.isFadeEnabled) { newValue in
                        viewModel.isFadeEnabled = newValue
                    }
                    .padding()
                Spacer()
            }
            .tabItem {
                Label("Appearance", systemImage: "paintbrush")
            }
            .padding()
            
            
            PermissionsView(viewModel: viewModel)
                .tabItem {
                    Label("Permissions", systemImage: "key")
                }
        }
        .padding()
        .frame(width: 500, height: 450)
    }
}
