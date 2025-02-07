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
                } else if let session = cameraViewModel.captureSession {
                    ZStack {
                        // Camera preview
                        CameraPreviewView(session: session)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .edgesIgnoringSafeArea(.all)
                        
                        // Semi-transparent bar for top safe area
                        VStack {
                            Rectangle()
                                .fill(Color.black.opacity(0.3))
                                .frame(height: geometry.safeAreaInsets.top)
                                .edgesIgnoringSafeArea(.top)
                            Spacer()
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
                            .padding(.bottom, 20)
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
            if !cameraViewModel.showPermissionDenied {
                cameraViewModel.setupCamera()
            }
        }
        .onDisappear {
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
