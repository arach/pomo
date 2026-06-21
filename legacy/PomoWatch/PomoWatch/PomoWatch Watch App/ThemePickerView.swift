//
//  ThemePickerView.swift
//  PomoWatch Watch App
//
//  Created by Arach Tchoupani on 2025-08-13.
//

import SwiftUI

struct ThemePickerView: View {
    @Binding var currentTheme: WatchTheme
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(WatchTheme.allCases, id: \.self) { theme in
                        Button(action: {
                            currentTheme = theme
                            dismiss()
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(theme.backgroundColor)
                                    .frame(height: 60)
                                
                                HStack {
                                    // Theme preview
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(theme.primaryColor)
                                            .frame(width: 10, height: 10)
                                        Circle()
                                            .fill(theme.accentColor)
                                            .frame(width: 10, height: 10)
                                        Circle()
                                            .fill(theme.buttonColor)
                                            .frame(width: 10, height: 10)
                                    }
                                    .padding(.leading, 10)
                                    
                                    Text(theme.rawValue)
                                        .font(.system(size: 16, weight: .medium, design: theme.fontDesign))
                                        .foregroundColor(theme.primaryColor)
                                    
                                    Spacer()
                                    
                                    if currentTheme == theme {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(theme.primaryColor)
                                            .padding(.trailing, 10)
                                    }
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Theme")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ThemePickerView(currentTheme: .constant(.minimal))
}