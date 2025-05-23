//
//  ScanCardViewController.swift
//  ScanCardFramework
//
//  Created by Sam King on 10/11/18.
//  Copyright © 2018 Sam King. All rights reserved.
//
import AVKit
import UIKit


@available(iOS 11.2, *)
@objc public protocol ScanDelegate {
    @objc func userDidCancel(_ scanViewController: ScanViewController)
    @objc func userDidScanCard(_ scanViewController: ScanViewController, creditCard: CreditCard)
    @objc func userDidSkip(_ scanViewController: ScanViewController)
}

@available(iOS 11.2, *)
@objc public protocol ScanStringsDataSource {
    @objc func scanCard() -> String
    @objc func positionCard() -> String
    @objc func backButton() -> String
    @objc func skipButton() -> String
}

@available(iOS 11.2, *)
@objc public protocol CaptureOutputDelegate {
    func capture(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
}

// The FullScanStringsDataSource protocol defines all of the strings
// that the viewcontroller uses. As we add more strings we will update
// this protocol, which will require you to update your integration on
// an update that includes new strings.
//
// If you prefer to just set the main strings on the ScanViewController
// the ScanStringsDataSource protocol is stable and won't change, but
// might be incomplete.
@available(iOS 11.2, *)
@objc public protocol FullScanStringsDataSource: ScanStringsDataSource {
    @objc func denyPermissionTitle() -> String
    @objc func denyPermissionMessage() -> String
    @objc func denyPermissionButton() -> String
}

@objc public class CreditCard: NSObject {
    @objc public var number: String
    @objc public var expiryMonth: String?
    @objc public var expiryYear: String?
    @objc public var name: String?
    @objc public var image: UIImage?
    @objc public var cvv: String?
    @objc public var postalCode: String?
    
    public init(number: String) {
        self.number = number
    }
    
    @objc public func expiryForDisplay() -> String? {
        guard var month = self.expiryMonth, var year = self.expiryYear else {
            return nil
        }
        
        if month.count == 1 {
            month = "0" + month
        }
        
        if year.count == 4 {
            year = String(year.suffix(2))
        }
        
        return "\(month)/\(year)"
    }
}

@available(iOS 11.2, *)
@objc public class ScanViewController: ScanBaseViewController {
    
    public weak var scanDelegate: ScanDelegate?
    public weak var captureOutputDelegate: CaptureOutputDelegate?
    @objc public weak var stringDataSource: ScanStringsDataSource?
    @objc public var allowSkip = false
    public var torchLevel: Float? 
    public var navigationBarIsHidden = true
    @objc public var hideBackButtonImage = false
    @objc public var backButtonImage: UIImage?
    @objc public var backButtonColor: UIColor?
    @objc public var backButtonFont: UIFont?
    @objc public var scanCardFont: UIFont?
    @objc public var positionCardFont: UIFont?
    @objc public var skipButtonFont: UIFont?
    @objc public var backButtonImageToTextDelta: NSNumber?
    @objc public var torchButtonImage: UIImage?
    @objc public var cornerColor: UIColor?
    
    public var torchButtonSize: CGSize?
    var cornerBorderColor = UIColor.green.cgColor
    var denyPermissionTitle = "Need camera access"
    var denyPermissionMessage = "Please enable camera access in your settings to scan your card"
    var denyPermissionButtonText = "OK"
    
    var calledDelegate = false
    @objc var backgroundBlurEffectView: UIVisualEffectView?
    
    @objc static public func createViewController(withDelegate delegate: ScanDelegate? = nil) -> ScanViewController? {
        // use default config
        return self.createViewController(withDelegate: delegate, configuration: ScanConfiguration())
    }
    
    @objc static public func createViewController(withDelegate delegate: ScanDelegate? = nil, configuration: ScanConfiguration) -> ScanViewController? {
        
        if !self.isCompatible(configuration: configuration) {
            return nil
        }
        
        let viewController = ScanViewController()
        viewController.scanDelegate = delegate
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            // For the iPad you can use the full screen style but you have to select "requires full screen" in
            // the Info.plist to lock it in portrait mode. For iPads, we recommend using a formSheet, which
            // handles all orientations correctly.
            viewController.modalPresentationStyle = .formSheet
        } else {
            viewController.modalPresentationStyle = .fullScreen
        }
        
        return viewController
    }
    
    @objc func backTextPress() {
        self.backButtonPress("")
    }
    
    @objc func backButtonPress(_ sender: Any) {
        // Note: for the back button we may call the `userCancelled` delegate even if the
        // delegate has been called just as a safety precation to always provide the
        // user with a way to get out.
        self.cancelScan()
        self.calledDelegate = true
        self.scanDelegate?.userDidCancel(self)
    }
    
    @objc func skipButtonPress() {
        // Same for the skip button, like with the back button press we may call the
        // delegate function even if it's already been called
        self.cancelScan()
        self.calledDelegate = true
        self.scanDelegate?.userDidSkip(self)
    }

    @objc public func cancel(callDelegate: Bool) {
        if !self.calledDelegate {
            self.cancelScan()
            self.calledDelegate = true
        }
        
        if callDelegate {
            self.scanDelegate?.userDidCancel(self)
        }
    }
    
    public func setStrings() {
        guard let dataSource = self.stringDataSource else {
            return
        }
        
        self.mainView.scanCardLabel.text = dataSource.scanCard()
        self.mainView.positionCardLabel.text = dataSource.positionCard()
        self.mainView.skipButton.setTitle(dataSource.skipButton(), for: .normal)
        self.mainView.backButton.setTitle(dataSource.backButton(), for: .normal)
        
        guard let fullDataSource = dataSource as? FullScanStringsDataSource else {
            return
        }
        
        self.denyPermissionMessage = fullDataSource.denyPermissionMessage()
        self.denyPermissionTitle = fullDataSource.denyPermissionTitle()
        self.denyPermissionButtonText = fullDataSource.denyPermissionButton()
    }
    
    func setUiCustomization() {
        if self.hideBackButtonImage {
            self.mainView.backButtonImageButton.setImage(nil, for: .normal)
            // the image button is 8 from safe area and has a width of 32 the
            // label has a leading constraint of -11 so setting the width to
            // 19 sets the space from the safe region to 16
            self.mainView.backButtonWidthConstraint.constant = 19
        } else if let newImage = self.backButtonImage {
            self.mainView.backButtonImageButton.setImage(newImage, for: .normal)
        }
        
        if let color = self.backButtonColor {
            self.mainView.backButton.setTitleColor(color, for: .normal)
        }
        if let font = self.backButtonFont {
            self.mainView.backButton.titleLabel?.font = font
        }
        if let font = self.scanCardFont {
            self.mainView.scanCardLabel.font = font
        }
        if let font = self.positionCardFont {
            self.mainView.positionCardLabel.font = font
        }
        if let font = self.skipButtonFont {
            self.mainView.skipButton.titleLabel?.font = font
        }
        if let delta = self.backButtonImageToTextDelta.map({ CGFloat($0.floatValue) }) {
            self.mainView.backButtonImageToTextConstraint.constant += delta
        }
        if let image = self.torchButtonImage {
            self.mainView.torchButton.setImage(image, for: .normal)
        }
        if let color = self.cornerColor {
            self.cornerBorderColor = color.cgColor
        }
        if let size = self.torchButtonSize {
            self.mainView.torchButtonWidthConstraint.constant = size.width
            self.mainView.torchButtonHeightConstraint.constant = size.height
        }
        self.hideNavigationBar = self.navigationBarIsHidden
    }
    
    func showDenyAlert() {
        let alert = UIAlertController(title: self.denyPermissionTitle, message: self.denyPermissionMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: self.denyPermissionButtonText, style: .default, handler: { action in
            switch action.style{
            case .default:
                self.backButtonPress("")
                
            case .cancel:
                print("cancel")
                
            case .destructive:
                print("destructive")

            @unknown default:
                assertionFailure("UIAlertAction case not handled")
            }}))
        self.present(alert, animated: true, completion: nil)
    }
    
    override public func onCameraPermissionDenied(showedPrompt: Bool) {
        if !showedPrompt {
            self.showDenyAlert()
        } else {
            self.backButtonPress("")
        }
    }
    
    lazy var mainView = ScanView()
    public override func loadView() {
        view = mainView
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.mainView.backButton.addTarget(self, action: #selector(backTextPress), for: .touchUpInside)
        self.mainView.backButtonImageButton.addTarget(self, action: #selector(backButtonPress(_:)), for: .touchUpInside)
        self.mainView.torchButton.addTarget(self, action: #selector(toggleTorch(_:)), for: .touchUpInside)
        self.mainView.skipButton.addTarget(self, action: #selector(skipButtonPress), for: .touchUpInside)
        
        self.setStrings()
        self.setUiCustomization()
        self.calledDelegate = false
        
        if self.allowSkip {
            self.mainView.skipButton.isHidden = false
        } else {
            self.mainView.skipButton.isHidden = true
        }
        
        let debugImageView = self.showDebugImageView ? self.mainView.debugImageView : nil
        self.setupOnViewDidLoad(regionOfInterestLabel: self.mainView.regionOfInterestLabel, blurView: self.mainView.blurView, previewView: self.mainView.previewView, cornerView: self.mainView.cornerView, debugImageView: debugImageView, torchLevel: self.torchLevel)
        self.startCameraPreview()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        self.mainView.cornerView.layer.borderColor = self.cornerBorderColor
        self.addBackgroundObservers()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    override public func showCardNumber(_ number: String, expiry: String?) {
        // we're assuming that the image takes up the full width and that
        // video has the same aspect ratio of the screen
        DispatchQueue.main.async {
            self.mainView.cardNumberLabel.text = CreditCardUtils.formatCardNumber(cardNumber: number)
            if self.mainView.cardNumberLabel.isHidden {
                self.mainView.cardNumberLabel.fadeIn()
            }
            
            if let expiry = expiry {
                self.mainView.expiryLabel.text = expiry
                if self.mainView.expiryLabel.isHidden {
                    self.mainView.expiryLabel.fadeIn()
                }
            }
        }
    }
    
    public override func useCurrentFrameNumber(errorCorrectedNumber : String?, currentFrameNumber: String) -> Bool {
        return true
    }
    
    override public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        super.captureOutput(output, didOutput: sampleBuffer, from: connection)
        captureOutputDelegate?.capture(output, didOutput: sampleBuffer, from: connection)
    }
    
    override public func onScannedCard(number: String, expiryYear: String?, expiryMonth: String?, scannedImage: UIImage?) {
        
        if self.calledDelegate {
            return
        }
        
        let notification = UINotificationFeedbackGenerator()
        notification.prepare()
        notification.notificationOccurred(.success)
                
        self.calledDelegate = true
        let card = CreditCard(number: number)
        card.expiryMonth = expiryMonth
        card.expiryYear = expiryYear
        card.image = scannedImage
        // This is a hack to work around having to change our public interface
        card.name = predictedName

        self.scanDelegate?.userDidScanCard(self, creditCard: card)
    }
    
    
    @objc func toggleTorch(_ sender: Any) {
        self.toggleTorch()
    }
    
}

@available(iOS 11.2, *)
extension ScanViewController {
     @objc func viewOnWillResignActive() {
        let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.dark)
        self.backgroundBlurEffectView = UIVisualEffectView(effect: blurEffect)

        guard let backgroundBlurEffectView = self.backgroundBlurEffectView else {
            return
        }

        backgroundBlurEffectView.frame = self.view.bounds
        backgroundBlurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(backgroundBlurEffectView)
     }
    
     @objc func viewOnDidBecomeActive() {
        if let backgroundBlurEffectView = self.backgroundBlurEffectView {
            backgroundBlurEffectView.removeFromSuperview()
        }
         mainView.cardNumberLabel.isHidden = true
         mainView.expiryLabel.isHidden = true
     }
     
     func addBackgroundObservers() {
         NotificationCenter.default.addObserver(self, selector: #selector(viewOnWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
         NotificationCenter.default.addObserver(self, selector: #selector(viewOnDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
     }
}

// https://stackoverflow.com/a/53143736/947883
extension UIView {
    func fadeIn(_ duration: TimeInterval? = 0.4, onCompletion: (() -> Void)? = nil) {
        self.alpha = 0
        self.isHidden = false
        UIView.animate(withDuration: duration!,
                       animations: { self.alpha = 1 },
                       completion: { (value: Bool) in
                        if let complete = onCompletion { complete() }})
    }
}



extension ScanViewController {
    
    class ScanView : UIView {
        
        var backButtonImageToTextConstraint: NSLayoutConstraint!
        var backButtonWidthConstraint: NSLayoutConstraint!
        var regionOfInterestAspectConstraint: NSLayoutConstraint!
        var torchButtonWidthConstraint: NSLayoutConstraint!
        var torchButtonHeightConstraint: NSLayoutConstraint!
        
        // MARK: -  UI Elements
        lazy var previewView: PreviewView = {
            let view = PreviewView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.backgroundColor = .white
            return view
        }()

        lazy var cornerView: CornerView = {
            let view = CornerView()
            view.contentMode = .scaleToFill
            view.translatesAutoresizingMaskIntoConstraints = false
            view.backgroundColor = .clear
            view.layer.borderWidth = 5
            view.layer.cornerRadius = 15
            return view
        }()

        lazy var regionOfInterestLabel: UILabel = {
            let label = UILabel()
            label.contentMode = .left
            label.text = ""
            label.textAlignment = .center
            label.lineBreakMode = .byTruncatingTail
            label.baselineAdjustment = .alignBaselines
            label.adjustsFontSizeToFitWidth = false
            label.translatesAutoresizingMaskIntoConstraints = false
            label.backgroundColor = .clear
            label.font = .systemFont(ofSize: 17)
            label.textColor = UIColor(red: 0.18039215689999999, green: 0.81568627449999997, blue: 0.37647058820000001, alpha: 1)
            return label
        }()

        lazy var backButtonImageButton: UIButton = {
            let button = UIButton()
            button.contentMode = .scaleToFill
            button.contentHorizontalAlignment = .center
            button.contentVerticalAlignment = .center
            button.translatesAutoresizingMaskIntoConstraints = false
            button.tintColor = .white
            button.setImage(UIImage(named: "back_arrow_white", in: CSBundle.bundle(), compatibleWith: nil), for: .normal)
            return button
        }()

        lazy var backButton: UIButton = {
            let button = UIButton()
            button.contentMode = .scaleToFill
            button.contentHorizontalAlignment = .center
            button.contentVerticalAlignment = .center
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setTitle("Back", for: .normal)
            button.setTitleColor(.white, for: .normal)
            return button
        }()

        lazy var blurView: BlurView = {
            let view = BlurView()
            view.contentMode = .scaleToFill
            view.translatesAutoresizingMaskIntoConstraints = false
            view.backgroundColor = UIColor(red: 0.18431372549019609, green: 0.20784313725490194, blue: 0.25882352941176467, alpha: 0.70205479452054798)
            return view
        }()

        lazy var wierdLabel: UILabel = {
            let label = UILabel()
            label.contentMode = .left
            label.text = ""
            label.textAlignment = .center
            label.lineBreakMode = .byTruncatingTail
            label.baselineAdjustment = .alignBaselines
            label.adjustsFontSizeToFitWidth = false
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .systemFont(ofSize: 17)
            label.textColor = UIColor(red: 0.18039215689999999, green: 0.81568627449999997, blue: 0.37647058820000001, alpha: 1)
            return label
        }()

        lazy var debugImageView: UIImageView = {
            let imageView = UIImageView()
            imageView.isHidden = true
            imageView.clipsToBounds = true
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            return imageView
        }()

        lazy var cardNumberLabel: UILabel = {
            let label = UILabel()
            label.isHidden = true
            label.text = "4242 4242 4242 4242"
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .systemFont(ofSize: 48)
            label.minimumScaleFactor = 12/48
            label.adjustsFontSizeToFitWidth = true
            label.textColor = .white
            return label
        }()

        lazy var expiryLabel: UILabel = {
            let label = UILabel()
            label.isHidden = true
            label.contentMode = .left
            label.text = "05/22"
            label.textAlignment = .center
            label.adjustsFontSizeToFitWidth = false
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .systemFont(ofSize: 20)
            label.textColor = .white
            return label
        }()

        lazy var scanCardLabel: UILabel = {
            let label = UILabel()
            label.text = "Scan Card"
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .systemFont(ofSize: 24)
            label.textColor = .white
            return label
        }()

        lazy var positionCardLabel: UILabel = {
            let label = UILabel()
            label.text = "Position your card in the frame so the card number is visible"
            label.textAlignment = .center
            label.numberOfLines = 2
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .systemFont(ofSize: 17)
            label.textColor = .white
            return label
        }()

        lazy var bottomView: UIView = {
            let view = UIView()
            view.contentMode = .scaleToFill
            view.translatesAutoresizingMaskIntoConstraints = false
            view.backgroundColor = .clear
            return view
        }()

        lazy var torchButton: UIButton = {
            let button = UIButton()
            button.contentMode = .scaleToFill
            button.contentHorizontalAlignment = .center
            button.contentVerticalAlignment = .center
            button.translatesAutoresizingMaskIntoConstraints = false
            button.tintColor = UIColor(displayP3Red: 0.48771206350000001, green: 0.98004418609999999, blue: 0.44752816719999999, alpha: 1)
            button.setImage(UIImage(named: "flashlight", in: CSBundle.bundle(), compatibleWith: nil), for: .normal)
            return button
        }()

        lazy var skipButton: UIButton = {
            let button = UIButton()
            button.contentHorizontalAlignment = .center
            button.contentVerticalAlignment = .center
            button.translatesAutoresizingMaskIntoConstraints = false
            button.titleLabel?.font = .systemFont(ofSize: 17)
            button.setTitle("Enter card manually", for: .normal)
            button.setTitleColor(.white, for: .normal)
            return button
        }()

        
        override init(frame: CGRect) {
            super.init(frame: frame)
            self.setupUI()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func setupUI() {
            backButtonImageToTextConstraint = backButton.leadingAnchor.constraint(equalTo: backButtonImageButton.trailingAnchor, constant: -11)
            backButtonWidthConstraint = backButtonImageButton.widthAnchor.constraint(equalToConstant: 32)
            regionOfInterestAspectConstraint = regionOfInterestLabel.widthAnchor.constraint(equalTo: regionOfInterestLabel.heightAnchor, multiplier: 359/226)
            torchButtonWidthConstraint = torchButton.widthAnchor.constraint(equalToConstant: 60)
            torchButtonHeightConstraint = torchButton.heightAnchor.constraint(equalToConstant: 60)
            
            self.backgroundColor = .white
            
            // MARK: -  View Hierachy
            self.addSubview(previewView)
            self.addSubview(cornerView)
            self.addSubview(regionOfInterestLabel)
            self.addSubview(backButtonImageButton)
            self.addSubview(backButton)
            previewView.addSubview(blurView)
            previewView.addSubview(wierdLabel)
            previewView.addSubview(debugImageView)
            previewView.addSubview(cardNumberLabel)
            previewView.addSubview(expiryLabel)
            previewView.addSubview(scanCardLabel)
            previewView.addSubview(positionCardLabel)
            previewView.addSubview(bottomView)
            bottomView.addSubview(torchButton)
            bottomView.addSubview(skipButton)

            // MARK: -  Constrains
            NSLayoutConstraint.activate([
                wierdLabel.topAnchor.constraint(equalTo: scanCardLabel.bottomAnchor, constant: 16),
                wierdLabel.bottomAnchor.constraint(equalTo: debugImageView.bottomAnchor),
                wierdLabel.leadingAnchor.constraint(equalTo: previewView.leadingAnchor, constant: 16),
                wierdLabel.trailingAnchor.constraint(equalTo: debugImageView.trailingAnchor),
                wierdLabel.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: -16),
                wierdLabel.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
                wierdLabel.centerYAnchor.constraint(equalTo: previewView.centerYAnchor),
                wierdLabel.widthAnchor.constraint(equalTo: wierdLabel.heightAnchor, multiplier: 343/216),
                wierdLabel.widthAnchor.constraint(equalTo: wierdLabel.heightAnchor, multiplier: 343/216),

                positionCardLabel.topAnchor.constraint(equalTo: wierdLabel.bottomAnchor, constant: 16),
                positionCardLabel.leadingAnchor.constraint(equalTo: previewView.leadingAnchor, constant: 16),
                positionCardLabel.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: -16),
                positionCardLabel.heightAnchor.constraint(equalToConstant: 49),

                torchButton.centerXAnchor.constraint(equalTo: bottomView.centerXAnchor),
                torchButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor),
                torchButtonWidthConstraint,
                torchButtonHeightConstraint,

                skipButton.topAnchor.constraint(equalTo: bottomView.topAnchor),
                skipButton.leadingAnchor.constraint(equalTo: bottomView.leadingAnchor, constant: 16),
                skipButton.trailingAnchor.constraint(equalTo: bottomView.trailingAnchor, constant: -16),
                skipButton.heightAnchor.constraint(equalToConstant: 30),

                blurView.topAnchor.constraint(equalTo: previewView.topAnchor),
                blurView.bottomAnchor.constraint(equalTo: previewView.bottomAnchor),
                blurView.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
                blurView.trailingAnchor.constraint(equalTo: previewView.trailingAnchor),

                bottomView.topAnchor.constraint(equalTo: positionCardLabel.bottomAnchor),
                bottomView.bottomAnchor.constraint(equalTo: previewView.bottomAnchor),
                bottomView.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
                bottomView.trailingAnchor.constraint(equalTo: previewView.trailingAnchor),

                expiryLabel.topAnchor.constraint(equalTo: cardNumberLabel.bottomAnchor, constant: 8),
                expiryLabel.leadingAnchor.constraint(equalTo: previewView.leadingAnchor, constant: 32),
                expiryLabel.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: -32),

                cardNumberLabel.leadingAnchor.constraint(equalTo: previewView.leadingAnchor, constant: 32),
                cardNumberLabel.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: -32),
                cardNumberLabel.centerYAnchor.constraint(equalTo: wierdLabel.centerYAnchor, constant: 16),

                scanCardLabel.leadingAnchor.constraint(equalTo: previewView.leadingAnchor, constant: 16),
                scanCardLabel.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: -16),

                debugImageView.topAnchor.constraint(equalTo: wierdLabel.topAnchor),
                debugImageView.leadingAnchor.constraint(equalTo: wierdLabel.leadingAnchor),

                cornerView.leadingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leadingAnchor, constant: 11),
                cornerView.trailingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.trailingAnchor, constant: -11),
                cornerView.widthAnchor.constraint(equalTo: cornerView.heightAnchor, multiplier: 353/226),

                regionOfInterestLabel.leadingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leadingAnchor, constant: 16),
                regionOfInterestLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
                regionOfInterestLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
                regionOfInterestLabel.centerXAnchor.constraint(equalTo: cornerView.centerXAnchor),
                regionOfInterestLabel.centerYAnchor.constraint(equalTo: cornerView.centerYAnchor),
                regionOfInterestLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor),
                regionOfInterestAspectConstraint,

                backButtonImageButton.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor, constant: 16),
                backButtonImageButton.leadingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leadingAnchor, constant: 8),
                backButtonWidthConstraint,
                backButtonImageButton.heightAnchor.constraint(equalToConstant: 32),

                previewView.topAnchor.constraint(equalTo: self.topAnchor),
                previewView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
                previewView.leadingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leadingAnchor),

                self.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: previewView.trailingAnchor),

                backButtonImageToTextConstraint,
                backButton.centerYAnchor.constraint(equalTo: backButtonImageButton.centerYAnchor),
            ])
        }
        
    }
    
}
