import SwiftUI
import AVFoundation

struct StartGameView: View {
    @State private var numberOfPlayers: String = ""
    @State private var playerNames: [String] = [""]
    @StateObject private var cameraModel = CameraModel()
    
    var body: some View {
        VStack {
            Text("Start Game")
                .foregroundColor(.white)
                .font(.largeTitle)
                .padding()
            
            TextField("Enter number of players", text: $numberOfPlayers)
                .keyboardType(.numberPad)
                .padding()
                .background(Color.white)
                .cornerRadius(10)
            
            if let playersCount = Int(numberOfPlayers), playersCount > 0 {
                ForEach(0..<playersCount, id: \.self) { index in
                    TextField("Enter name for player \(index + 1)", text: Binding(
                        get: { playerNames[safe: index] ?? "" },
                        set: { newValue in
                            if playerNames.count <= index {
                                playerNames.append(newValue)
                            } else {
                                playerNames[index] = newValue
                            }
                        }
                    ))
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                }
            }
            
            ZStack {
                #if targetEnvironment(simulator)
                // Simulator placeholder
                Rectangle()
                    .fill(Color.gray)
                    .frame(height: 300)
                    .cornerRadius(10)
                    .overlay(
                        Text("Camera not available on simulator")
                            .foregroundColor(.white)
                    )
                #else
                CameraPreview(camera: cameraModel)
                    .frame(height: 300)
                    .cornerRadius(10)
                    .padding()
                #endif
                
                if cameraModel.isRecording {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .fill(Color.red)
                                .frame(width: 20, height: 20)
                        )
                }
            }
            Button (action: {
                cameraModel.switchCamera()
            }) {
                Label("Switch Camera", systemImage: "arrow.triangle.2.circlepath.camera")
            }.buttonStyle(.borderedProminent)
            HStack {
                Button(action: {
                    cameraModel.startRecording()
                }) {
                    Text("Start Recording")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    cameraModel.stopRecording()
                }) {
                    Text("Stop Recording")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                }
            }
            .padding()
            
            Button(action: {
                uploadVideo() // Upload the video after recording
            }) {
                Text("Upload Video")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            cameraModel.setup()
        }
    }
    
    // Function to upload the video to the FastAPI server
    func uploadVideo() {
        guard let videoURL = cameraModel.videoURL else {
            print("No video recorded")
            return
        }

        let url = URL(string: "http://128.61.68.146:8000/upload_video/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add the video file to the body
        let videoData = try? Data(contentsOf: videoURL)
        let videoFileName = "video.mov"
        
        if let videoData = videoData {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(videoFileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: video/quicktime\r\n\r\n".data(using: .utf8)!)
            body.append(videoData)
            body.append("\r\n".data(using: .utf8)!)
        }

        // Add the player name to the body
        let playerName = playerNames.first ?? "Player1" // Modify this as needed
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"player_names\"\r\n\r\n".data(using: .utf8)!)
        body.append(playerName.data(using: .utf8)!)  // Convert the player name to Data
        body.append("\r\n".data(using: .utf8)!)

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let session = URLSession.shared
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error uploading video: \(error)")
                return
            }
            print("Video uploaded successfully.")
        }.resume()
    }
    
    func trainModel() {
        let url = URL(string: "http://128.61.68.146:8000/train_model")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let session = URLSession.shared
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error training model: \(error)")
                return
            }
            print("Model training started.")
        }.resume()
    }
}

import AVFoundation

class CameraModel: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    public let session = AVCaptureSession()
    private let videoOutput = AVCaptureMovieFileOutput()
    private let queue = DispatchQueue(label: "camera.queue")
    @Published var isRecording = false
    var videoURL: URL? // Store the URL of the recorded video
    
    func setup() {
        #if targetEnvironment(simulator)
        print("Camera not available on simulator")
        return
        #else
        session.beginConfiguration()
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("No camera available")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }
            if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
            
            session.commitConfiguration()
            session.startRunning()
        } catch {
            print("Error setting up camera: \(error)")
        }
        #endif
    }
    
    func switchCamera() {
        #if targetEnvironment(simulator)
        print("Camera not available on simulator")
        return
        #else
        guard let currInput = session.inputs.first as? AVCaptureDeviceInput else {
            session.commitConfiguration()
            return
        }
        session.removeInput(currInput)
        let newPos: AVCaptureDevice.Position = (currInput.device.position == .back) ? .front : .back
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPos) else {
            print("bye bye")
            session.commitConfiguration()
            return
        }
        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
            }
        } catch {
            print("error w the camera")
        }
        #endif
    }
    
    func startRecording() {
        #if targetEnvironment(simulator)
        print("Camera not available on simulator")
        return
        #else
        guard !isRecording else { return }
        isRecording = true
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("recording-\(timestamp).mov")

        videoOutput.startRecording(to: tempURL, recordingDelegate: self)
        #endif
    }
    
    func stopRecording() {
        #if targetEnvironment(simulator)
        print("Camera not available on simulator")
        return
        #else
        guard isRecording else { return }
        isRecording = false
        videoOutput.stopRecording()
        #endif
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Recording error: \(error)")
        } else {
            print("Video saved at: \(outputFileURL)")
            videoURL = outputFileURL // Store the URL of the video
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        var previewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    let camera: CameraModel
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        #if !targetEnvironment(simulator)
        let session = camera.session
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        #else
        // Simulator fallback: Display a placeholder
        view.backgroundColor = .gray
        #endif
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {}
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
