import SwiftUI
import AVFoundation
import AVKit
import PhotosUI

struct CaptureView: View {
    @StateObject private var cameraViewModel = CameraViewModel()
    @State private var showPermissionAlert = false
    @State private var showVideoPreview = false
    @State private var showingMediaPicker = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if cameraViewModel.showPermissionDenied {
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
                } else if let previewLayer = cameraViewModel.previewLayer {
                    ZStack {
                        // Camera preview
                        CameraPreviewView(previewLayer: previewLayer)
                            .frame(width: geometry.size.width, height: geometry.size.height - 100) // Subtract space for tab bar
                            .onAppear {
                                previewLayer.frame = CGRect(x: 0, y: 0, 
                                                          width: geometry.size.width,
                                                          height: geometry.size.height - 100)
                            }
                            .onChange(of: geometry.size) { _ in
                                previewLayer.frame = CGRect(x: 0, y: 0,
                                                          width: geometry.size.width,
                                                          height: geometry.size.height - 100)
                            }
                        
                        // Recording controls
                        VStack {
                            Spacer()
                            HStack(spacing: 60) {
                                // Photo library button
                                Button(action: {
                                    showingMediaPicker = true
                                }) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                }
                                
                                // Record button
                                Button(action: {
                                    if cameraViewModel.isRecording {
                                        cameraViewModel.stopRecording()
                                        showVideoPreview = true
                                    } else {
                                        cameraViewModel.startRecording()
                                    }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(cameraViewModel.isRecording ? .red : .white)
                                            .frame(width: 80, height: 80)
                                        if cameraViewModel.isRecording {
                                            Circle()
                                                .stroke(Color.white, lineWidth: 4)
                                                .frame(width: 70, height: 70)
                                        }
                                    }
                                }
                                
                                // Camera switch button
                                Button(action: {
                                    cameraViewModel.switchCamera()
                                }) {
                                    Image(systemName: "camera.rotate")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.bottom, 20) // Reduced padding since we're already accounting for tab bar
                        }
                    }
                } else {
                    ProgressView("Setting up camera...")
                        .onAppear {
                            cameraViewModel.checkPermissions()
                        }
                }
            }
        }
        .onAppear {
            // Initialize camera immediately when view appears
            if !cameraViewModel.showPermissionDenied {
                cameraViewModel.setupCamera()
            }
        }
        .onDisappear {
            // Stop the session when leaving the view
            cameraViewModel.stopSession()
        }
        .sheet(isPresented: $showVideoPreview) {
            if let videoURL = cameraViewModel.recordedVideoURL {
                VideoPreviewView(videoURL: videoURL)
            }
        }
        .sheet(isPresented: $showingMediaPicker) {
            MediaPicker(completion: { url in
                if let url = url {
                    cameraViewModel.recordedVideoURL = url
                    showVideoPreview = true
                }
            })
        }
    }
}

#Preview {
    CaptureView()
}
