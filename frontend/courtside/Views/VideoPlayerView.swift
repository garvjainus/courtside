
import SwiftUI
import AVKit

struct VideoPlayerView: View {
    var videoURL: URL

    var body: some View {
        VStack {
            VideoPlayer(player: AVPlayer(url: videoURL))
                .frame(height: 300) // Adjust frame size as needed
                .padding()
        }
    }
}

struct VideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        VideoPlayerView(videoURL: URL(string: "https://www.example.com/video.mp4")!) // Example preview
    }
}
