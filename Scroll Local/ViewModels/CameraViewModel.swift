import Foundation
import AVFoundation
import CoreLocation
import UIKit

public class CameraViewModel: NSObject, ObservableObject {
    @Published public var isRecording = false
    @Published public var recordedVideoURL: URL?
    @Published public var previewLayer: AVCaptureVideoPreviewLayer?
    @Published public var showPermissionDenied = false
    
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var currentDevice: AVCaptureDevice?
    private let locationManager = CLLocationManager()
    
    public override init() {
        super.init()
        locationManager.delegate = self
    }
    
    public func checkPermissions() {
        // Check camera permissions
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.showPermissionDenied = false
                        self?.setupCamera()
                    } else {
                        self?.showPermissionDenied = true
                    }
                }
            }
        case .restricted, .denied:
            DispatchQueue.main.async {
                self.showPermissionDenied = true
            }
        case .authorized:
            showPermissionDenied = false
            setupCamera()
        @unknown default:
            break
        }
        
        // Check location permissions
        locationManager.requestWhenInUseAuthorization()
    }
    
    public func setupCamera() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.setupCameraInternal()
        }
    }
    
    private func setupCameraInternal() {
        // Ensure we're on the main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.setupCamera()
            }
            return
        }
        
        // Check if we already have a running session
        if let session = captureSession, session.isRunning {
            return
        }
        let session = AVCaptureSession()
        
        // Set up video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: .back) else { return }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        
        guard session.canAddInput(videoInput) else { return }
        session.addInput(videoInput)
        
        // Set up audio input
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else { return }
        guard let audioInput = try? AVCaptureDeviceInput(device: audioDevice) else { return }
        guard session.canAddInput(audioInput) else { return }
        session.addInput(audioInput)
        
        // Set up video output
        let output = AVCaptureMovieFileOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        
        // Set up preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        
        self.captureSession = session
        self.videoOutput = output
        self.previewLayer = previewLayer
        self.currentDevice = videoDevice
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    public func startRecording() {
        guard let output = videoOutput else { return }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        output.startRecording(to: tempURL, recordingDelegate: self)
        isRecording = true
    }
    
    public func stopRecording() {
        videoOutput?.stopRecording()
        isRecording = false
    }
    
    public func switchCamera() {
        guard let session = captureSession,
              let currentDevice = currentDevice else { return }
        
        // Get new camera position
        let newPosition: AVCaptureDevice.Position = currentDevice.position == .back ? .front : .back
        
        // Get new device
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                     for: .video,
                                                     position: newPosition) else { return }
        
        // Get new input
        guard let newInput = try? AVCaptureDeviceInput(device: newDevice) else { return }
        
        // Remove old input and add new input
        session.beginConfiguration()
        if let input = session.inputs.first as? AVCaptureDeviceInput {
            session.removeInput(input)
        }
        if session.canAddInput(newInput) {
            session.addInput(newInput)
        }
        session.commitConfiguration()
        
        self.currentDevice = newDevice
    }
    
    public func getVideoLocation() -> CLLocation? {
        if locationManager.authorizationStatus == .authorizedWhenInUse {
            return locationManager.location
        }
        return nil
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension CameraViewModel: AVCaptureFileOutputRecordingDelegate {
    public func fileOutput(_ output: AVCaptureFileOutput,
                   didFinishRecordingTo outputFileURL: URL,
                   from connections: [AVCaptureConnection],
                   error: Error?) {
        if error == nil {
            self.recordedVideoURL = outputFileURL
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension CameraViewModel: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // Handle location authorization changes if needed
    }
}
