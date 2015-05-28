//
//  ImageViewController.swift
//  ImageCaptureSession
//
//  Created by Gustavo Barcena on 5/27/15.
//  Copyright (c) 2015 Gustavo Barcena. All rights reserved.
//

import UIKit

class ImageViewController: UIViewController {
    @IBOutlet weak var imageView : UIImageView!
    
    var image : UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.image = image
    }
    
    @IBAction func dismissViewPressed() {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
}
