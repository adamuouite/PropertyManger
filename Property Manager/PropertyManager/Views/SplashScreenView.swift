import SwiftUI
import AVKit

struct SplashScreenView: View {
    var onFinished: () -> Void

    @State private var player: AVPlayer?
    @State private var fadeOut = false

    var body: some View {
        ZStack {
            // Background matching video's teal color to avoid flash
            Color(red: 0.29, green: 0.47, blue: 0.47)
                .ignoresSafeArea()

            if let player {
                VideoPlayerView(player: player)
                    .ignoresSafeArea()
            }
        }
        .opacity(fadeOut ? 0 : 1)
        .onAppear {
            loadAndPlay()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func loadAndPlay() {
        // Look for the video in the app bundle's Resources
        guard let url = Bundle.main.url(forResource: "SplashVideo", withExtension: "mp4") else {
            // No video bundled — just dismiss after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                onFinished()
            }
            return
        }

        let avPlayer = AVPlayer(url: url)
        avPlayer.isMuted = true
        self.player = avPlayer

        // Watch for video end
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            withAnimation(.easeOut(duration: 0.4)) {
                fadeOut = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                onFinished()
            }
        }

        avPlayer.play()
    }
}

// MARK: - AVPlayer NSView wrapper (no controls, fills frame)

struct VideoPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.wantsLayer = true
        view.layer?.addSublayer(playerLayer)
        playerLayer.frame = view.bounds
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let playerLayer = nsView.layer?.sublayers?.first as? AVPlayerLayer {
            playerLayer.frame = nsView.bounds
        }
    }
}

// MARK: - Logo (kept for LoginView)

struct LogoView: View {
    var foreground: Color = Color(red: 0.73, green: 0.82, blue: 0.69)
    var windowColor: Color = Color(red: 0.29, green: 0.47, blue: 0.47)

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cornerRadius: CGFloat = w * 0.12

            // Outer rounded rectangle (phone/card shape)
            let outerRect = CGRect(x: w * 0.1, y: 0, width: w * 0.8, height: h)
            let outerPath = Path(roundedRect: outerRect, cornerRadius: cornerRadius)
            context.stroke(outerPath, with: .color(foreground), lineWidth: w * 0.045)

            // Notch at top
            let notchW = w * 0.2
            let notchH = h * 0.015
            let notchRect = CGRect(x: (w - notchW) / 2, y: h * 0.06, width: notchW, height: notchH)
            let notchPath = Path(roundedRect: notchRect, cornerRadius: notchH / 2)
            context.fill(notchPath, with: .color(foreground))

            // Building body - center column
            let bx = w * 0.35
            let bw = w * 0.3
            let by = h * 0.28
            let bh = h * 0.62
            let buildingRect = CGRect(x: bx, y: by, width: bw, height: bh)
            context.fill(Path(buildingRect), with: .color(foreground))

            // Left wing
            let lwx = w * 0.2
            let lww = w * 0.18
            let lwy = h * 0.42
            let lwh = h * 0.48
            let leftWing = CGRect(x: lwx, y: lwy, width: lww, height: lwh)
            context.fill(Path(leftWing), with: .color(foreground))

            // Right wing
            let rwx = w * 0.62
            let rightWing = CGRect(x: rwx, y: lwy, width: lww, height: lwh)
            context.fill(Path(rightWing), with: .color(foreground))

            // Roof triangle
            var roofPath = Path()
            roofPath.move(to: CGPoint(x: w * 0.5, y: h * 0.16))
            roofPath.addLine(to: CGPoint(x: w * 0.32, y: h * 0.30))
            roofPath.addLine(to: CGPoint(x: w * 0.68, y: h * 0.30))
            roofPath.closeSubpath()
            context.fill(roofPath, with: .color(foreground))

            // Roof eaves
            var eavePath = Path()
            eavePath.move(to: CGPoint(x: w * 0.5, y: h * 0.21))
            eavePath.addLine(to: CGPoint(x: w * 0.28, y: h * 0.34))
            eavePath.addLine(to: CGPoint(x: w * 0.72, y: h * 0.34))
            eavePath.closeSubpath()
            context.stroke(eavePath, with: .color(foreground.opacity(0.5)), lineWidth: 1)

            // Windows
            let winW = w * 0.08
            let winH = h * 0.06
            let winGapV = h * 0.09

            // Center column windows (2 columns, 4 rows)
            for row in 0..<4 {
                let wy = h * 0.36 + CGFloat(row) * winGapV
                let wx1 = w * 0.38
                context.fill(Path(CGRect(x: wx1, y: wy, width: winW, height: winH)), with: .color(windowColor))
                let wx2 = w * 0.54
                context.fill(Path(CGRect(x: wx2, y: wy, width: winW, height: winH)), with: .color(windowColor))
            }

            // Left wing windows (1 column, 3 rows)
            for row in 0..<3 {
                let wy = h * 0.48 + CGFloat(row) * winGapV
                let wx = w * 0.24
                context.fill(Path(CGRect(x: wx, y: wy, width: winW, height: winH)), with: .color(windowColor))
            }

            // Right wing windows (1 column, 3 rows)
            for row in 0..<3 {
                let wy = h * 0.48 + CGFloat(row) * winGapV
                let wx = w * 0.68
                context.fill(Path(CGRect(x: wx, y: wy, width: winW, height: winH)), with: .color(windowColor))
            }
        }
    }
}
