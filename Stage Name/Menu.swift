//
//  Menu.swift
//  Stage Label
//
//  Created by c2r0b on 03/01/24.
//

import SwiftUI

struct AppMenu: View {
    var windowController: WindowController
    @ObservedObject var viewModel: WindowListViewModel

    var body: some View {
        VStack {
            Button(action: {
                windowController.openSettingsWindow(with: viewModel)
            }) {
                HStack {
                    Image(systemName: "gearshape") // Explicitly create an Image for the icon
                    Text("Settings...")
                }
            }
            .padding()
            
            Divider()

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Image(systemName: "power") // Explicitly create an Image for the icon
                    Text("Quit Stage Label")
                }
            }
            .padding()
        }
    }
}
