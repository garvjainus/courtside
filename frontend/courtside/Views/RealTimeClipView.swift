import SwiftUI
import AVFoundation
import UIKit

// MARK: - RealTimeClipView

struct RealTimeClipView: View {
    @StateObject private var realTimeClipCameraModel = RealTimeClipCameraModel()
    
    var body: some View {
        ZStack {
            // Use our new preview that accepts RealTimeClipCameraModel.
            RealTimeClipPreview(camera: realTimeClipCameraModel)
            
            // Optionally overlay any text or UI elements if needed.
            VStack {
                Spacer()
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
    }
}

struct RealTimeClipView_Previews: PreviewProvider {
    static var previews: some View {
        RealTimeClipView()
    }
}

// MARK: - RealTimeClipCameraModel

class RealTimeClipCameraModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    // The camera session used for capturing live video.
    let session = AVCaptureSession()
    
    // Video data output for obtaining frame buffers.
    private let videoDataOutput = AVCaptureVideoDataOutput()
    
    // Queue for processing video data output delegate calls.
    private let videoDataOutputQueue = DispatchQueue(label: "com.example.RealTimeClipVideoDataOutputQueue")
    
    // A separate serial queue to ensure thread-safe access to the frame buffer.
    private let bufferQueue = DispatchQueue(label: "com.example.RealTimeClipBufferQueue")
    
    // Cache to hold the last 10 frames (as JPEG Data)
    private var frameBuffer: [Data] = []
    
    // Optional error message to display on the UI.
    @Published var errorMessage: String?
    
    /// Sets up the AVCaptureSession with a video data output.
    func setup() {
        #if targetEnvironment(simulator)
        errorMessage = "Camera not available on simulator"
        print(errorMessage!)
        return
        #endif
        
        session.beginConfiguration()
        session.sessionPreset = .high
        
        // Choose the front camera (or change to .back as needed)
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
                errorMessage = "Unable to add camera input to session"
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
    
    /// Delegate method that is called for every video frame captured.
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Convert the sample buffer to a JPEG image.
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
        
        // Cache the frame in a thread-safe manner.
        bufferQueue.async { [weak self] in
            guard let self = self else { return }
            self.frameBuffer.append(jpegData)
            
            // When 10 frames have been collected, send them to the API.
            if self.frameBuffer.count >= 10 {
                let framesToSend = Array(self.frameBuffer.suffix(10))
                self.frameBuffer.removeAll()
                self.sendFrames(frames: framesToSend)
            }
        }
    }
    
    /// Sends an array of 10 JPEG frames to the FastAPI endpoint.
    private func sendFrames(frames: [Data]) {
        guard let url = URL(string: "http://128.61.68.146:8000/upload_clip") else {
            print("Invalid URL for FastAPI endpoint")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Create a unique boundary string using a UUID.
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Build the multipart form data.
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
        
        // Perform the network request.
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

/// This is a preview view tailored for RealTimeClipCameraModel.
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

/// Helper to append Data.
extension Data {
    mutating func append(_ data: Data) {
        self.append(data)
    }
}
