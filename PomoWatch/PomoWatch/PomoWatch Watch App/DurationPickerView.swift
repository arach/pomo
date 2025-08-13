//
//  DurationPickerView.swift
//  PomoWatch Watch App
//
//  Created by Arach Tchoupani on 2025-08-13.
//

import SwiftUI

struct DurationPickerView: View {
    @Binding var selectedMinutes: Int
    @Binding var timeRemaining: Int
    @Environment(\.dismiss) private var dismiss
    
    let presetDurations = [5, 10, 15, 20, 25, 30, 45, 60]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    Text("Set Timer Duration")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 5)
                    
                    ForEach(presetDurations, id: \.self) { minutes in
                        Button(action: {
                            selectedMinutes = minutes
                            timeRemaining = minutes * 60
                            dismiss()
                        }) {
                            HStack {
                                Text("\(minutes)")
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .frame(width: 40, alignment: .trailing)
                                
                                Text("minutes")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                if selectedMinutes == minutes {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedMinutes == minutes ? 
                                         Color.blue.opacity(0.2) : 
                                         Color.gray.opacity(0.1))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DurationPickerView(selectedMinutes: .constant(25), timeRemaining: .constant(1500))
}