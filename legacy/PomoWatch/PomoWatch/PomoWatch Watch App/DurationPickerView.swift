//
//  DurationPickerView.swift
//  PomoWatch Watch App
//
//  Created by Arach Tchoupani on 2025-08-13.
//

import SwiftUI
import WatchKit

struct DurationPickerView: View {
    @Binding var selectedMinutes: Int
    @Environment(\.dismiss) private var dismiss
    
    let presetDurations = [5, 10, 15, 20, 25, 30, 45, 60]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Duration")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.gray.opacity(0.6))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            
            // Duration options
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(presetDurations, id: \.self) { minutes in
                        Button(action: {
                            selectedMinutes = minutes
                            // Add haptic feedback
                            WKInterfaceDevice.current().play(.click)
                            // Auto-dismiss after selection with slight delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                dismiss()
                            }
                        }) {
                            HStack {
                                Text("\(minutes)")
                                    .font(.system(size: 20, weight: selectedMinutes == minutes ? .semibold : .medium, design: .rounded))
                                    .frame(width: 40, alignment: .trailing)
                                    .foregroundColor(selectedMinutes == minutes ? .white : .white.opacity(0.8))
                                
                                Text("min")
                                    .font(.system(size: 14))
                                    .foregroundColor(selectedMinutes == minutes ? .white.opacity(0.9) : .secondary)
                                
                                Spacer()
                                
                                if selectedMinutes == minutes {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedMinutes == minutes ? 
                                         Color.blue.opacity(0.25) : 
                                         Color.gray.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedMinutes == minutes ? 
                                                   Color.blue.opacity(0.5) : 
                                                   Color.clear, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
        }
        .background(Color.black)
    }
}

#Preview {
    DurationPickerView(selectedMinutes: .constant(25))
}