import SwiftUI
import AVKit

struct CustomVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    let videoGravityForPlayer: AVLayerVideoGravity

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = videoGravityForPlayer
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        // Если плеер изменится, обновляем его
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
        // Если режим масштабирования изменился, обновляем его
        if uiView.playerLayer.videoGravity != videoGravityForPlayer {
            uiView.playerLayer.videoGravity = videoGravityForPlayer
        }
    }
}

class PlayerUIView: UIView {
    // Используем AVPlayerLayer как слой этого UIView
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        if let avLayer = layer as? AVPlayerLayer {
            return avLayer
        } else {
            assertionFailure("Ожидался AVPlayerLayer для слоя PlayerUIView, создан fallback слой")
            let fallbackLayer = AVPlayerLayer()
            fallbackLayer.frame = bounds
            return fallbackLayer
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Убедимся, что слой плеера всегда соответствует размерам UIView
        playerLayer.frame = bounds
    }
} 