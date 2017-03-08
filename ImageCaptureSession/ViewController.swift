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
            cameraPosition = .front
        }
        else if (ImageCaptureSession.hasBackCamera()) {
            cameraPosition = .back
        }
        else {
            cameraPosition = .unspecified
            assertionFailure("Device needs to have a camera for this demo")
        }
        
        captureSession = ImageCaptureSession(position: cameraPosition, previewView: previewView)
        captureSession?.start()
    }
    
    @IBAction func takePhotoPressed(_ sender:AnyObject) {
        captureSession?.captureImage({ (image, error) -> Void in
            if (error == nil) {
                if let imageVC = self.storyboard?.instantiateViewController(withIdentifier: "ImageViewController") as? ImageViewController {
                    imageVC.image = image
                    self.present(imageVC, animated: true, completion: nil)
                }
                return
            }
            let alertController = UIAlertController(title: "Oh no!", message: "Failed to take a photo.", preferredStyle: .alert)
            self.present(alertController, animated: true, completion: nil)
        })
    }
    
    @IBAction func switchCamerasPressed(_ sender:AnyObject) {
        let stillFrame = previewView.snapshotView(afterScreenUpdates: false)
        stillFrame?.frame = previewView.frame
        view.insertSubview(stillFrame!, aboveSubview: previewView)
        UIView.animate(withDuration: 0.05,
            animations: {
                self.captureSession?.previewLayer.opacity = 0
            }, completion: { (finished) in
                self.captureSession?.switchCameras()
                UIView.animate(withDuration: 0.05,
                    animations: {
                        self.captureSession?.previewLayer.opacity = 1
                    }, completion: { (finished) in
                        stillFrame?.removeFromSuperview()
                })
        })
    }

}
