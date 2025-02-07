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
    
    public func stopSession() {
        let cameraQueue = DispatchQueue(label: "com.scrolllocal.camera.session")
        cameraQueue.async { [weak self] in
            guard let session = self?.captureSession, session.isRunning else { return }
            session.stopRunning()
        }
    }
    
    public func startSession() {
        let cameraQueue = DispatchQueue(label: "com.scrolllocal.camera.session")
        cameraQueue.async { [weak self] in
            guard let session = self?.captureSession, !session.isRunning else { return }
            session.startRunning()
        }
    }
    
    private func setupCameraInternal() {
        // Create a serial queue for camera operations
        let cameraQueue = DispatchQueue(label: "com.scrolllocal.camera.setup")
        
        cameraQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Stop any existing session
            self.stopSession()
            
            // Create and configure capture session
            let session = AVCaptureSession()
            
            // Start configuration
            session.beginConfiguration()
            
            // Set session preset
            session.sessionPreset = .high
            
            // Set up video input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("Failed to get video device")
                return
            }
            
            do {
                // Configure device for better preview
                try videoDevice.lockForConfiguration()
                if videoDevice.isFocusModeSupported(.continuousAutoFocus) {
                    videoDevice.focusMode = .continuousAutoFocus
                }
                if videoDevice.isExposureModeSupported(.continuousAutoExposure) {
                    videoDevice.exposureMode = .continuousAutoExposure
                }
                if videoDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    videoDevice.whiteBalanceMode = .continuousAutoWhiteBalance
                }
                videoDevice.unlockForConfiguration()
                
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                if session.canAddInput(videoInput) {
                    session.addInput(videoInput)
                } else {
                    print("Cannot add video input")
                    return
                }
            } catch {
                print("Error setting up video input: \(error.localizedDescription)")
                return
            }
            
            // Set up audio input
            guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
                print("Failed to get audio device")
                return
            }
            
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                } else {
                    print("Cannot add audio input")
                }
            } catch {
                print("Error setting up audio input: \(error.localizedDescription)")
            }
            
            // Set up video output
            let output = AVCaptureMovieFileOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                
                // Configure video orientation
                if let connection = output.connection(with: .video) {
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                    if connection.isVideoStabilizationSupported {
                        connection.preferredVideoStabilizationMode = .auto
                    }
                }
            } else {
                print("Cannot add video output")
                return
            }
            
            session.commitConfiguration()
            
            // Create and configure preview layer
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.connection?.videoOrientation = .portrait
            
            // Update UI elements on main thread
            DispatchQueue.main.async {
                self.captureSession = session
                self.videoOutput = output
                self.previewLayer = previewLayer
                self.currentDevice = videoDevice
                
                // Start the session on camera queue
                cameraQueue.async {
                    session.startRunning()
                }
            }
        }
    }
    
    public func startRecording() {
        guard let output = videoOutput else { return }
        
        // Ensure we're not already recording
        guard !isRecording else { return }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        // Start recording
        output.startRecording(to: tempURL, recordingDelegate: self)
        
        DispatchQueue.main.async {
            self.isRecording = true
        }
    }
    
    public func stopRecording() {
        guard isRecording else { return }
        videoOutput?.stopRecording()
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    public func switchCamera() {
        let cameraQueue = DispatchQueue(label: "com.scrolllocal.camera.switch")
        cameraQueue.async { [weak self] in
            guard let self = self,
                  let session = self.captureSession,
                  let currentDevice = self.currentDevice else { return }
            
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
            
            DispatchQueue.main.async {
                self.currentDevice = newDevice
            }
        }
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
