import Foundation
import AVFoundation
import CoreLocation
import UIKit

public class CameraViewModel: NSObject, ObservableObject {
    @Published public var isRecording = false
    @Published public var recordedVideoURL: URL?
    @Published public var showPermissionDenied = false
    
    private(set) var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var currentDevice: AVCaptureDevice?
    private let locationManager = CLLocationManager()
    
    // Dedicated serial queue for camera operations
    private let cameraQueue = DispatchQueue(label: "com.scrolllocal.camera.session", qos: .userInteractive)
    
    public override init() {
        super.init()
        locationManager.delegate = self
        
        // Initialize the session right away
        captureSession = AVCaptureSession()
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
        cameraQueue.async { [weak self] in
            self?.setupCameraInternal()
        }
    }
    
    private func setupCameraInternal() {
        guard let session = captureSession else { return }
        
        // Stop any existing session
        if session.isRunning {
            session.stopRunning()
        }
        
        session.sessionPreset = .high
        
        // Configure the session
        session.beginConfiguration()
        
        // Configure inputs and outputs
        guard configureVideoInput(for: session),
              configureAudioInput(for: session),
              configureVideoOutput(for: session) else {
            session.commitConfiguration()
            return
        }
        
        // Commit configuration
        session.commitConfiguration()
        
        // Start the session
        if !session.isRunning {
            cameraQueue.async {
                session.startRunning()
            }
        }
    }
    
    public func stopSession() {
        cameraQueue.async { [weak self] in
            guard let session = self?.captureSession, session.isRunning else { return }
            session.stopRunning()
        }
    }
    
    public func startSession() {
        cameraQueue.async { [weak self] in
            guard let session = self?.captureSession, !session.isRunning else { return }
            session.startRunning()
        }
    }
    
    private func configureVideoInput(for session: AVCaptureSession) -> Bool {
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Failed to get video device")
            return false
        }
        
        do {
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
                DispatchQueue.main.async { [weak self] in
                    self?.currentDevice = videoDevice
                }
                return true
            }
        } catch {
            print("Error setting up video input: \(error.localizedDescription)")
        }
        return false
    }
    
    private func configureAudioInput(for session: AVCaptureSession) -> Bool {
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            print("Failed to get audio device")
            return false
        }
        
        do {
            let audioInput = try AVCaptureDeviceInput(device: audioDevice)
            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
                return true
            }
        } catch {
            print("Error setting up audio input: \(error.localizedDescription)")
        }
        return false
    }
    
    private func configureVideoOutput(for session: AVCaptureSession) -> Bool {
        let output = AVCaptureMovieFileOutput()
        guard session.canAddOutput(output) else {
            print("Cannot add video output")
            return false
        }
        
        session.addOutput(output)
        if let connection = output.connection(with: .video) {
            if #available(iOS 17.0, *) {
                connection.videoRotationAngle = 0
            } else if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.videoOutput = output
        }
        return true
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
        cameraQueue.async { [weak self] in
            guard let self = self,
                  let session = self.captureSession,
                  let currentDevice = self.currentDevice else { return }
            
            let newPosition: AVCaptureDevice.Position = currentDevice.position == .back ? .front : .back
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                        for: .video,
                                                        position: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else { return }
            
            session.beginConfiguration()
            if let input = session.inputs.first as? AVCaptureDeviceInput {
                session.removeInput(input)
            }
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                DispatchQueue.main.async {
                    self.currentDevice = newDevice
                }
            }
            session.commitConfiguration()
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
