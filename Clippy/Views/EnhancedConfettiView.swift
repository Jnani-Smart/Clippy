import SwiftUI
import CoreGraphics

// iMessage-style confetti piece with paper rectangle shape
struct EnhancedConfettiPiece: Identifiable {
    let id = UUID()
    var position: CGPoint
    var rotation: Double
    var scale: CGFloat
    var color: Color
    var velocity: CGPoint
    var angularVelocity: Double
    var opacity: Double
    var depth: CGFloat // For 3D-like layering effect
    var rotationAxis: UnitPoint // For 3D-like rotation
    
    static func randomPiece(in rect: CGRect) -> EnhancedConfettiPiece {
        // iMessage-style color palette - bright and celebratory
        let colors: [Color] = [
            Color(red: 1.0, green: 0.42, blue: 0.42), // Coral red
            Color(red: 1.0, green: 0.84, blue: 0.0),  // Golden yellow
            Color(red: 0.56, green: 0.93, blue: 0.56), // Light green
            Color(red: 0.31, green: 0.78, blue: 0.95), // Sky blue
            Color(red: 0.85, green: 0.44, blue: 0.84), // Orchid purple
            Color(red: 1.0, green: 0.75, blue: 0.8),   // Pink
            Color(red: 0.0, green: 0.9, blue: 0.9)     // Cyan
        ]
        
        // Create a piece with randomized properties - iMessage style
        return EnhancedConfettiPiece(
            position: CGPoint(
                x: CGFloat.random(in: rect.minX...rect.maxX),
                y: rect.minY - CGFloat.random(in: 0...50) // Tighter starting heights for burst effect
            ),
            rotation: Double.random(in: 0...360),
            scale: CGFloat.random(in: 0.5...1.2), // More consistent sizes like iMessage
            color: colors.randomElement()!,
            velocity: CGPoint(
                x: CGFloat.random(in: -200...200),
                y: CGFloat.random(in: 600...1000) // Higher initial velocity for dramatic burst
            ),
            angularVelocity: Double.random(in: -720...720), // Faster rotation for paper effect
            opacity: Double.random(in: 0.8...1.0), // Higher starting opacity
            depth: CGFloat.random(in: 0.8...1.2), // Depth factor for scaling
            rotationAxis: [.center, .leading, .trailing].randomElement()! // Random rotation axis for 3D effect
        )
    }
}

// Enhanced confetti view with iMessage-style physics and visual effects
struct EnhancedConfettiView: View {
    @Binding var isActive: Bool
    @State private var pieces: [EnhancedConfettiPiece] = []
    @State private var timer: Timer? = nil
    @State private var elapsedTime: TimeInterval = 0
    @State private var isInitialBurst: Bool = true
    
    let duration: TimeInterval
    let intensity: Int
    let burstDuration: TimeInterval
    
    init(isActive: Binding<Bool>, duration: TimeInterval = 3.5, intensity: Int = 80, burstDuration: TimeInterval = 0.3) {
        self._isActive = isActive
        self.duration = duration
        self.intensity = intensity
        self.burstDuration = burstDuration
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Render each confetti piece with its own visual properties
                ForEach(pieces) { piece in
                    PaperRectangleView(piece: piece)
                        .blendMode(.plusLighter) // Adds a glow effect when pieces overlap
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
        isInitialBurst = true
        timer?.invalidate()
        
        // Create initial burst of confetti - concentrated for iMessage effect
        let rect = CGRect(origin: .zero, size: size)
        addConfettiBurst(in: rect, count: intensity)
        
        // Start animation timer with higher frame rate for smoother animation
        timer = Timer.scheduledTimer(withTimeInterval: 1/120, repeats: true) { _ in
            updateConfetti(in: rect)
        }
    }
    
    private func addConfettiBurst(in rect: CGRect, count: Int) {
        for _ in 0..<count {
            pieces.append(EnhancedConfettiPiece.randomPiece(in: rect))
        }
    }
    
    private func updateConfetti(in rect: CGRect) {
        elapsedTime += 1/120
        
        // Add additional bursts only during the initial burst phase - iMessage style
        if isInitialBurst && elapsedTime < burstDuration {
            if Int(elapsedTime * 1000) % 50 < 10 { // Add mini-bursts every 50ms during burst phase
                // Add smaller bursts for the explosive effect
                addConfettiBurst(in: rect, count: intensity / 10)
            }
        }
        
        // After burst duration, stop adding new confetti
        if elapsedTime >= burstDuration {
            isInitialBurst = false
        }
        
        // Update each piece with improved physics
        for i in 0..<pieces.count {
            if i < pieces.count { // Safety check
                var piece = pieces[i]
                
                // Apply more realistic physics
                let timeStep: CGFloat = 1/120
                
                // Update position based on velocity
                piece.position.y += piece.velocity.y * timeStep
                piece.position.x += piece.velocity.x * timeStep
                
                // Apply gravity with slight randomization for natural movement
                piece.velocity.y -= (350 + CGFloat.random(in: -20...20)) * timeStep // Stronger gravity
                
                // Apply horizontal air resistance and drift - more pronounced for paper
                piece.velocity.x *= 0.97 // Slightly more air resistance
                piece.velocity.x += CGFloat.random(in: -8...8) * timeStep // More random air currents
                
                // Update rotation with angular velocity
                piece.rotation += piece.angularVelocity * timeStep
                
                // Gradually slow down rotation - paper effect
                piece.angularVelocity *= 0.97
                
                // Fade out pieces as they fall - faster fade after burst
                if !isInitialBurst {
                    // Progressive fade based on elapsed time
                    let fadeRate = elapsedTime > duration * 0.7 ? 0.03 : 0.01
                    piece.opacity -= fadeRate
                }
                
                pieces[i] = piece
            }
        }
        
        // Remove pieces that have fallen off the screen or faded out
        pieces = pieces.filter { $0.position.y < rect.height + 100 && $0.opacity > 0.05 }
        
        // Stop the animation after the duration
        if elapsedTime >= duration || pieces.isEmpty {
            timer?.invalidate()
            timer = nil
            
            // Set isActive to false immediately when animation is complete
            if pieces.isEmpty {
                isActive = false
            } else {
                // Small delay to allow last pieces to fade out
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isActive = false
                }
            }
        }
    }
}

// iMessage-style paper rectangle view
struct PaperRectangleView: View {
    let piece: EnhancedConfettiPiece
    
    var body: some View {
        // Paper rectangle with slight curve for realism
        RoundedRectangle(cornerRadius: 1)
            .fill(piece.color)
            .frame(width: 5, height: 12) // Paper rectangle proportions
            .overlay(
                RoundedRectangle(cornerRadius: 1)
                    .stroke(piece.color.opacity(0.7), lineWidth: 0.5)
            )
            .scaleEffect(piece.scale * piece.depth) // Apply depth scaling for 3D effect
            .position(x: piece.position.x, y: piece.position.y)
            .rotation3DEffect(
                .degrees(piece.rotation),
                axis: (x: piece.rotationAxis == .leading ? 1 : 0,
                       y: piece.rotationAxis == .trailing ? 1 : 0,
                       z: piece.rotationAxis == .center ? 1 : 0)
            )
            .opacity(piece.opacity)
            .shadow(color: piece.color.opacity(0.2), radius: 0.5, x: 0, y: 0.5) // Subtle shadow for depth
    }
}

// Enhanced thank you view with iMessage-style animations perfectly synchronized with confetti
struct EnhancedThankYouView: View {
    @Binding var isShowing: Bool
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.8
    @State private var rotation: Double = -5
    @State private var showSubtitle: Bool = false
    @State private var showIcon: Bool = false
    
    var body: some View {
        ZStack {
            // Semi-transparent background overlay
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .opacity(opacity * 0.7)
                .animation(.easeOut(duration: 0.3), value: opacity) // Faster animation to match confetti
            
            // Main content container
            VStack(spacing: 16) {
                if showIcon {
                    // App icon with glow effect
                    Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: Color.white.opacity(0.5), radius: 15, x: 0, y: 0)
                        .transition(.scale.combined(with: .opacity))
                }
                
                // Main title with enhanced styling
                Text("Thank You for Downloading!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                
                if showSubtitle {
                    // Subtitle with animation
                    Text("Enjoy your enhanced clipboard experience")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .background(
                ZStack {
                    // Premium glass effect background
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    
                    // Subtle gradient overlay for depth
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .cornerRadius(24)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.6),
                            Color.white.opacity(0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Perfectly synchronized with confetti burst
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.1)) {
                opacity = 1
                scale = 1
                rotation = 0
            }
            
            // Staggered appearance of elements - faster to match confetti
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showIcon = true
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showSubtitle = true
                }
            }
            
            // Auto-dismiss after 3.5 seconds to match confetti duration
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                // Smooth fade out animation
                withAnimation(
                    Animation.interpolatingSpring(
                        mass: 1.0,
                        stiffness: 100,
                        damping: 16,
                        initialVelocity: 0
                    )
                ) {
                    opacity = 0
                    scale = 0.9
                    rotation = 0
                }
                
                // Ensure view is removed after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    isShowing = false
                }
            }
        }
    }
}