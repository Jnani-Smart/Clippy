import SwiftUI

struct ConfettiPiece: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var rotation: Double
    var scale: CGFloat
    var color: Color
    var shape: ConfettiShape
    var velocity: CGPoint
    var rotationSpeed: Double
    
    enum ConfettiShape {
        case circle
        case triangle
        case square
        case squiggle
    }
    
    static func randomPiece(in rect: CGRect) -> ConfettiPiece {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
        let shapes: [ConfettiShape] = [.circle, .triangle, .square, .squiggle]
        
        return ConfettiPiece(
            x: CGFloat.random(in: rect.minX...rect.maxX),
            y: rect.minY - 50,
            rotation: Double.random(in: 0...360),
            scale: CGFloat.random(in: 0.5...1.5),
            color: colors.randomElement()!,
            shape: shapes.randomElement()!,
            velocity: CGPoint(
                x: CGFloat.random(in: -100...100),
                y: CGFloat.random(in: 300...600)
            ),
            rotationSpeed: Double.random(in: -360...360)
        )
    }
}

struct ConfettiView: View {
    @Binding var isActive: Bool
    @State private var pieces: [ConfettiPiece] = []
    @State private var timer: Timer? = nil
    @State private var elapsedTime: TimeInterval = 0
    let duration: TimeInterval
    let intensity: Int
    
    init(isActive: Binding<Bool>, duration: TimeInterval = 3.0, intensity: Int = 50) {
        self._isActive = isActive
        self.duration = duration
        self.intensity = intensity
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(pieces) { piece in
                    ConfettiPieceView(piece: piece)
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    startConfetti(in: geometry.size)
                }
            }
        }
    }
    
    private func startConfetti(in size: CGSize) {
        // Reset state
        pieces = []
        elapsedTime = 0
        timer?.invalidate()
        
        // Create initial pieces
        let rect = CGRect(origin: .zero, size: size)
        for _ in 0..<intensity {
            pieces.append(ConfettiPiece.randomPiece(in: rect))
        }
        
        // Start animation timer
        timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
            updateConfetti(in: rect)
        }
    }
    
    private func updateConfetti(in rect: CGRect) {
        elapsedTime += 1/60
        
        // Update each piece's position
        for i in 0..<pieces.count {
            if i < pieces.count { // Safety check
                var piece = pieces[i]
                
                // Apply gravity and movement
                let timeStep: CGFloat = 1/60
                piece.y += piece.velocity.y * timeStep
                piece.x += piece.velocity.x * timeStep
                piece.velocity.y -= 200 * timeStep // Gravity
                piece.rotation += piece.rotationSpeed * timeStep
                
                // Apply some drag
                piece.velocity.x *= 0.99
                piece.velocity.y *= 0.99
                
                pieces[i] = piece
            }
        }
        
        // Remove pieces that have fallen off the screen
        pieces = pieces.filter { $0.y < rect.height + 100 }
        
        // Stop the animation after the duration
        if elapsedTime >= duration {
            timer?.invalidate()
            timer = nil
            
            // Delay setting isActive to false to allow pieces to fall off screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isActive = false
            }
        }
    }
}

struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    
    var body: some View {
        confettiShape
            .foregroundColor(piece.color)
            .frame(width: 8, height: 8)
            .scaleEffect(piece.scale)
            .position(x: piece.x, y: piece.y)
            .rotationEffect(.degrees(piece.rotation))
    }
    
    @ViewBuilder
    private var confettiShape: some View {
        switch piece.shape {
        case .circle:
            Circle()
        case .triangle:
            Triangle()
        case .square:
            Rectangle()
        case .squiggle:
            Squiggle()
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct Squiggle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control1: CGPoint(x: rect.width * 0.3, y: rect.height * 0.3),
            control2: CGPoint(x: rect.width * 0.7, y: rect.height * 0.7)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY + 2))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.midY + 2),
            control1: CGPoint(x: rect.width * 0.7, y: rect.height * 0.7 + 2),
            control2: CGPoint(x: rect.width * 0.3, y: rect.height * 0.3 + 2)
        )
        path.closeSubpath()
        return path
    }
}

struct ThankYouView: View {
    @Binding var isShowing: Bool
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.5
    
    var body: some View {
        VStack {
            Text("Thank You for Downloading!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding()
                .background(
                    ZStack {
                        VisualEffectView(material: .popover, blendingMode: .withinWindow)
                        Color.white.opacity(0.1)
                    }
                    .cornerRadius(16)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .opacity(opacity)
                .scaleEffect(scale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                opacity = 1
                scale = 1
            }
            
            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeOut(duration: 0.5)) {
                    opacity = 0
                    scale = 0.8
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isShowing = false
                }
            }
        }
    }
}