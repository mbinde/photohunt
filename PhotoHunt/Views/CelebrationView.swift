import SwiftUI

struct ConfettiPiece: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let color: Color
    let size: CGFloat
    let rotation: Double
    let speed: Double
}

struct CelebrationView: View {
    let milestone: Int // 25, 50, 75, or 100
    @Binding var isShowing: Bool
    var onCreateSlideshow: (() -> Void)? = nil

    @State private var confetti: [ConfettiPiece] = []
    @State private var showText = false
    @State private var textScale: CGFloat = 0.5
    @State private var showSlideshowButton = false

    var milestoneText: String {
        switch milestone {
        case 100: return "Amazing!"
        case 75: return "Almost there!"
        case 50: return "Halfway!"
        case 25: return "Great start!"
        default: return "Nice!"
        }
    }

    var milestoneEmoji: String {
        switch milestone {
        case 100: return "🎉"
        case 75: return "⭐️"
        case 50: return "✨"
        case 25: return "🌟"
        default: return "👏"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Confetti pieces
                ForEach(confetti) { piece in
                    ConfettiShape(rotation: piece.rotation)
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 1.5)
                        .position(x: piece.x, y: piece.y)
                }

                // Milestone text
                if showText {
                    VStack(spacing: 8) {
                        Text(milestoneEmoji)
                            .font(.system(size: 60))
                        Text(milestoneText)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(milestone)% Complete")
                            .font(.headline)
                            .foregroundStyle(Theme.lavender)

                        // Show slideshow button for 100% completion
                        if milestone == 100 && showSlideshowButton && onCreateSlideshow != nil {
                            Button {
                                isShowing = false
                                onCreateSlideshow?()
                            } label: {
                                Label("Create Slideshow", systemImage: "film")
                                    .font(.headline)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.lavender)
                            .padding(.top, 12)
                        }
                    }
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.white)
                            .shadow(color: Theme.lavender.opacity(0.4), radius: 20)
                    )
                    .scaleEffect(textScale)
                }
            }
            .onAppear {
                startCelebration(in: geometry.size)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(true)
        .onTapGesture {
            withAnimation {
                isShowing = false
            }
        }
    }

    private func startCelebration(in size: CGSize) {
        // Create confetti pieces
        let colors: [Color] = [
            Theme.lavender,
            Theme.accentPink,
            Theme.accentMint,
            .yellow,
            .orange,
            Theme.found
        ]

        let pieceCount = milestone == 100 ? 80 : 40

        for _ in 0..<pieceCount {
            let piece = ConfettiPiece(
                x: CGFloat.random(in: 0...size.width),
                y: -20,
                color: colors.randomElement()!,
                size: CGFloat.random(in: 8...14),
                rotation: Double.random(in: 0...360),
                speed: Double.random(in: 2...4)
            )
            confetti.append(piece)
        }

        // Animate confetti falling
        animateConfetti(in: size)

        // Show text with bounce
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.3)) {
            showText = true
            textScale = 1.0
        }

        // For 100% with slideshow callback, show button and don't auto-dismiss
        if milestone == 100 && onCreateSlideshow != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showSlideshowButton = true
                }
            }
            // Don't auto-dismiss - let user tap button or tap to dismiss
        } else {
            // Auto-dismiss after delay for other milestones
            let dismissDelay: Double = milestone == 100 ? 3.0 : 2.0
            DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isShowing = false
                }
            }
        }
    }

    private func animateConfetti(in size: CGSize) {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            if !isShowing {
                timer.invalidate()
                return
            }

            for i in confetti.indices {
                confetti[i].y += confetti[i].speed * 3
                confetti[i].x += CGFloat.random(in: -1...1)
            }

            // Remove pieces that have fallen off screen
            confetti.removeAll { $0.y > size.height + 50 }

            if confetti.isEmpty {
                timer.invalidate()
            }
        }
    }
}

struct ConfettiShape: Shape {
    let rotation: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: 2, height: 2))
        return path
    }
}

#Preview {
    CelebrationView(milestone: 100, isShowing: .constant(true))
}
