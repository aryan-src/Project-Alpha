import Foundation
import AVFoundation
import CoreMedia
import AppKit

public protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer)
}

public class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    public static let shared = CameraManager()
    
    public weak var delegate: CameraManagerDelegate?
    
    public private(set) var captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.handtracker.sessionQueue")
    private let videoOutputQueue = DispatchQueue(label: "com.handtracker.videoOutputQueue", qos: .userInteractive)
    
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let videoDataOutput = AVCaptureVideoDataOutput()
    
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var availableDevices: [AVCaptureDevice] = []
    @Published public private(set) var currentDevice: AVCaptureDevice?
    
    public override init() {
        super.init()
        discoverDevices()
    }
    
    public func discoverDevices() {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(macOS 14.0, *) {
            deviceTypes.append(.external)
        } else {
            deviceTypes.append(.externalUnknown)
        }
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )
        self.availableDevices = discoverySession.devices
        if currentDevice == nil {
            currentDevice = AVCaptureDevice.default(for: .video)
        }
    }
    
    public func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.setupSession()
                self.captureSession.startRunning()
                DispatchQueue.main.async {
                    self.isRunning = self.captureSession.isRunning
                }
            }
        }
    }
    
    public func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                DispatchQueue.main.async {
                    self.isRunning = false
                }
            }
        }
    }
    
    public func switchCamera(to device: AVCaptureDevice) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            
            if let currentInput = self.videoDeviceInput {
                self.captureSession.removeInput(currentInput)
            }
            
            do {
                let newInput = try AVCaptureDeviceInput(device: device)
                if self.captureSession.canAddInput(newInput) {
                    self.captureSession.addInput(newInput)
                    self.videoDeviceInput = newInput
                    self.currentDevice = device
                }
            } catch {
                print("Error switching camera: \(error)")
            }
            
            self.captureSession.commitConfiguration()
        }
    }
    
    private func setupSession() {
        captureSession.beginConfiguration()
        
        // Optimize for speed and hand detection
        if captureSession.canSetSessionPreset(.hd1280x720) {
            captureSession.sessionPreset = .hd1280x720
        } else if captureSession.canSetSessionPreset(.vga640x480) {
            captureSession.sessionPreset = .vga640x480
        }
        
        guard let device = currentDevice ?? AVCaptureDevice.default(for: .video) else {
            captureSession.commitConfiguration()
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                self.videoDeviceInput = input
            }
        } catch {
            print("Failed to create camera input: \(error)")
            captureSession.commitConfiguration()
            return
        }
        
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoDataOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
        
        captureSession.commitConfiguration()
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        delegate?.cameraManager(self, didOutput: sampleBuffer)
    }
}
