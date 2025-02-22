import SwiftUI
import AVFoundation
import CoreML
import Vision

struct StartGameView: View {
    @State private var showPicker = false
    @State private var selectedVideoURL: URL?
    @State private var numberOfPlayers: String = ""
    @State private var playerNames: [String] = [""]
    
    var body: some View {
        VStack {
            Text("Start Game")
                .foregroundColor(.white)
                .font(.largeTitle)
                .padding()

            // Input for number of players
            TextField("Enter number of players", text: $numberOfPlayers)
                .keyboardType(.numberPad)
                .padding()
                .background(Color.white)
                .cornerRadius(10)

            // Loop to show text fields for each player's name
            if let playersCount = Int(numberOfPlayers), playersCount > 0 {
                ForEach(0..<playersCount, id: \.self) { index in
                    TextField("Enter name for player \(index + 1)", text: Binding(
                        get: { playerNames[safe: index] ?? "" },
                        set: { newValue in
                            // Ensure the playerNames array can hold enough elements
                            if playerNames.count <= index {
                                playerNames.append(newValue)
                            }
                        }
                    ))
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                }
            }

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
                VideoPlayerView(videoURL: videoURL)
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

            // Button to train model after all videos are uploaded
            Button(action: {
                trainModel()
            }) {
                Text("Train Model")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(10)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $showPicker, content: {
            // Present video picker here
            VideoPicker(selectedVideoURL: $selectedVideoURL)
        })
    }

    func uploadVideoToServer(videoURL: URL) {
        guard let numberOfPlayers = Int(numberOfPlayers) else { return }

        let url = URL(string: "http://128.61.68.146:8000/upload_video")! // Replace with your FastAPI server URL
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()

        if let videoData = try? Data(contentsOf: videoURL) {
            let filename = videoURL.lastPathComponent
            let contentDisposition = "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n"
            let contentType = "Content-Type: video/mp4\r\n\r\n"
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(contentDisposition.data(using: .utf8)!)
            body.append(contentType.data(using: .utf8)!)
            
            body.append(videoData)
            body.append("\r\n".data(using: .utf8)!)
        }

        let playerNamesString = playerNames.joined(separator: ",")
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"player_names\"\r\n\r\n".data(using: .utf8)!)
        body.append(playerNamesString.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let session = URLSession.shared
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error uploading video: \(error)")
                return
            }
            print("Video uploaded successfully")
        }.resume()
    }

    func trainModel() {
        let url = URL(string: "http://128.61.68.146:8000/train_model")! // Replace with your FastAPI server URL
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Send a request to trigger the model training
        let session = URLSession.shared
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error training model: \(error)")
                return
            }
            // Handle the response from the server (e.g., success message)
            print("Model training started.")
        }.resume()
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct StartGameView_Previews: PreviewProvider {
    static var previews: some View {
        StartGameView()
    }
}
