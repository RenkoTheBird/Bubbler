//
//  FeedPresetPicker.swift
//  BubblerApp
//

import SwiftUI

struct FeedPresetPicker: View {
    @Binding var selectedPreset: FeedPreset
    var onSelect: (FeedPreset) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(FeedPreset.selectablePresets) { preset in
                Button {
                    selectedPreset = preset
                    onSelect(preset)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: selectedPreset == preset ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedPreset == preset ? .cyan : .white.opacity(0.45))
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white.opacity(0.95))

                            Text(preset.description)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.65))
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedPreset == preset ? Color.white.opacity(0.14) : Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        selectedPreset == preset ? Color.cyan.opacity(0.5) : Color.white.opacity(0.12),
                                        lineWidth: 1
                                    )
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(preset.title). \(preset.description)")
            }

            if selectedPreset == .custom {
                Text("Using custom mix — adjust weights in Advanced feed settings.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
