
import SwiftUI
import AVKit
import UIKit

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var selectedVideoURL: URL?

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.movie"]  // Ensures only video files are available
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
