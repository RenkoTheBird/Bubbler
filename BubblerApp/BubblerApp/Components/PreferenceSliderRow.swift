//
//  PreferenceSliderRow.swift
//  BubblerApp
//

import SwiftUI

struct PreferenceSliderRow: View {
    let title: String
    @Binding var value: Double
    let tint: Color
    var isDisabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .foregroundColor(.white.opacity(0.9))
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(Int((value * 100).rounded()))%")
                    .foregroundColor(.white.opacity(0.72))
                    .font(.caption.monospacedDigit())
            }

            Slider(value: $value, in: 0 ... 1)
                .tint(tint)
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.45 : 1)
        }
    }
}
