import SwiftUI
import AVFoundation
import CoreLocation

public struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var showingVideoPreview = false
    @State private var showingMediaPicker = false
    
    public var body: some View {
        ZStack {
            // Camera preview
            if viewModel.showPermissionDenied {
                VStack {
                    Text("Camera Access Required")
                        .font(.title2)
                        .padding(.bottom, 4)
                    Text("Please enable camera access in Settings to use this feature.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .padding(.top)
                }
                .padding()
            } else if let previewLayer = viewModel.previewLayer {
                CameraPreviewView(previewLayer: previewLayer)
                    .ignoresSafeArea()
            } else {
                // Show loading state while checking permissions/setting up camera
                ProgressView("Setting up camera...")
            }
            
            // Camera controls
            VStack {
                Spacer()
                
                HStack {
                    Button(action: {
                        showingMediaPicker = true
                    }) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding()
                    }
                    
                    Spacer()
                    
                    // Record button
                    Button(action: {
                        if viewModel.isRecording {
                            viewModel.stopRecording()
                            showingVideoPreview = true
                        } else {
                            viewModel.startRecording()
                        }
                    }) {
                        Circle()
                            .fill(viewModel.isRecording ? Color.red : Color.white)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                            )
                    }
                    
                    Spacer()
                    
                    // Camera switch button
                    Button(action: {
                        viewModel.switchCamera()
                    }) {
                        Image(systemName: "camera.rotate")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showingVideoPreview) {
            if let videoURL = viewModel.recordedVideoURL {
                VideoPreviewView(videoURL: videoURL)
            }
        }
        .sheet(isPresented: $showingMediaPicker) {
            MediaPicker(completion: { url in
                if let url = url {
                    viewModel.recordedVideoURL = url
                    showingVideoPreview = true
                }
            })
        }
        .onAppear {
            viewModel.checkPermissions()
            viewModel.setupCamera()
        }
    }
}

// Camera preview helper view
public struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    public func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        previewLayer.frame = uiView.bounds
    }
}

// Media picker for selecting existing videos
public struct MediaPicker: UIViewControllerRepresentable {
    let completion: (URL?) -> Void
    
    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.mediaTypes = ["public.movie"]
        picker.sourceType = .photoLibrary
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    public class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (URL?) -> Void
        
        init(completion: @escaping (URL?) -> Void) {
            self.completion = completion
        }
        
        public func imagePickerController(_ picker: UIImagePickerController,
                                 didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let url = info[.mediaURL] as? URL {
                completion(url)
            } else {
                completion(nil)
            }
            picker.dismiss(animated: true)
        }
        
        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            completion(nil)
            picker.dismiss(animated: true)
        }
    }
}
