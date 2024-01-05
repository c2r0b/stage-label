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
