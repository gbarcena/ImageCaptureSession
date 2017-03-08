//
//  ImageCaptureSession.swift
//
//  Created by Gustavo Barcena on 9/22/14.
//

import UIKit
import AVFoundation

// TODO: Fix issue with final image going outside preview bounds
open class PreviewView : UIView {
    var previewLayer : AVCaptureVideoPreviewLayer? {
        didSet {
            oldValue?.removeFromSuperlayer()
            if let previewLayer = previewLayer {
                self.layer.insertSublayer(previewLayer, at: 0)
            }
        }
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        self.previewLayer?.frame = self.bounds
    }
}

open class ImageCaptureSession: NSObject {
    var session = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer
    var stillImageOutput: AVCaptureStillImageOutput
    
    public init(position:AVCaptureDevicePosition, previewView:PreviewView) {
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSessionPresetPhoto
        let device = ImageCaptureSession.createCameraInput(position:position)
        let input = try? AVCaptureDeviceInput(device: device)
        if input == nil {
            print("No input")
        }
        self.session.addInput(input);
        let output = AVCaptureVideoDataOutput()
        self.session.addOutput(output)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as NSString : Int(kCVPixelFormatType_32BGRA)]
        previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        previewLayer.frame = previewView.bounds
        previewView.previewLayer = previewLayer
        
        stillImageOutput = AVCaptureStillImageOutput()
        stillImageOutput.outputSettings = [AVVideoCodecKey:AVVideoCodecJPEG];
        session.addOutput(stillImageOutput);
        
        session.commitConfiguration()
        
        let connection = stillImageOutput.connection(withMediaType: AVMediaTypeVideo)
        connection?.videoOrientation = .portrait
    }
    
    open func start() {
        session.startRunning()
    }
    
    open func stop() {
        session.stopRunning()
    }
    
    open func switchCameras() {
        let currentCameraInput = session.inputs[0] as! AVCaptureDeviceInput
        var newCamera : AVCaptureDevice?
        if (currentCameraInput.device.position == .back) {
            newCamera = ImageCaptureSession.createCameraInput(position: .front)
        }
        else {
            newCamera = ImageCaptureSession.createCameraInput(position: .back)
        }
        
        if let newCamera = newCamera {
            session.beginConfiguration()
            let newVideoInput = try? AVCaptureDeviceInput(device: newCamera)
            session.removeInput(currentCameraInput)
            session.addInput(newVideoInput);
            session.commitConfiguration()
        }
    }
    
    class fileprivate func createCameraInput(position: AVCaptureDevicePosition) -> AVCaptureDevice? {
        let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as! [AVCaptureDevice]
        for device in devices {
            if (device.position == position) {
                return device
            }
        }
        return nil
    }
    
    open class func hasFrontCamera() -> Bool {
        let camera = self.createCameraInput(position: .front)
        return (camera != nil)
    }
    
    open class func hasBackCamera() -> Bool {
        let camera = self.createCameraInput(position: .back)
        return (camera != nil)
    }
    
    open func captureImage(_ completion:@escaping ((_ image:UIImage?, _ error:NSError?) -> Void)) {
        var videoConnection: AVCaptureConnection?
        var isFrontCamera = true
        for connection in stillImageOutput.connections as! [AVCaptureConnection] {
            for port in connection.inputPorts as! [AVCaptureInputPort] {
                if port.mediaType == AVMediaTypeVideo {
                    videoConnection = connection
                    let deviceInput = port.input as! AVCaptureDeviceInput
                    isFrontCamera = (deviceInput.device.position == .front)
                    break
                }
            }
            
            if videoConnection != nil {
                break
            }
        }
        
        stillImageOutput.captureStillImageAsynchronously(from: videoConnection, completionHandler: { (sampleBuffer, error) -> Void in
            if error == nil {
                let outputRect = self.previewLayer.metadataOutputRectOfInterest(for: self.previewLayer.bounds)
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
                var image = UIImage(data: imageData!)
                if let cleanUpImage = image {
                    image = type(of: self).cleanUpImage(cleanUpImage, mirrorFlipImage: isFrontCamera, cropRect: outputRect)
                }

                completion(image, nil)
            }
            else {
                completion(nil, error as NSError?)
            }
            return
        })
    }
    
    private class func cleanUpImage(_ image:UIImage, mirrorFlipImage:Bool, cropRect:CGRect) -> UIImage {
        var image = image
        // When using the front fracing camera, instead of seeing the
        // original image in the final image we see it flipped so this
        // flips it back
        if (mirrorFlipImage) {
            let scale = image.scale
            image = UIImage(cgImage: image.cgImage!, scale: scale, orientation: .leftMirrored)
        }
        
        // When the image is taken it is the full bounds of the camera.
        // So this code crops out what is seen in the preview layer rect
        //http://stackoverflow.com/questions/15951746/how-to-crop-an-image-from-avcapture-to-a-rect-seen-on-the-display
        let outputRect = cropRect
        let cgImage = image.cgImage
        let width = CGFloat((cgImage?.width)!)
        let height = CGFloat((cgImage?.height)!)
        
        let cropRect = CGRect(x: outputRect.origin.x * width,
            y: outputRect.origin.y * height,
            width: outputRect.size.width * width,
            height: outputRect.size.height * height)
        
        let croppedCGImage = cgImage?.cropping(to: cropRect)
        image = UIImage(cgImage: croppedCGImage!, scale: 1, orientation: image.imageOrientation)
        
        // Remove all orientation information
        UIGraphicsBeginImageContext(image.size)
        image.draw(at: CGPoint.zero)
        if let graphicsImage = UIGraphicsGetImageFromCurrentImageContext() {
            image = graphicsImage
        }
        UIGraphicsEndImageContext();
        
        return image
    }
    
    open class func checkAndRequestCameraPermissions(_ completion: @escaping (_ granted:Bool) -> Void) {
        /* Auth status request can be slow so this code is added so we can check
           a local variable instead of asking the device. It is implemented as a
           struct because at the time of writing there were no static variables
           in functions. It is okay to do it like this because changing the 
           permission will terminate the app.
        */
        struct Holder {
            static var authStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        }
        
        switch (Holder.authStatus) {
        case .authorized, .restricted:
            DispatchQueue.main.async { completion(true) }
        case .denied:
            DispatchQueue.main.async { completion(false) }
        case .notDetermined:
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { (granted) -> Void in
                if (granted) {
                    Holder.authStatus = .authorized
                }
                else {
                    Holder.authStatus = .denied
                }
                DispatchQueue.main.async { completion(granted) }
            })
        }
    }

}
