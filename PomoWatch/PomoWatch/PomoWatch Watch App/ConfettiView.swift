//
//  ConfettiView.swift
//  PomoWatch Watch App
//
//  Confetti animation for timer completion
//

import SwiftUI

struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []
    @Binding var isShowing: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiPieces) { piece in
                    ConfettiPieceView(piece: piece, screenSize: geometry.size)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            createConfetti()
        }
    }
    
    private func createConfetti() {
        // Create more confetti pieces for a better celebration
        confettiPieces = (0..<40).map { index in
            ConfettiPiece(
                x: CGFloat.random(in: 0...1), // Use relative positioning
                color: [
                    Color.red, 
                    Color.blue, 
                    Color.green, 
                    Color.yellow, 
                    Color.purple, 
                    Color.orange,
                    Color.pink,
                    Color.cyan
                ].randomElement()!,
                size: CGFloat.random(in: 3...6),
                delay: Double(index) * 0.02, // Stagger the animation
                rotationSpeed: Double.random(in: 180...540),
                horizontalMovement: CGFloat.random(in: -30...30)
            )
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: CGFloat // 0 to 1 (relative position)
    let color: Color
    let size: CGFloat
    let delay: Double
    let rotationSpeed: Double
    let horizontalMovement: CGFloat
}

struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    let screenSize: CGSize
    
    @State private var yPosition: CGFloat = 0
    @State private var xOffset: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 0
    
    var body: some View {
        // Use different shapes for variety
        Group {
            if piece.id.hashValue % 3 == 0 {
                Circle()
                    .fill(piece.color)
                    .frame(width: piece.size, height: piece.size)
            } else if piece.id.hashValue % 3 == 1 {
                Star(corners: 5, smoothness: 0.45)
                    .fill(piece.color)
                    .frame(width: piece.size * 1.2, height: piece.size * 1.2)
            } else {
                RoundedRectangle(cornerRadius: 1)
                    .fill(piece.color)
                    .frame(width: piece.size, height: piece.size * 1.5)
            }
        }
        .scaleEffect(scale)
        .position(
            x: piece.x * screenSize.width + xOffset,
            y: yPosition
        )
        .rotationEffect(.degrees(rotation))
        .opacity(opacity)
        .onAppear {
            // Start from top
            yPosition = -20
            
            // Animate falling with physics
            withAnimation(
                .interpolatingSpring(stiffness: 20, damping: 5)
                .delay(piece.delay)
            ) {
                yPosition = screenSize.height + 50
                xOffset = piece.horizontalMovement
                rotation = piece.rotationSpeed
                scale = 1
            }
            
            // Fade out near the end
            withAnimation(
                .easeIn(duration: 0.6)
                .delay(piece.delay + 2.2)
            ) {
                opacity = 0
            }
        }
    }
}

// Star shape for confetti variety
struct Star: Shape {
    let corners: Int
    let smoothness: Double
    
    func path(in rect: CGRect) -> Path {
        guard corners >= 2 else { return Path() }
        
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let angle = 2 * .pi / Double(corners * 2)
        let radius = min(rect.width, rect.height) / 2
        let innerRadius = radius * smoothness
        
        var path = Path()
        
        for i in 0..<corners * 2 {
            let currentAngle = angle * Double(i) - .pi / 2
            let currentRadius = i % 2 == 0 ? radius : innerRadius
            
            let x = center.x + CGFloat(cos(currentAngle)) * currentRadius
            let y = center.y + CGFloat(sin(currentAngle)) * currentRadius
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
}