import SwiftUI
import AVFoundation
import CoreLocation

public struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var showingVideoPreview = false
    @State private var showingMediaPicker = false
    
    public init() {
        // Empty init to satisfy public access
    }
    
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
            } else if let session = viewModel.captureSession {
                CameraPreviewView(session: session)
                    .ignoresSafeArea()
            } else {
                // Show loading state while checking permissions/setting up camera
                ProgressView("Setting up camera...")
                    .onAppear {
                        viewModel.checkPermissions()
                    }
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
public class PreviewView: UIView {
    public override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    public var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    public var session: AVCaptureSession? {
        get { videoPreviewLayer.session }
        set { videoPreviewLayer.session = newValue }
    }
}

public struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    public init(session: AVCaptureSession) {
        self.session = session
    }
    
    public func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.session = session
        return view
    }
    
    public func updateUIView(_ uiView: PreviewView, context: Context) {
        // Update rotation if needed
        if #available(iOS 17.0, *) {
            uiView.videoPreviewLayer.connection?.videoRotationAngle = 0
        } else {
            uiView.videoPreviewLayer.connection?.videoOrientation = .portrait
        }
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
