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
                            }
                        }
                    ))
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                }
            }
            
            ZStack {
                CameraPreview(camera: cameraModel)
                    .frame(height: 300)
                    .cornerRadius(10)
                    .padding()
                
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
                trainModel()
            }) {
                Text("Train Model")
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

class CameraModel: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureMovieFileOutput()
    private let queue = DispatchQueue(label: "camera.queue")
    @Published var isRecording = false
    
    func setup() {
        session.beginConfiguration()
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
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
    }
    
    func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("tempVideo.mov")
        videoOutput.startRecording(to: tempURL, recordingDelegate: self)
    }
    
    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        videoOutput.stopRecording()
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Recording error: \(error)")
        } else {
            print("Video saved at: \(outputFileURL)")
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
        if let session = camera.session {
            view.previewLayer.session = session
            view.previewLayer.videoGravity = .resizeAspectFill
        }
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
