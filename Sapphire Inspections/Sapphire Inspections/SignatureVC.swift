//
//  SignatureVC.swift
//

import UIKit
import CoreImage
import Vivid

protocol SignatureVCDelegate: class {
    func signatureUpdated(item: TemplateItem, action: String, binaryUpdate: Bool)
}

class SignatureVC: UIViewController, YPSignatureDelegate, UINavigationControllerDelegate, UIScrollViewDelegate {

    @IBOutlet var doneButton: UIBarButtonItem!
    @IBOutlet weak var signatureView: YPDrawSignatureView!
    @IBOutlet weak var previewCurrentButton: UIButton!
    @IBOutlet weak var currentSignatureContainerView: UIView!
    @IBOutlet weak var currentSignatureImageView: UIImageView!
    @IBOutlet weak var rotateToSignView: UIView!
    
    weak var delegate: SignatureVCDelegate?
    
    var signatureImage: UIImage?
    var signatureReviewImage: UIImage?
    
    var screenSize = CGSize.zero
    
    var keyItem: (key: String, item: TemplateItem)?
    var keyInspection: (key: String, inspection: Inspection)?
    var readOnly = true

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        signatureView.delegate = self
        signatureView.strokeWidth = 4.0
        
        // Do any additional setup after loading the view.
        removeDoneButton()
        

        loadCurrentSignature()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if screenSize == .zero {
            screenSize = UIScreen.main.bounds.size
            print("viewWillAppear: \(screenSize)")
        }
        
        // 568 is the smallest phone height supported
        if screenSize.width < 568 {
            UIDevice.current.setValue(Int(UIInterfaceOrientation.landscapeRight.rawValue), forKey: "orientation")
        }
        
        rotateToSignView.alpha = 0.0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
//        // Redraw for updated view
//        if let image = signatureImage {
//            setImageToCrop(image: image)
//        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscapeRight
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        screenSize = size
        
        // 568 is the smallest phone height supported
        if screenSize.width < 568 {
            rotateToSignView.alpha = 1.0
        } else {
            rotateToSignView.alpha = 0.0
        }
    }
    
    @IBAction func hitBackButton(_ sender: UIBarButtonItem) {
        
        if let navController = navigationController {
            navController.popViewController(animated: true)
        }
    }
    
    @IBAction func hitRedoButton(_ sender: UIButton) {
        signatureView.undo()
//        newSignatureView.erase()
        
        if !signatureView.doesContainSignature {
            removeDoneButton()
        }
    }
    
    @IBAction func hitPreviewCurrentSignatureButton(_ sender: UIButton) {
        currentSignatureContainerView.alpha = 1.0
    }
    
    @IBAction func hitCloseCurrentSignature(_ sender: Any) {
        currentSignatureContainerView.alpha = 0.0
    }
    
    @IBAction func doneButtonTapped(_ sender: UIBarButtonItem) {
        
        guard let image = signatureView.getSignature(scale: 6.0) else {
            print("ERROR: signature could not be converted to an image")
            return
        }
            
        signatureImage = image
        saveImage()
    }
    
    func addDoneButton() {
        navigationItem.rightBarButtonItems = [doneButton]
    }
    
    func removeDoneButton() {
        navigationItem.rightBarButtonItems = []
    }
    
    func loadCurrentSignature() {
        previewCurrentButton.isHidden = true
        
        guard let key = keyItem?.key else {
            return
        }
        
        guard let item = keyItem?.item else {
            return
        }
        
        // pull existing, if avaiable, else return
        if item.signatureTimestampKey != "" {
            print("Signature URL: \(item.signatureDownloadURL)")
            previewCurrentButton.isHidden = false

            if item.signatureDownloadURL == "" {
                if let localImage = LocalInspectionImages.localInspectionItemImage(inspectionKey: keyInspection!.key, itemKey: key, key: item.signatureTimestampKey) {
                    print("Loaded offline photo with key=\(item.signatureTimestampKey)")
                    currentSignatureImageView.image = UIImage(data: localImage.imageData!)
                }
            } else {
                let signatureURL = URL(string: item.signatureDownloadURL)
                let downloader = SDWebImageDownloader.shared
                downloader.downloadImage(with: signatureURL, options: .highPriority, progress: { (receivedSize, expectedSize, targetURL) in
                }, completed: { [weak self] (image, data, error, finished) in
                    if let image = image , finished {
                        self?.currentSignatureImageView.image = image
                    }
                })
            }
        }
    }
    
    // MARK: YPSignatureDelegate
    
    func didStart() {
        
    }
    
    func didFinish() {
        if signatureView.doesContainSignature {
            addDoneButton()
        }
    }

    
    func simpleBlurFilter(inputImage: UIImage) -> UIImage? {
        var context: CIContext!
        var currentFilter: CIFilter!
        
        context = CIContext()
        currentFilter = CIFilter(name: "YUCIFXAA") // From Vivid
        
        let beginImage = CIImage(image: inputImage)
        currentFilter.setValue(beginImage, forKey: kCIInputImageKey)
//        currentFilter.setValue(1, forKey: kCIInputRadiusKey) // Default 10
        
        if let cgimg = context.createCGImage(currentFilter.outputImage!, from: currentFilter.outputImage!.extent) {
            let processedImage = UIImage(cgImage: cgimg)
            return processedImage
        }
        
        return nil
    }
    
    func saveImage() {
        guard let image = signatureImage else {
            print("no image to save")
            return
        }
        if let keyInspection = self.keyInspection, let keyItem = self.keyItem, let imageData = image.jpegData(compressionQuality: 0.5) {
            // Remove old signature image, if it exists
            if keyItem.item.signatureTimestampKey != "" {
                let oldSignatureImage = LocalInspectionItemImage()
                oldSignatureImage.key = keyItem.item.signatureTimestampKey
                oldSignatureImage.inspectionKey = keyInspection.key
                oldSignatureImage.itemKey = keyItem.key
                LocalInspectionImages.deleteImage(imageObject: oldSignatureImage)
            }
            
            let timestamp = String(format: "%.0f", Date().timeIntervalSince1970 * 1000)
            let imageRef = storageInspectionItemImagesRef.child("\(keyInspection.key)").child("\(keyItem.key)").child("\(timestamp).jpg")
            
            if FIRConnection.connected() && !pauseUploadingPhotos {
                SVProgressHUD.show()

                // Upload the file using the property key as the image name
                imageRef.putData(imageData, metadata: nil) { metadata, error in
                    DispatchQueue.main.async(execute: { [weak self] () -> Void in
                        if (error != nil) {
                            let newLocalImage = LocalInspectionItemImage()
                            newLocalImage.key = timestamp
                            newLocalImage.imageData = imageData
                            newLocalImage.inspectionKey = keyInspection.key
                            newLocalImage.itemKey = keyItem.key
                            newLocalImage.isSignature = true
                            keyItem.item.signatureTimestampKey = timestamp
                            keyItem.item.signatureDownloadURL = ""
                            print(timestamp)
                            print("Added offline photo")
                            LocalInspectionImages.addImage(imageObject: newLocalImage)
                            self?.delegate?.signatureUpdated(item: keyItem.item, action: "signature photo added with filename: \(timestamp).jpg", binaryUpdate: true)
                        } else {
                            storageInspectionItemImagesRef.child("\(keyInspection.key)").child("\(keyItem.key)").child("\(timestamp).jpg").downloadURL(completion: { [weak self] (downloadURL, error) in
                                
                                SVProgressHUD.dismiss()

                                guard error == nil, let downloadURL = downloadURL else {
                                    DispatchQueue.main.async(execute: { [weak self] () -> Void in
                                        self?.showMessagePrompt("Error occurred when saving signature image")
                                    })
                                    return
                                }
                                
                                keyItem.item.signatureTimestampKey = timestamp
                                keyItem.item.signatureDownloadURL = downloadURL.absoluteString
                                self?.delegate?.signatureUpdated(item: keyItem.item, action: "signature photo added with filename: \(timestamp).jpg", binaryUpdate: true)
                                
                                if let navController = self?.navigationController {
                                    navController.popViewController(animated: true)
                                }
                            })
                        }
                    })
                }
            } else {
                let newLocalImage = LocalInspectionItemImage()
                newLocalImage.key = timestamp
                newLocalImage.imageData = imageData
                newLocalImage.inspectionKey = keyInspection.key
                newLocalImage.itemKey = keyItem.key
                newLocalImage.isSignature = true
                keyItem.item.signatureTimestampKey = timestamp
                keyItem.item.signatureDownloadURL = ""
                
                print(timestamp)
                LocalInspectionImages.addImage(imageObject: newLocalImage)
                print("Added offline photo")
                self.delegate?.signatureUpdated(item: keyItem.item, action: "signature photo added with filename: \(timestamp).jpg", binaryUpdate: true)
                
                if let navController = navigationController {
                    navController.popViewController(animated: true)
                }
            }
        } else {
            DispatchQueue.main.async(execute: { () -> Void in
                self.showMessagePrompt("Error occurred when creating image data")
            })
        }
    }
}

