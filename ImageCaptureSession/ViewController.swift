//
//  ViewController.swift
//  ImageCaptureSession
//
//  Created by Gustavo Barcena on 5/27/15.
//  Copyright (c) 2015 Gustavo Barcena. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    @IBOutlet weak var previewView : PreviewView!
    var captureSession : ImageCaptureSession?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCameraView()
    }
    
    deinit {
        captureSession?.stop()
    }
    
    func setupCameraView() {
        let cameraPosition : AVCaptureDevicePosition
        if (ImageCaptureSession.hasFrontCamera()) {
            cameraPosition = .Front
        }
        else if (ImageCaptureSession.hasBackCamera()) {
            cameraPosition = .Back
        }
        else {
            cameraPosition = .Unspecified
            assertionFailure("Device needs to have a camera for this demo")
        }
        
        captureSession = ImageCaptureSession(position: cameraPosition, previewView: previewView)
        captureSession?.start()
    }
    
    @IBAction func takePhotoPressed(sender:AnyObject) {
        captureSession?.captureImage({ (image, error) -> Void in
            if (error == nil) {
                if let imageVC = self.storyboard?.instantiateViewControllerWithIdentifier("ImageViewController") as? ImageViewController {
                    imageVC.image = image
                    self.presentViewController(imageVC, animated: true, completion: nil)
                }
                return
            }
            let alertController = UIAlertController(title: "Oh no!", message: "Failed to take a photo.", preferredStyle: .Alert)
            self.presentViewController(alertController, animated: true, completion: nil)
        })
    }
    
    @IBAction func switchCamerasPressed(sender:AnyObject) {
        let stillFrame = previewView.snapshotViewAfterScreenUpdates(false)
        stillFrame.frame = previewView.frame
        view.insertSubview(stillFrame, aboveSubview: previewView)
        UIView.animateWithDuration(0.05,
            animations: {
                self.captureSession?.previewLayer.opacity = 0
            }, completion: { (finished) in
                self.captureSession?.switchCameras()
                UIView.animateWithDuration(0.05,
                    animations: {
                        self.captureSession?.previewLayer.opacity = 1
                    }, completion: { (finished) in
                        stillFrame.removeFromSuperview()
                })
        })
    }

}