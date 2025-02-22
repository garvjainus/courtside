import SwiftUI
import AVFoundation
import CoreML
import Vision

struct StartGameView: View {
    @State private var showPicker = false
    @State private var selectedVideoURL: URL?

    var body: some View {
        VStack {
            Text("Start Game")
                .foregroundColor(.white)
                .font(.largeTitle)
                .padding()

            // Add your start game content here
            Button(action: {
                // Trigger the video picker to select a video for uploading
                showPicker.toggle()
            }) {
                Text("Start New Game")
                    .foregroundColor(.black)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
            }
            .padding()

            if let videoURL = selectedVideoURL {
                // Show video preview (optional)
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(height: 300)
                    .padding()

                // Button to upload the selected video for training
                Button(action: {
                    uploadVideoToServer(videoURL: videoURL)
                }) {
                    Text("Upload Video for Training")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $showPicker, content: {
            // Present video picker here
            VideoPicker(selectedVideoURL: $selectedVideoURL)
        })
    }

    // Function to upload the selected video to the FastAPI server
    func uploadVideoToServer(videoURL: URL) {
        let url = URL(string: "http://your-fastapi-server-url/upload_video")! // Replace with your FastAPI server URL

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Create the multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()

        // Add the video file to the form data
        if let videoData = try? Data(contentsOf: videoURL) {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(videoURL.lastPathComponent)\"\r\n")
            body.append("Content-Type: video/mp4\r\n\r\n")
            body.append(videoData)
            body.append("\r\n")
        }
        
        body.append("--\(boundary)--\r\n")
        request.httpBody = body

        // Send the request
        let session = URLSession.shared
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error uploading video: \(error)")
                return
            }
            // Handle the response from the server (e.g., success message)
            print("Video uploaded successfully")
        }.resume()
    }
}

struct StartGameView_Previews: PreviewProvider {
    static var previews: some View {
        StartGameView()
    }
}

// VideoPicker.swift
// Custom video picker to allow users to select a video file
import SwiftUI
import AVKit

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var selectedVideoURL: URL?

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.movie"]
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: VideoPicker

        init(_ parent: VideoPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let url = info[.mediaURL] as? URL {
                parent.selectedVideoURL = url
            }
            picker.dismiss(animated: true, completion: nil)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true, completion: nil)
        }
    }
}
