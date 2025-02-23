import Foundation

func uploadVideo(videoURL: URL, completion: @escaping (URL?) -> Void) {
    guard let url = URL(string: "http://your-fastapi-server-address/process-video/") else {
        print("Invalid URL")
        completion(nil)
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    
    // Generate a unique boundary string.
    let boundary = "Boundary-\(UUID().uuidString)"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    
    // Read the video file data.
    guard let videoData = try? Data(contentsOf: videoURL) else {
        print("Unable to read video file")
        completion(nil)
        return
    }
    
    // Build the multipart/form-data body.
    var body = Data()
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"video\"; filename=\"\(videoURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
    body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
    body.append(videoData)
    body.append("\r\n".data(using: .utf8)!)
    body.append("--\(boundary)--\r\n".data(using: .utf8)!)
    
    request.httpBody = body
    
    // Start the upload task.
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error uploading video: \(error)")
            completion(nil)
            return
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Invalid response")
            completion(nil)
            return
        }
        if httpResponse.statusCode == 200, let data = data {
            // Save the returned processed video to the Documents directory.
            let fileManager = FileManager.default
            if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let outputPath = documentsDirectory.appendingPathComponent("final_output_video.mp4")
                do {
                    try data.write(to: outputPath)
                    print("Processed video saved to \(outputPath)")
                    completion(outputPath)
                } catch {
                    print("Error saving processed video: \(error)")
                    completion(nil)
                }
            }
        } else {
            print("Server returned status code: \(httpResponse.statusCode)")
            completion(nil)
        }
    }
    task.resume()
}
