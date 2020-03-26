import SwiftUI
import AVFoundation

struct ContentView: View {
    var captureSession: AVCaptureSession?
    var photoOutput: AVCapturePhotoOutput?
    var device: AVCaptureDevice?
    var processor = CaptureProcessor()
    
    var body: some View {
        VStack {
            Spacer()
            Button(action: { self.capture() }) {
                Text("Capture")
            }
            Spacer()
        }
    }
    
    init() {
        guard let captureDevice = AVCaptureDevice.default(
            .builtInTelephotoCamera,
            for: AVMediaType.video,
            position: .back
        ) else {
            fatalError("No video device found")
        }
        device = captureDevice;
        do {
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            
            captureSession = AVCaptureSession()
            captureSession?.sessionPreset = .photo
            captureSession?.addInput(deviceInput)
            
            photoOutput = AVCapturePhotoOutput()
            photoOutput?.isHighResolutionCaptureEnabled = true

            captureSession?.addOutput(photoOutput!)
            captureSession?.startRunning()
        } catch {
            print(error)
            return
        }
    }
    
    func capture() {
        guard let device = self.device else { return }
        guard device.hasTorch else { return }
        
        guard let photoOutput = self.photoOutput else { return }
        guard let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first else { return }

        let photoSettings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
        photoSettings.isHighResolutionPhotoEnabled = true
        photoSettings.flashMode = .off
        
        do {
            try flash(device)
        } catch {
            print(error)
            return
        }
        photoOutput.capturePhoto(with: photoSettings, delegate: self.processor)
    }
    
    func flash(_ device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        try device.setTorchModeOn(level: 1.0)
        Thread.sleep(forTimeInterval: 0.05)
        device.torchMode = AVCaptureDevice.TorchMode.off
        device.unlockForConfiguration()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

class CaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else { print("Error capturing photo: \(error!)"); return }
        if photo.isRawPhoto {
            guard let pixelBuffer = photo.pixelBuffer else { return }
            let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
            guard pixelFormat == kCVPixelFormatType_14Bayer_RGGB else {
                print("Unexpected pixel format: \(pixelFormat)")
                return
            }
            
            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
            
            /* Data is Bayer 14-bit Little-Endian, packed in 16-bits, ordered R G R G... alternating with G B G B... */
            let buffer = unsafeBitCast(CVPixelBufferGetBaseAddress(pixelBuffer), to: UnsafeMutablePointer<UInt16>.self)
            
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            for col in 0...width {
                for row in 0...height {
                    let pixel = buffer[col * height + row]
                    // do something...
                }
            }
            print("done")
        }
    }
}
