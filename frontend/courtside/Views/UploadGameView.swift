import SwiftUI
import AVKit
import AVFoundation
import UIKit

struct UploadGameView: View {
    @EnvironmentObject var gameManager: GameManager  // Inject the shared GameManager
    
    @State private var selectedVideoURL: URL?
    @State private var showVideoPicker = false
    @State private var trimStart: Double = 0
    @State private var trimEnd: Double = 0
    @State private var videoDuration: Double = 0
    @State private var isUploading: Bool = false
    @State private var uploadMessage: String = ""
    
    // Holds the processed video file URL returned from the server.
    @State private var processedVideoURL: URL?
    // When true, navigates to the WatchView.
    @State private var navigateToWatchView: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let videoURL = selectedVideoURL {
                    // Video preview
                    VideoPlayer(player: AVPlayer(url: videoURL))
                        .frame(height: 300)
                        .cornerRadius(10)
                        .padding()
                    
                    Text("Trim Video")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    VStack {
                        // Display trim start/end times
                        HStack {
                            Text("Start: \(formatTime(trimStart))")
                                .foregroundColor(.white)
                            Spacer()
                            Text("End: \(formatTime(trimEnd))")
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal)
                        
                        // Slider for trim start
                        Slider(value: $trimStart, in: 0...videoDuration, step: 0.1)
                            .accentColor(.green)
                            .padding(.horizontal)
                            .onChange(of: trimStart) { newValue in
                                if newValue > trimEnd {
                                    trimStart = trimEnd
                                }
                            }
                        
                        // Slider for trim end
                        Slider(value: $trimEnd, in: 0...videoDuration, step: 0.1)
                            .accentColor(.red)
                            .padding(.horizontal)
                            .onChange(of: trimEnd) { newValue in
                                if newValue < trimStart {
                                    trimEnd = trimStart
                                }
                            }
                    }
                    
                    // Submit (trim & upload) button
                    Button(action: {
                        trimAndUploadVideo()
                    }) {
                        if isUploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding()
                        } else {
                            Text("Submit")
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .background(Color.blue)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    if !uploadMessage.isEmpty {
                        Text(uploadMessage)
                            .foregroundColor(.white)
                            .padding()
                    }
                } else {
                    Text("Select a video to upload")
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Button to open the video picker
                Button(action: {
                    showVideoPicker = true
                }) {
                    Text("Select Video")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                }
                .background(Color.gray)
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Hidden NavigationLink that triggers when processedVideoURL is available.
                NavigationLink(
                    destination: WatchView(),
                    isActive: $navigateToWatchView,
                    label: { EmptyView() }
                )
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Upload Game Video")
            .sheet(isPresented: $showVideoPicker) {
                CustomVideoPicker(
                    videoURL: $selectedVideoURL,
                    videoDuration: $videoDuration,
                    trimEnd: $trimEnd
                )
            }
        }
    }
    
    // Formats seconds into mm:ss
    func formatTime(_ time: Double) -> String {
        let intTime = Int(time)
        let minutes = intTime / 60
        let seconds = intTime % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // Trims the selected video and uploads it.
    func trimAndUploadVideo() {
        guard let videoURL = selectedVideoURL else { return }
        isUploading = true
        uploadMessage = ""
        
        let asset = AVAsset(url: videoURL)
        let exportPreset = AVAssetExportPresetHighestQuality
        
        guard
            AVAssetExportSession.exportPresets(compatibleWith: asset).contains(exportPreset),
            let exportSession = AVAssetExportSession(asset: asset, presetName: exportPreset)
        else {
            uploadMessage = "Export preset not supported"
            isUploading = false
            return
        }
        
        let start = CMTime(seconds: trimStart, preferredTimescale: 600)
        let duration = CMTime(seconds: trimEnd - trimStart, preferredTimescale: 600)
        exportSession.timeRange = CMTimeRange(start: start, duration: duration)
        
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("trimmedVideo.mov")
        try? FileManager.default.removeItem(at: outputURL)
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                if exportSession.status == .completed {
                    self.uploadVideo(fileURL: outputURL)
                } else {
                    self.uploadMessage = "Error trimming video: \(exportSession.error?.localizedDescription ?? "Unknown error")"
                    self.isUploading = false
                }
            }
        }
    }
    
    // Uploads the trimmed video to the FastAPI endpoint.
    func uploadVideo(fileURL: URL) {
        // Replace with your FastAPI endpoint URL.
        let url = URL(string: "http://128.61.68.146:8000/upload_game/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        if let videoData = try? Data(contentsOf: fileURL) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            let fileName = "game_video.mov"
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: video/quicktime\r\n\r\n".data(using: .utf8)!)
            body.append(videoData)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isUploading = false
                if let error = error {
                    self.uploadMessage = "Upload error: \(error.localizedDescription)"
                } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let data = data {
                    // Save the processed video to the Documents directory.
                    let fileManager = FileManager.default
                    if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                        let outputPath = documentsDirectory.appendingPathComponent("final_output_video.mp4")
                        do {
                            try data.write(to: outputPath)
                            self.uploadMessage = "Video uploaded successfully!"
                            self.processedVideoURL = outputPath
                            // Navigate to WatchView now that we have the processed video.
                            self.navigateToWatchView = true
                        } catch {
                            self.uploadMessage = "Error saving processed video: \(error.localizedDescription)"
                        }
                    }
                } else {
                    self.uploadMessage = "Server returned status code: \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                }
            }
        }.resume()
    }
}

// MARK: - CustomVideoPicker

/// A custom picker to let users select a video from their photo library.
struct CustomVideoPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var videoURL: URL?
    @Binding var videoDuration: Double
    @Binding var trimEnd: Double
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.mediaTypes = ["public.movie"]
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates required.
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CustomVideoPicker
        
        init(_ parent: CustomVideoPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let url = info[.mediaURL] as? URL {
                parent.videoURL = url
                let asset = AVAsset(url: url)
                let duration = CMTimeGetSeconds(asset.duration)
                parent.videoDuration = duration
                parent.trimEnd = duration
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
