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
            self.layer.insertSublayer(previewLayer, atIndex: 0)
        }
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        self.previewLayer?.frame = self.bounds
    }
}

public class ImageCaptureSession: NSObject {
    var session = AVCaptureSession()
    var previewLayer : AVCaptureVideoPreviewLayer
    var stillImageOutput : AVCaptureStillImageOutput

    public init(position:AVCaptureDevicePosition, previewView:PreviewView)
    {
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSessionPresetPhoto
        var device = self.dynamicType.createCameraInput(position:position)
        var input: AnyObject! = AVCaptureDeviceInput.deviceInputWithDevice(device, error: nil)
        if  (input == nil)
        {
            print("No Input");
        }
        self.session.addInput(input as! AVCaptureInput);
        var output = AVCaptureVideoDataOutput()
        self.session.addOutput(output)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey:kCVPixelFormatType_32BGRA]
        previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        previewLayer.frame = previewView.bounds
        previewView.previewLayer = previewLayer
        
        stillImageOutput = AVCaptureStillImageOutput()
        stillImageOutput.outputSettings = [AVVideoCodecKey:AVVideoCodecJPEG];
        session.addOutput(stillImageOutput);
        
        session.commitConfiguration()
        
        var connection = stillImageOutput.connectionWithMediaType(AVMediaTypeVideo)
        connection.videoOrientation = .Portrait
    }
    
    public func start()
    {
        session.startRunning()
    }
    
    public func stop()
    {
        session.stopRunning()
    }
    
    public func switchCameras()
    {
        var currentCameraInput = session.inputs[0] as! AVCaptureDeviceInput;
        var newCamera : AVCaptureDevice?
        if (currentCameraInput.device.position == .Back)
        {
            newCamera = self.dynamicType.createCameraInput(position: .Front)
        }
        else
        {
            newCamera = self.dynamicType.createCameraInput(position: .Back)
        }
        
        if let newCamera = newCamera
        {
            session.beginConfiguration()
            let newVideoInput = AVCaptureDeviceInput(device: newCamera, error: nil)
            session.removeInput(currentCameraInput)
            session.addInput(newVideoInput);
            session.commitConfiguration()
        }
    }
    
    private class func createCameraInput(#position : AVCaptureDevicePosition) -> AVCaptureDevice?
    {
        var devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as! [AVCaptureDevice]
        for device in devices
        {
            if (device.position == position)
            {
                return device
            }
        }
        return nil
    }
    
    public class func hasFrontCamera() -> Bool
    {
        let camera = self.createCameraInput(position: .Front)
        return (camera != nil)
    }
    
    public class func hasBackCamera() -> Bool
    {
        let camera = self.createCameraInput(position: .Back)
        return (camera != nil)
    }
    
    public func captureImage(completion:((image:UIImage?, error:NSError?) -> Void))
    {
        var videoConnection : AVCaptureConnection?
        var isFrontCamera = true
        for connection in stillImageOutput.connections as! [AVCaptureConnection]
        {
            for port in connection.inputPorts as! [AVCaptureInputPort]
            {
                if (port.mediaType == AVMediaTypeVideo)
                {
                    videoConnection = connection
                    var deviceInput = port.input as! AVCaptureDeviceInput
                    isFrontCamera = (deviceInput.device.position == .Front)
                    break
                }
            }
            if ((videoConnection) != nil)
            {
                break
            }
        }
        
        stillImageOutput.captureStillImageAsynchronouslyFromConnection(videoConnection, completionHandler: { (sampleBuffer, error) -> Void in
            if (error == nil)
            {
                var imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
                var image = UIImage(data: imageData)
                if (isFrontCamera)
                {
                    let scale = image?.scale
                    image = UIImage(CGImage: image?.CGImage, scale: scale!, orientation: .LeftMirrored)
                }
                
                completion(image: image, error: nil)
            }
            else
            {
                completion(image: nil, error: error)
            }
            return
        })
    }
    
    public class func checkAndRequestCameraPermissions(completion:(granted:Bool) -> Void)
    {
        /* Auth status request can be slow so this code is added so we can check
           a local variable instead of asking the device. It is implemented as a 
           struct because at the time of writing there were no static variables
           in functions. It is okay to do it like this because changing the 
           permission will terminate the app.
        */
        struct Holder {
            static var authStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
        }
        
        switch (Holder.authStatus)
            {
        case .Authorized, .Restricted:
            dispatch_async(dispatch_get_main_queue()) { completion(granted: true) }
        case .Denied:
            dispatch_async(dispatch_get_main_queue()) { completion(granted: false) }
        case .NotDetermined:
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { (granted) -> Void in
                if (granted)
                {
                    Holder.authStatus = .Authorized
                }
                else
                {
                    Holder.authStatus = .Denied
                }
                dispatch_async(dispatch_get_main_queue()) { completion(granted: granted) }
            })
        }
    }

}
