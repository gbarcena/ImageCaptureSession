//
//  ImageCaptureSession.swift
//
//  Created by Gustavo Barcena on 9/22/14.
//

import UIKit
import AVFoundation

// TODO: Fix issue with final image going outside preview bounds
public class PreviewView : UIView {
    var previewLayer : AVCaptureVideoPreviewLayer? {
        didSet {
            oldValue?.removeFromSuperlayer()
            if let previewLayer = previewLayer {
                self.layer.insertSublayer(previewLayer, atIndex: 0)
            }
        }
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        self.previewLayer?.frame = self.bounds
    }
}

public class ImageCaptureSession: NSObject {
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
        
        let connection = stillImageOutput.connectionWithMediaType(AVMediaTypeVideo)
        connection.videoOrientation = .Portrait
    }
    
    public func start() {
        session.startRunning()
    }
    
    public func stop() {
        session.stopRunning()
    }
    
    public func switchCameras() {
        let currentCameraInput = session.inputs[0] as! AVCaptureDeviceInput
        var newCamera : AVCaptureDevice?
        if (currentCameraInput.device.position == .Back) {
            newCamera = ImageCaptureSession.createCameraInput(position: .Front)
        }
        else {
            newCamera = ImageCaptureSession.createCameraInput(position: .Back)
        }
        
        if let newCamera = newCamera {
            session.beginConfiguration()
            let newVideoInput = try? AVCaptureDeviceInput(device: newCamera)
            session.removeInput(currentCameraInput)
            session.addInput(newVideoInput);
            session.commitConfiguration()
        }
    }
    
    class private func createCameraInput(position position: AVCaptureDevicePosition) -> AVCaptureDevice? {
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as! [AVCaptureDevice]
        for device in devices {
            if (device.position == position) {
                return device
            }
        }
        return nil
    }
    
    public class func hasFrontCamera() -> Bool {
        let camera = self.createCameraInput(position: .Front)
        return (camera != nil)
    }
    
    public class func hasBackCamera() -> Bool {
        let camera = self.createCameraInput(position: .Back)
        return (camera != nil)
    }
    
    public func captureImage(completion:((image:UIImage?, error:NSError?) -> Void)) {
        var videoConnection: AVCaptureConnection?
        var isFrontCamera = true
        for connection in stillImageOutput.connections as! [AVCaptureConnection] {
            for port in connection.inputPorts as! [AVCaptureInputPort] {
                if port.mediaType == AVMediaTypeVideo {
                    videoConnection = connection
                    let deviceInput = port.input as! AVCaptureDeviceInput
                    isFrontCamera = (deviceInput.device.position == .Front)
                    break
                }
            }
            
            if videoConnection != nil {
                break
            }
        }
        
        stillImageOutput.captureStillImageAsynchronouslyFromConnection(videoConnection, completionHandler: { (sampleBuffer, error) -> Void in
            if error == nil {
                let outputRect = self.previewLayer.metadataOutputRectOfInterestForRect(self.previewLayer.bounds)
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
                var image = UIImage(data: imageData)
                if let cleanUpImage = image {
                    image = self.dynamicType.cleanUpImage(cleanUpImage, mirrorFlipImage: isFrontCamera, cropRect: outputRect)
                }

                completion(image: image, error: nil)
            }
            else {
                completion(image: nil, error: error)
            }
            return
        })
    }
    
    private class func cleanUpImage(var image:UIImage, mirrorFlipImage:Bool, cropRect:CGRect) -> UIImage {
        // When using the front fracing camera, instead of seeing the
        // original image in the final image we see it flipped so this
        // flips it back
        if (mirrorFlipImage) {
            let scale = image.scale
            image = UIImage(CGImage: image.CGImage!, scale: scale, orientation: .LeftMirrored)
        }
        
        // When the image is taken it is the full bounds of the camera.
        // So this code crops out what is seen in the preview layer rect
        //http://stackoverflow.com/questions/15951746/how-to-crop-an-image-from-avcapture-to-a-rect-seen-on-the-display
        let outputRect = cropRect
        let cgImage = image.CGImage
        let width = CGFloat(CGImageGetWidth(cgImage))
        let height = CGFloat(CGImageGetHeight(cgImage))
        
        let cropRect = CGRect(x: outputRect.origin.x * width,
            y: outputRect.origin.y * height,
            width: outputRect.size.width * width,
            height: outputRect.size.height * height)
        
        let croppedCGImage = CGImageCreateWithImageInRect(cgImage, cropRect)
        image = UIImage(CGImage: croppedCGImage!, scale: 1, orientation: image.imageOrientation)
        
        // Remove all orientation information
        UIGraphicsBeginImageContext(image.size)
        image.drawAtPoint(CGPointZero)
        if let graphicsImage = UIGraphicsGetImageFromCurrentImageContext() {
            image = graphicsImage
        }
        UIGraphicsEndImageContext();
        
        return image
    }
    
    public class func checkAndRequestCameraPermissions(completion: (granted:Bool) -> Void) {
        /* Auth status request can be slow so this code is added so we can check
           a local variable instead of asking the device. It is implemented as a
           struct because at the time of writing there were no static variables
           in functions. It is okay to do it like this because changing the 
           permission will terminate the app.
        */
        struct Holder {
            static var authStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
        }
        
        switch (Holder.authStatus) {
        case .Authorized, .Restricted:
            dispatch_async(dispatch_get_main_queue()) { completion(granted: true) }
        case .Denied:
            dispatch_async(dispatch_get_main_queue()) { completion(granted: false) }
        case .NotDetermined:
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { (granted) -> Void in
                if (granted) {
                    Holder.authStatus = .Authorized
                }
                else {
                    Holder.authStatus = .Denied
                }
                dispatch_async(dispatch_get_main_queue()) { completion(granted: granted) }
            })
        }
    }

}
