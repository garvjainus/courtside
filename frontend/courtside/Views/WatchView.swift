import SwiftUI
import AVKit

struct WatchView: View {
    @State private var processedVideoURL: URL?
    @State private var isLoading: Bool = true
    @State private var errorMessage: String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading processed video...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .foregroundColor(.white)
                        .padding()
                } else if let videoURL = processedVideoURL {
                    VideoPlayer(player: AVPlayer(url: videoURL))
                        .frame(height: 300)
                        .cornerRadius(10)
                        .padding()
                } else if !errorMessage.isEmpty {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                } else {
                    Text("No video available")
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Watch Processed Video")
            .onAppear {
                fetchProcessedVideo()
            }
        }
    }
    
    /// Fetches the processed video from the backend, saves it locally,
    /// and sets `processedVideoURL` for playback.
    func fetchProcessedVideo() {
        // Replace with the actual URL that returns your processed video.
        guard let requestURL = URL(string: "http://128.61.68.146:8000/final_output_video/") else {
            self.errorMessage = "Invalid video URL."
            self.isLoading = false
            return
        }
        
        let task = URLSession.shared.dataTask(with: requestURL) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Error: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "No data received from server."
                    self.isLoading = false
                }
                return
            }
            
            // Save the downloaded data to a file in the Documents directory.
            let fileManager = FileManager.default
            if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let localURL = documentsDirectory.appendingPathComponent("final_output_video.mp4")
                do {
                    try data.write(to: localURL)
                    DispatchQueue.main.async {
                        self.processedVideoURL = localURL
                        self.isLoading = false
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = "Error saving video: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                }
            }
        }
        task.resume()
    }
}

struct WatchView_Previews: PreviewProvider {
    static var previews: some View {
        // For preview purposes, use a dummy URL.
        WatchView()
    }
}
