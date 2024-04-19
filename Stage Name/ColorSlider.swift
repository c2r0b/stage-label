//
//  ColorPicker.swift
//  Stage Label
//
//  Created by c2r0b on 02/01/24.
//

import SwiftUI
import Foundation

struct ColorSlider: View {
    @Binding var selectedColor: Color
    
    // The gradient for the slider, representing the color spectrum
    private let colorGradient: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .white, .gray, .black]
    
    // The current value of the slider
    @State private var sliderValue: CGFloat = 0.5
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(LinearGradient(gradient: Gradient(colors: colorGradient), startPoint: .leading, endPoint: .trailing))
                    .frame(height: 20)
                
                Circle()
                    .frame(width: 30, height: 30)
                    .foregroundColor(.white)
                    .shadow(radius: 4)
                    .offset(x: sliderValue * geometry.size.width - 15)
                    .gesture(
                        DragGesture().onChanged { gesture in
                            // Update the slider value based on the gesture's location
                            sliderValue = min(max(0, gesture.location.x / geometry.size.width), 1)
                            // Update the selected color based on the new slider value
                            selectedColor = getColor(at: sliderValue)
                        }
                    )
            }
        }
        .frame(height: 30)
    }
    
    // Function to map the slider value to a color
    private func getColor(at value: CGFloat) -> Color {
        let gradientIndex = Int(value * CGFloat(colorGradient.count - 1))
        return colorGradient[gradientIndex]
    }
}
