import SwiftUI
import AVFoundation
import UIKit

struct RealTimeClipView: View {
    @StateObject private var realTimeClipCameraModel = RealTimeClipCameraModel()
    @EnvironmentObject var gameManager: GameManager  // Inject the shared GameManager
    
    var body: some View {
        Group {
            if gameManager.isGameActive {
                ZStack {
                    // Display the live camera feed.
                    RealTimeClipPreview(camera: realTimeClipCameraModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea() // Ensure it extends beyond safe areas
                    
                    VStack {
                        // Switch Camera Button
                        Button(action: {
                            realTimeClipCameraModel.switchCamera()
                        }) {
                            Label("Switch Camera", systemImage: "arrow.triangle.2.circlepath.camera")
                                .padding()
                                .background(Color.black.opacity(0.5))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.top, 600)
                        .padding(.bottom, 30)
                        .padding(.horizontal, 50)
                        
                        Spacer()
                        
                        // Red Toggle Button to Start/Stop Sending Frames
                        Button(action: {
                            realTimeClipCameraModel.isSending.toggle()
                            // If stopping, clear any stored frames.
                            if !realTimeClipCameraModel.isSending {
                                realTimeClipCameraModel.clearFrameBuffer()
                            }
                        }) {
                            Text(realTimeClipCameraModel.isSending ? "Stop Sending" : "Start Sending")
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(realTimeClipCameraModel.isSending ? Color.green : Color.red)
                                .cornerRadius(10)
                                .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 30)
                        
                        if let error = realTimeClipCameraModel.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .padding()
                        }
                    }
                }
                .onAppear {
                    realTimeClipCameraModel.setup()
                }
                .onDisappear {
                    realTimeClipCameraModel.session.stopRunning()
                }
            } else {
                // Game not started – prompt the user to start a game.
                VStack(spacing: 20) {
                    Text("Please start a game first.")
                        .font(.headline)
                        .foregroundColor(.white)
                    NavigationLink("Go to Start Game", destination: StartGameView())
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())
            }
        }
    }
}

struct RealTimeClipView_Previews: PreviewProvider {
    static var previews: some View {
        RealTimeClipView()
    }
}

// MARK: - RealTimeClipCameraModel

class RealTimeClipCameraModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    // The capture session used for real-time video.
    let session = AVCaptureSession()
   
    // Video data output for frame capture.
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoDataOutputQueue = DispatchQueue(label: "com.example.RealTimeClipVideoDataOutputQueue")
   
    // Queue to safely manage the frame buffer.
    private let bufferQueue = DispatchQueue(label: "com.example.RealTimeClipBufferQueue")
   
    // Buffer to hold the last 10 JPEG frames.
    private var frameBuffer: [Data] = []
   
    // Published flag to control sending frames.
    @Published var isSending: Bool = false
   
    // Published error message for UI feedback.
    @Published var errorMessage: String?
   
    /// Sets up the AVCaptureSession for live video capture.
    func setup() {
        #if targetEnvironment(simulator)
        errorMessage = "Camera not available on simulator"
        print(errorMessage!)
        return
        #endif
       
        session.beginConfiguration()
        session.sessionPreset = .high
       
        // Use the front camera by default.
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            errorMessage = "No camera available"
            print(errorMessage!)
            session.commitConfiguration()
            return
        }
       
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                errorMessage = "Unable to add camera input"
                print(errorMessage!)
                session.commitConfiguration()
                return
            }
        } catch {
            errorMessage = "Error setting up camera input: \(error)"
            print(errorMessage!)
            session.commitConfiguration()
            return
        }
       
        // Configure the video data output.
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
       
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            errorMessage = "Unable to add video data output"
            print(errorMessage!)
            session.commitConfiguration()
            return
        }
       
        session.commitConfiguration()
        session.startRunning()
    }
   
    /// Switches between the front and back cameras.
    func switchCamera() {
        #if targetEnvironment(simulator)
        print("Camera not available on simulator")
        return
        #else
        guard let currentInput = session.inputs.first as? AVCaptureDeviceInput else {
            session.commitConfiguration()
            return
        }
        session.removeInput(currentInput)
       
        // Toggle camera position.
        let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            print("No device found for new position")
            session.commitConfiguration()
            return
        }
       
        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
            }
        } catch {
            print("Error switching camera: \(error)")
        }
        #endif
    }
   
    /// Clears the frame buffer.
    func clearFrameBuffer() {
        bufferQueue.async {
            self.frameBuffer.removeAll()
        }
    }
   
    /// Delegate method called for each captured video frame.
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Only process frames if sending is enabled.
        guard isSending else { return }
       
        // Convert the sample buffer into a JPEG image.
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get pixel buffer")
            return
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            print("Failed to create CGImage")
            return
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
       
        let uiImage = UIImage(cgImage: cgImage)
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.8) else {
            print("Failed to convert UIImage to JPEG")
            return
        }
       
        bufferQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.frameBuffer.append(jpegData)
            
            if self.frameBuffer.count == 10 {
                let framesToSend = self.frameBuffer
                self.frameBuffer.removeAll()
                
                DispatchQueue.global(qos: .background).async {
                    self.sendFrames(frames: framesToSend)
                }
            }
        }
    }
   
    /// Sends an array of 10 JPEG frames to the FastAPI endpoint.
    private func sendFrames(frames: [Data]) {
        guard let url = URL(string: "http://128.61.68.146:8000/upload_clips/") else {
            print("Invalid URL for FastAPI endpoint")
            return
        }
       
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
       
        var body = Data()
        for (index, frameData) in frames.enumerated() {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            let filename = "frame_\(index).jpg"
            body.append("Content-Disposition: form-data; name=\"frames\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(frameData)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
       
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending frames: \(error)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("Unexpected HTTP response status: \(httpResponse.statusCode)")
                return
            }
            print("Successfully sent 10 frames to API.")
        }
        task.resume()
    }
}

// MARK: - RealTimeClipPreview

struct RealTimeClipPreview: UIViewRepresentable {
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        var previewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
   
    let camera: RealTimeClipCameraModel
   
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        #if !targetEnvironment(simulator)
        let session = camera.session
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        #else
        view.backgroundColor = .gray
        #endif
        return view
    }
   
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {}
}

// MARK: - Data Extension

extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            self.append(data)
        }
    }
}

