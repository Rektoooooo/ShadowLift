//
//  CameraViewModel.swift
//  ShadowLift
//
//  Created by Claude Code on 27.10.2025.
//

import AVFoundation
import SwiftUI

class CameraViewModel: NSObject, ObservableObject {
    @Published var isCameraAuthorized = false
    let session = AVCaptureSession()
    let output = AVCapturePhotoOutput()
    var preview: AVCaptureVideoPreviewLayer?

    private var currentCamera: AVCaptureDevice.Position = .back
    private var photoCompletion: ((UIImage?) -> Void)?

    override init() {
        super.init()
        print("🎥 CameraViewModel init")
    }

    deinit {
        print("🎥 CameraViewModel deinit - stopping session")
        // Stop session synchronously to prevent crashes
        if session.isRunning {
            session.stopRunning()
        }
        preview?.removeFromSuperlayer()
        preview = nil
    }

    func stopCamera() {
        print("🎥 Stopping camera session")
        if session.isRunning {
            session.stopRunning()
        }
    }

    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCameraAuthorized = true
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isCameraAuthorized = granted
                    if granted {
                        self?.setupCamera()
                    }
                }
            }
        default:
            isCameraAuthorized = false
        }
    }

    func setupCamera() {
        // Prevent multiple setups
        if session.isRunning {
            print("⚠️ Camera already running, skipping setup")
            return
        }

        session.beginConfiguration()

        // Remove existing inputs
        session.inputs.forEach { session.removeInput($0) }

        // Remove existing outputs
        session.outputs.forEach { session.removeOutput($0) }

        // Add camera input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCamera) else {
            print("❌ Camera not available")
            session.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            session.commitConfiguration()

            // Start session
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self, !self.session.isRunning else { return }
                print("🎥 Starting camera session")
                self.session.startRunning()
            }

        } catch {
            print("❌ Camera setup failed: \(error)")
            session.commitConfiguration()
        }
    }

    func flipCamera() {
        // Stop current session first
        if session.isRunning {
            session.stopRunning()
        }
        currentCamera = currentCamera == .back ? .front : .back
        setupCamera()
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        photoCompletion = completion

        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("❌ Photo capture error: \(error)")
            photoCompletion?(nil)
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              var image = UIImage(data: imageData) else {
            photoCompletion?(nil)
            return
        }

        // Flip front camera images horizontally
        if currentCamera == .front {
            image = flipImageHorizontally(image)
        }

        photoCompletion?(image)
    }

    private func flipImageHorizontally(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        return UIImage(
            cgImage: cgImage,
            scale: image.scale,
            orientation: .leftMirrored
        )
    }
}
