//
//  Permissions.swift
//  Stage Label
//
//  Created by c2r0b on 03/01/24.
//

import SwiftUI
import LaunchAtLogin

struct PermissionsView: View {
    @ObservedObject var viewModel: WindowListViewModel

    var body: some View {
        VStack(spacing: 10) {
            Spacer()

            Text("Accessibility")
                .font(.headline)
                .padding(.top)

            Text("To manage windows effectively, accessibility permissions are required.")
                .multilineTextAlignment(.center)

            if !viewModel.isAccessibilityPermissionGranted {
                Button(action: viewModel.openSystemPreferencesAccessibility) {
                    Text("Grant Accessibility Permissions")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            } else {
                Label("Accessibility Permissions Granted", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            
            Spacer()
            Divider()
            Spacer()
            
            Text("Startup")
                .font(.headline)

            Text("You can automatically launch Stage Label at startup (optional).")
                .multilineTextAlignment(.center)
            LaunchAtLogin.Toggle()

            Spacer()
        }
        .padding(.horizontal)
        .frame(width: 400, height: 350)
    }
}
