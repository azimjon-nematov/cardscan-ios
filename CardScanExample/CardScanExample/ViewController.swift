//
//  ViewController.swift
//  CardScan
//
//  Created by Sam King on 10/15/2018.
//  Copyright (c) 2018 Sam King. All rights reserved.
//
import AVFoundation
import UIKit
import CardScan

class ViewController: UIViewController {
    @IBOutlet weak var cameraImage: UIImageView!
    @IBOutlet weak var scanCardButton: UIButton!
    
    let testImages = [UIImage(imageLiteralResourceName: "synthetic_card_full")]
    var currentTestImages: [CGImage]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.cameraImage.image = UIImage(named: "camera")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !ScanViewController.isCompatible() {
            self.scanCardButton.isHidden = true
        }
    }
    @IBAction func scanWithMirPress() {
        guard let vc = ScanViewController.createViewController(withDelegate: self) else {
            print("scan view controller not supported on this hardware")
            return
        }
        CreditCardUtils.prefixesRegional = ["2200", "2201", "2202", "2203", "2204"]
        
        self.present(vc, animated: true)
    }
    
    @IBAction func scanQrCodePress() {
        let vc = SimpleScanViewController.createViewController()
        vc.delegate = self
        self.present(vc, animated: true)
    }
    
    @IBAction func scanCardPress() {
        guard let vc = ScanViewController.createViewController(withDelegate: self) else {
            print("scan view controller not supported on this hardware")
            return
        }
        
        self.present(vc, animated: true)
    }
    
    @IBAction func scanCardOldDevicePress() {
        let config = ScanConfiguration()
        config.runOnOldDevices = true
        guard let vc = ScanViewController.createViewController(withDelegate: self, configuration: config) else {
            print("scan view controller not supported on this hardware")
            return
        }
        
        vc.allowSkip = true
        self.present(vc, animated: true)
    }
    
    @IBAction func scanCardCustomStringsPress() {
        guard let vc = ScanViewController.createViewController(withDelegate: self) else {
            print("scan view controller not supported on this hardware")
            return
        }
        vc.allowSkip = true
        vc.stringDataSource = self
        
        vc.backButtonColor = UIColor.red
        vc.hideBackButtonImage = true
        vc.backButtonImageToTextDelta = 8.0
        
        vc.backButtonFont = UIFont(name: "Verdana", size: CGFloat(17.0))
        vc.scanCardFont = UIFont(name: "Chalkduster", size: CGFloat(24.0))
        vc.positionCardFont = UIFont(name: "Chalkduster", size: CGFloat(17.0))
        vc.skipButtonFont = UIFont(name: "Chalkduster", size: CGFloat(17.0))
        
        vc.cornerColor = UIColor.blue
        vc.torchButtonImage = UIImage(named: "camera")

        vc.torchButtonSize = CGSize(width: 44, height: 44)
        
        self.present(vc, animated: true)
    }
    
    
    @IBAction func scanWithTimeoutPress() {
        guard let vc = ScanViewController.createViewController(withDelegate: self) else {
            print("scan view controller not supported on this hardware")
            return
        }
        vc.allowSkip = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) {
            vc.cancel(callDelegate: true)
//            let scanStats = vc.getScanStats()
//            let fps = Double(scanStats.scans) / scanStats.duration()
//            print("fps -> \(fps)")
        }
        self.present(vc, animated: true)
    }
    
    @IBAction func scanAndShowImagePress() {
        let vc = SimpleScanViewController.createViewController()
        vc.includeCardImage = true
        vc.delegate = self

        self.present(vc, animated: true)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @IBAction func customVideoPress() {
        guard let vc = ScanViewController.createViewController(withDelegate: self) else {
            print("scan view controller not supported on this hardware")
            return
        }
        
        self.currentTestImages = self.testImages.compactMap { $0.cgImage }
        vc.testingImageDataSource = self
        vc.showDebugImageView = true
        self.present(vc, animated: true)
    }
    
    @IBAction func scanWithStatsPress() {
        guard let vc = ScanViewController.createViewController(withDelegate: self) else {
            print("scan view controller not supported on this hardware")
            return
        }
        
        self.present(vc, animated: true)
    }
}

extension ViewController: ScanDelegate {
   func userDidSkip(_ scanViewController: ScanViewController) {
        self.dismiss(animated: true)
    }
    
    func userDidCancel(_ scanViewController: ScanViewController) {
        self.dismiss(animated: true)
    }
    
    func userDidScanCard(_ scanViewController: ScanViewController, creditCard: CreditCard) {
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "results") as! ResultViewController
//        vc.scanStats = scanViewController.getScanStats()
        vc.number = creditCard.number
        vc.cardImage = creditCard.image
        vc.expiration = creditCard.expiryForDisplay()
        vc.name = creditCard.name
        
        self.dismiss(animated: true)
        self.present(vc, animated: true)
    }
}

@available(iOS 11.2, *)
extension ViewController: SimpleScanDelegate {
    
    func userDidCancelSimple(_ scanViewController: SimpleScanViewController) {
        self.dismiss(animated: true)
    }
    
    func userDidScanCardSimple(_ scanViewController: SimpleScanViewController, creditCard: CreditCard) {
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "results") as! ResultViewController
//        vc.scanStats = scanViewController.getScanStats()
        vc.number = creditCard.number
        vc.cardImage = creditCard.image
        vc.expiration = creditCard.expiryForDisplay()
        vc.name = creditCard.name
        
        self.dismiss(animated: true)
        self.present(vc, animated: true)
    }
}

extension ViewController: FullScanStringsDataSource {
    func scanCard() -> String { return "New Scan Card" }
    func positionCard() -> String { return "New Position Card" }
    func backButton() -> String { return "New Back" }
    func skipButton() -> String { return "New Skip" }
    func denyPermissionTitle() -> String { return "New Deny" }
    func denyPermissionMessage() -> String { return "New Deny Message" }
    func denyPermissionButton() -> String { return "GO" }
}

extension ViewController: TestingImageDataSource {
    func nextSquareAndFullImage() -> (CGImage, CGImage)? {
        if self.currentTestImages?.first == nil {
            self.currentTestImages = self.testImages.compactMap { $0.cgImage }
        }
        
        guard let fullCardImage = self.currentTestImages?.first else {
            print("could not get full size test image")
            return nil
        }
        
        let squareCropImage = fullCardImage
        let width = CGFloat(squareCropImage.width)
        let height = width
        let x = CGFloat(0)
        let y = CGFloat(squareCropImage.height) * 0.5 - height * 0.5
        
        guard let squareCardImage = squareCropImage.cropping(to: CGRect(x: x, y: y, width: width, height: height)) else {
            print("could not crop test image")
            return nil
        }
    
        self.currentTestImages = self.currentTestImages?.dropFirst().map { $0 }
        return (squareCardImage, fullCardImage)
    }
}
