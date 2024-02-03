//
//  GalleryVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 9/10/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import RealmSwift
import FirebaseFirestore
import SwiftyJSON
//import YPImagePicker


protocol GalleryVCDelegate: class {
    func galleryUpdated(item: TemplateItem, action: String, binaryUpdate: Bool)
}

//import INSPhotoGallery
import ImagePicker
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}


class GalleryVC: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, ImagePickerDelegate {

    @IBOutlet weak var itemTitle: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var addButton: UIBarButtonItem!
    
    var inspectionListener: ListenerRegistration?

    var keyItem: (key: String, item: TemplateItem)?
    var keyInspection: (key: String, inspection: Inspection)?
    var readOnly = true
    var needToLoadItem = false
    weak var delegate: GalleryVCDelegate?
    
    var photos: [GalleryPhotoModel] = []
    var offlineImagesToAdd: [LocalInspectionItemImage] = []
    var captions: [String] = []
    
    //var uploadingImagesCount = 0
    var imagesToUpload: [UIImage] = []
    
    var dismissHUD = false
    
//    var config = YPImagePickerConfiguration()
//    var picker: YPImagePicker?
    
    var viewAppeared = false


//    var token: NotificationToken?
//    
    deinit {
        if let listener = inspectionListener {
            listener.remove()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let keyItem = keyItem {
            itemTitle.text = keyItem.item.title
        }
        
        addButton.isEnabled = !readOnly
    
        refreshPhotos()
        
        if needToLoadItem {
            setObservers()
        }
        
//        configureImagePicker()
        

        
//        let realm = try! Realm()
//        token = realm.addNotificationBlock { notification, realm in
//            self.refreshPhotos()
//        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !viewAppeared && !readOnly && photos.count == 0 {
            addButtonTapped(addButton)
        }
        
        viewAppeared = true
    }
    
    func refreshPhotos() {
        photos = []
        if let keyItem = keyItem {
            if let photosData = keyItem.item.photosData as? [String: [String: AnyObject]] {
                for (key, value) in photosData {
                    if let downloadURL = value["downloadURL"] as? String {
                        let caption = value["caption"] as? String ?? ""
                        let photo = GalleryPhotoModel()
                        photo.itemPhotoDataKey = key
                        if downloadURL == "" && keyInspection != nil {
                            if let localImage = LocalInspectionImages.localInspectionItemImage(inspectionKey: keyInspection!.key, itemKey: keyItem.key, key: key) {
                                print("Loaded offline photo with key=\(key)")
                                photo.image = UIImage(data: localImage.imageData!)
                                photo.thumbnailImage = UIImage(data: localImage.imageData!)
                            }
                        }
                        photo.imageURL = URL(string: downloadURL)
                        photo.thumbnailImageURL = URL(string: downloadURL)
                        let paragraphStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
                        paragraphStyle.alignment = NSTextAlignment.center
                        let attributes: [NSAttributedString.Key: Any] = [
                            .foregroundColor: UIColor.white,
                            .paragraphStyle: paragraphStyle
                            ]
                        photo.attributedTitle = NSAttributedString(string: caption, attributes: attributes)
                        self.photos.append(photo)
                    }
                }
            }
            
            photos.sort(by: { $0.itemPhotoDataKey < $1.itemPhotoDataKey })
        }
        
        collectionView.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        guard let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            return
        }
        
        flowLayout.invalidateLayout()  // Recalculate item size
    }
    
/*
    func configureImagePicker() {
        // General
        config.isScrollToChangeModesEnabled = true
        config.onlySquareImagesFromCamera = false
        config.usesFrontCamera = false
        config.showsPhotoFilters = false
        config.showsVideoTrimmer = true
        config.shouldSaveNewPicturesToAlbum = false
        config.albumName = "Sparkle"
        config.startOnScreen = YPPickerScreen.photo
        config.screens = [.library, .photo]
        config.showsCrop = .none
        config.targetImageSize = YPImageSize.original
        config.overlayView = UIView()
        config.hidesStatusBar = true
        config.hidesBottomBar = false
        config.hidesCancelButton = false
        config.preferredStatusBarStyle = UIStatusBarStyle.default
//        config.bottomMenuItemSelectedColour = UIColor(r: 38, g: 38, b: 38)
//        config.bottomMenuItemUnSelectedColour = UIColor(r: 153, g: 153, b: 153)
//        config.filters = [DefaultYPFilters...]
//        config.maxCameraZoomFactor = 1.0
        
        // Library
        config.library.options = nil
        config.library.onlySquare = false
        config.library.isSquareByDefault = false
        config.library.minWidthForItem = nil
        config.library.mediaType = YPlibraryMediaType.photo
        config.library.defaultMultipleSelection = true
        config.library.maxNumberOfItems = 10
        config.library.minNumberOfItems = 1
        config.library.numberOfItemsInRow = 4
        config.library.spacingBetweenItems = 1.0
        config.library.skipSelectionsGallery = true
        config.library.preselectedItems = nil
        
        // Video
//        config.video.compression = AVAssetExportPresetHighestQuality
//        config.video.fileType = .mov
//        config.video.recordingTimeLimit = 60.0
//        config.video.libraryTimeLimit = 60.0
//        config.video.minimumTimeLimit = 3.0
//        config.video.trimmerMaxDuration = 60.0
//        config.video.trimmerMinDuration = 3.0
        
        // Gallery
        config.gallery.hidesRemoveButton = false
        
        picker = YPImagePicker(configuration: config)
        
        picker?.didFinishPicking { [unowned picker] items, cancelled in
            var images: [UIImage] = []
            for item in items {
                switch item {
                case .photo(let photo):
                    images.append(photo.image)
//                    print(photo)
                case .video(let video):
                    print(video)
                }
            }
            if images.count > 0 {
                DispatchQueue.main.async(execute: { [weak self] () -> Void in
                    picker?.dismiss(animated: true, completion: nil)
                    self?.alertForEnterPhotoCaption(images)
                })
            } else {
                DispatchQueue.main.async(execute: { () -> Void in
                    picker?.dismiss(animated: true, completion: nil)
                })
            }
        }
    }
*/
    
    // MARK: Actions
    
    @IBAction func addButtonTapped(_ sender: AnyObject) {
        
//        if let picker = picker {
//            DispatchQueue.main.async(execute: { [weak self] () -> Void in
//                self?.present(picker, animated: true, completion: nil)
//            })
//        }
        
        let imagePickerController = ImagePickerController()
        imagePickerController.imageLimit = 10
        imagePickerController.modalPresentationStyle = .fullScreen
        imagePickerController.delegate = self
        present(imagePickerController, animated: true, completion: nil)
    }
    
    @IBAction func longPress(_ sender: UILongPressGestureRecognizer) {
        if (sender.state != UIGestureRecognizer.State.began || readOnly){
            return
        }
        
        let p = sender.location(in: self.collectionView)
        
        if let indexPath = (self.collectionView?.indexPathForItem(at: p)) {
            alertForCaptionUpdateOrDelete(indexPath)
        }
    }
    
    // MARK: - UICollectionView
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "imageCell", for: indexPath) as! GalleryImageCell
        
        cell.populateWithPhoto(photos[(indexPath as NSIndexPath).row])
        //cell.addCaption(captions[indexPath.row])
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let screenSize: CGRect = UIScreen.main.bounds
        
        return itemSizeForScreenWidth(screenSize.width)
    }
    
    func itemSizeForScreenWidth(_ screenWidth: CGFloat) -> CGSize {
        let screenScale: CGFloat = UIScreen.main.scale
        let maxWidth: CGFloat = 300 + (screenScale * 8) // Thumbnail are never more than 300px (16px border)
        
        let mainScreenWidthScaled: CGFloat = (screenWidth * screenScale)
        
        var divisor: CGFloat = 1
        var result = mainScreenWidthScaled / divisor
        while (result > maxWidth) {
            divisor += 1
            result = mainScreenWidthScaled / divisor
        }
        
        let cellWidth = result / screenScale
        
        return CGSize(width: cellWidth, height: cellWidth)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! GalleryImageCell
        let currentPhoto = photos[(indexPath as NSIndexPath).row]
        let galleryPreview = INSPhotosViewController(photos: photos, initialPhoto: currentPhoto, referenceView: cell)
        
        galleryPreview.referenceViewForPhotoWhenDismissingHandler = { [weak self] photo in
            if let index = self?.photos.index(where: {$0 === photo}) {
                let indexPath = IndexPath(item: index, section: 0)
                return collectionView.cellForItem(at: indexPath) as? GalleryImageCell
            }
            return nil
        }
        present(galleryPreview, animated: true, completion: nil)
    }
    
    // MARK: ImagePicker Delegate
    
    func wrapperDidPress(_ imagePicker: ImagePickerController, images: [UIImage]) {
        print("Wrapper Did Press")
    }
    
    func doneButtonDidPress(_ imagePicker: ImagePickerController, images: [UIImage]) {
        print("Done Button Did Press")
                
        dismiss(animated: true) {
            DispatchQueue.main.async(execute: { [weak self] () -> Void in
                self?.alertForEnterPhotoCaption(images)
            })
        }
    }
    
    func cancelButtonDidPress(_ imagePicker: ImagePickerController) {
        print("Cancel Button Did Press")
        dismiss(animated: true)
    }
    
    // MARK: Uploading
    
    func updateNextImage(_ caption: String) {
        if imagesToUpload.count > 0 {
            let image = imagesToUpload.removeFirst()
            if let keyInspection = self.keyInspection, let keyItem = self.keyItem, let imageData = image.jpegData(compressionQuality: 0.5) {
                let timestamp = String(format: "%.0f", Date().timeIntervalSince1970 * 1000)
                let imageRef = storageInspectionItemImagesRef.child("\(keyInspection.key)").child("\(keyItem.key)").child("\(timestamp).jpg")
                
                if FIRConnection.connected() && !pauseUploadingPhotos {
                    // Upload the file using the property key as the image name
                    imageRef.putData(imageData, metadata: nil) { metadata, error in
                        DispatchQueue.main.async(execute: { [weak self] () -> Void in
                            if (error != nil) {
                                let newLocalImage = LocalInspectionItemImage()
                                newLocalImage.key = timestamp
                                newLocalImage.imageData = imageData
                                newLocalImage.caption = caption
                                newLocalImage.inspectionKey = keyInspection.key
                                newLocalImage.itemKey = keyItem.key
                                let photoData: [String : AnyObject] = ["downloadURL" : "" as AnyObject, "caption" : caption as AnyObject]
                                keyItem.item.photosData[timestamp] = photoData as AnyObject?
                                print(timestamp)
                                print(keyItem.item.photosData)
                                print(keyItem.item.photosData[timestamp] as? [String: AnyObject] ?? "nothing")
                                self?.offlineImagesToAdd.append(newLocalImage)
                                print("Added offline photo")
                                self?.delegate?.galleryUpdated(item: keyItem.item, action: "added photo with filename: \(timestamp).jpg, and caption: \"\(caption)\"", binaryUpdate: true)
                                self?.updateNextImage(caption)
                            } else {
                                storageInspectionItemImagesRef.child("\(keyInspection.key)").child("\(keyItem.key)").child("\(timestamp).jpg").downloadURL(completion: { [weak self] (downloadURL, error) in
                                    
                                    guard error == nil, let downloadURL = downloadURL else {
                                        DispatchQueue.main.async(execute: { () -> Void in
                                            self?.showMessagePrompt("Error occurred when saving image")
                                            self?.updateNextImage(caption)
                                        })
                                        return
                                    }
                                    
                                    let photoData: [String : AnyObject] = ["downloadURL" : "\(downloadURL.absoluteString)" as AnyObject, "caption" : caption as AnyObject]
                                    keyItem.item.photosData[timestamp] = photoData as AnyObject?
                                    self?.delegate?.galleryUpdated(item: keyItem.item, action: "added photo with filename: \(timestamp).jpg, and caption: \"\(caption)\"", binaryUpdate: true)
                                    self?.updateNextImage(caption)
                                })
                            }
                        })
                    }
                } else {
                    let newLocalImage = LocalInspectionItemImage()
                    newLocalImage.key = timestamp
                    newLocalImage.imageData = imageData
                    newLocalImage.caption = caption
                    newLocalImage.inspectionKey = keyInspection.key
                    newLocalImage.itemKey = keyItem.key
                    let photoData: [String : AnyObject] = ["downloadURL" : "" as AnyObject, "caption" : caption as AnyObject]
                    keyItem.item.photosData[timestamp] = photoData as AnyObject?
                    print(timestamp)
                    print(keyItem.item.photosData)
                    print(keyItem.item.photosData[timestamp] as? [String: AnyObject] ?? "nothing")
                    self.offlineImagesToAdd.append(newLocalImage)
                    print("Added offline photo")
                    self.delegate?.galleryUpdated(item: keyItem.item, action: "added photo with filename: \(timestamp).jpg, and caption: \"\(caption)\"", binaryUpdate: true)
                    self.updateNextImage(caption)
                }
            } else {
                DispatchQueue.main.async(execute: { [weak self] () -> Void in
                    self?.showMessagePrompt("Error occurred when creating image data")
                    self?.updateNextImage(caption)
                })
            }
        } else {
            if offlineImagesToAdd.count > 0 {
                LocalInspectionImages.addImages(imageObjects: offlineImagesToAdd)
                offlineImagesToAdd.removeAll()
            }

            self.refreshPhotos()
            SVProgressHUD.dismiss()
        }
    }

    // MARK: Alerts
    
    func alertForCaptionUpdateOrDelete(_ indexPath: IndexPath) {
        let alertController = UIAlertController(title: "Photo Options", message: nil, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel action"), style: .cancel, handler: { (action) in
            print("Cancel Action")
        })
        let captionAction = UIAlertAction(title: "CAPTION", style: .default) { [weak self] (action) -> Void in
            if let photo = self?.photos[(indexPath as NSIndexPath).row] {
                self?.alertForUpdatingPhotoCaption(photo)
            }
        }
        let deleteAction = UIAlertAction(title: NSLocalizedString("DELETE", comment: "Delete Action"), style: .destructive, handler: { [weak self] (action) in
            self?.alertForDeletingImage(indexPath)
        })
        
        alertController.addAction(cancelAction)
        alertController.addAction(captionAction)
        alertController.addAction(deleteAction)

        present(alertController, animated: true, completion: {})
    }
    
    func alertForDeletingImage(_ indexPath: IndexPath) {
        let alertController = UIAlertController(title: "Are you sure you want to delete this image?", message: nil, preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel action"), style: .cancel, handler: { (action) in
            print("Cancel Action")
        })
        let deleteAction = UIAlertAction(title: NSLocalizedString("DELETE", comment: "Delete Action"), style: .destructive, handler: { [weak self] (action) in
            DispatchQueue.main.async(execute: { () -> Void in
                guard let weakSelf = self else {
                    return
                }
                
                let photo = weakSelf.photos[(indexPath as NSIndexPath).row] as GalleryPhotoModel
                if let itemPhotoDataKey = photo.itemPhotoDataKey, let keyInspection = weakSelf.keyInspection, let keyItem = weakSelf.keyItem {
                    if let localImage = LocalInspectionImages.localInspectionItemImage(inspectionKey: weakSelf.keyInspection!.key, itemKey: keyItem.key, key: itemPhotoDataKey) {
                        if !localImage.synced {
                            let realm = try! Realm()
                            try! realm.write {
                                realm.delete(localImage)
                            }
                            keyItem.item.photosData.removeValue(forKey: itemPhotoDataKey)
                            weakSelf.refreshPhotos()
                        } else  {
                            let realm = try! Realm()
                            try! realm.write {
                                localImage.deleted = true
                            }
                            keyItem.item.photosData.removeValue(forKey: itemPhotoDataKey)
                            weakSelf.refreshPhotos()
                        }
                    } else {
                        let imageRef = storageInspectionItemImagesRef.child("\(keyInspection.key)").child("\(keyItem.key)").child("\(itemPhotoDataKey).jpg")
                        if FIRConnection.connected() {
                            SVProgressHUD.show(withStatus: "Deleting Photo")
                            imageRef.delete(completion: { (error) in
                                if error != nil {
                                    let newLocalImage = LocalInspectionItemImage()
                                    newLocalImage.deleted = true
                                    newLocalImage.key = itemPhotoDataKey
                                    newLocalImage.inspectionKey = keyInspection.key
                                    newLocalImage.itemKey = keyItem.key
                                    let realm = try! Realm()
                                    try! realm.write {
                                        realm.add(newLocalImage, update: .modified)
                                    }
                                }
                                
                                keyItem.item.photosData.removeValue(forKey: itemPhotoDataKey)
                                weakSelf.refreshPhotos()
                                SVProgressHUD.dismiss()
                            })
                        } else {
                            keyItem.item.photosData.removeValue(forKey: itemPhotoDataKey)
                            weakSelf.refreshPhotos()
                            SVProgressHUD.dismiss()
                        }

                    }
                    weakSelf.delegate?.galleryUpdated(item: keyItem.item, action: "deleted photo with filename: \(itemPhotoDataKey).jpg", binaryUpdate: true)
                }
            })
        })
        alertController.addAction(cancelAction)
        alertController.addAction(deleteAction)
        
        present(alertController, animated: true, completion: {})
    }
    
    func alertForEnterPhotoCaption(_ images: [UIImage]) {
        let alertController = UIAlertController(
            title: "Caption",
            message: "Please enter a caption for your photo\(images.count > 1 ? "s" : "")",
            preferredStyle: UIAlertController.Style.alert)
        
        let okAction = UIAlertAction(
        title: "OK", style: UIAlertAction.Style.default) { [weak self]
            (action) -> Void in
            let caption = alertController.textFields!.first!.text ?? ""
            print("You entered \(alertController.textFields!.first!.text ?? "")")
            
            SVProgressHUD.show(withStatus: "Saving Photo\(images.count > 1 ? "s" : "")")
            
            // Store photo, if one exists
            DispatchQueue.main.async(execute: { () -> Void in
                self?.imagesToUpload = images
                self?.updateNextImage(caption)
            })
        }
        
        alertController.addTextField {
            (txtInput) -> Void in
            txtInput.placeholder = "<Enter caption here>"
        }
        
        alertController.addAction(okAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    func alertForUpdatingPhotoCaption(_ photo: GalleryPhotoModel) {
        let alertController = UIAlertController(
            title: "Caption",
            message: "Enter a caption for the photo",
            preferredStyle: UIAlertController.Style.alert)
        
        let okAction = UIAlertAction(
        title: "OK", style: UIAlertAction.Style.default) { [weak self]
            (action) -> Void in
            guard let weakSelf = self else {
                return
            }
            
            let caption = alertController.textFields!.first!.text ?? ""
            print("You entered \(alertController.textFields!.first!.text ?? "")")

            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white
            ]
            photo.attributedTitle = NSAttributedString(string: caption, attributes: attributes)
            if let keyItem = weakSelf.keyItem, let itemPhotoDataKey = photo.itemPhotoDataKey {
                let photosData = keyItem.item.photosData
                var photoData = photosData[itemPhotoDataKey] as? [String: AnyObject]
                if photoData != nil {
                    weakSelf.delegate?.galleryUpdated(item: keyItem.item, action: "changed caption for photo with filename: \(itemPhotoDataKey).jpg from \"\(photoData!["caption"] as? String ?? "")\" to \"\(caption)\"", binaryUpdate: false)
                    photoData!["caption"] = caption as AnyObject?
                    keyItem.item.photosData[itemPhotoDataKey] = photoData! as AnyObject?
                }
                if let localImage = LocalInspectionImages.localInspectionItemImage(inspectionKey: weakSelf.keyInspection!.key, itemKey: keyItem.key, key: itemPhotoDataKey) {
                    print("Loaded offline photo with key=\(itemPhotoDataKey)")
                    if photoData == nil { weakSelf.delegate?.galleryUpdated(item: keyItem.item, action: "changed caption for photo with filename: \(itemPhotoDataKey).jpg from \"\(localImage.caption)\" to \"\(caption)\"", binaryUpdate: false) }
                    let realm = try! Realm()
                    try! realm.write {
                        localImage.caption = caption
                    }
                }
            }
            
            DispatchQueue.main.async(execute: { [weak self] () -> Void in
                self?.collectionView.reloadData()
            })
        }
        
        alertController.addTextField {
            (txtInput) -> Void in
            txtInput.placeholder = "<Enter caption here>"
            txtInput.text = photo.attributedTitle?.string
        }
        
        alertController.addAction(okAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    func setObservers() {
        if let keyInspection = keyInspection, let keyItem = keyItem {
            inspectionListener = dbDocumentInspectionWith(documentId: keyInspection.key).addSnapshotListener({ [weak self] (documentSnapshot, error) in
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        dismissHUDForConnection()
                        return
                    }
                    
                    if let document = documentSnapshot, document.exists {
                        let json = JSON(document.data() ?? [:])
                        if let templateItemDictObject = json["template"]["items"][keyItem.key].dictionaryObject {
                            if let item = Mapper<TemplateItem>().map(JSONObject: templateItemDictObject) {
                                weakSelf.keyItem?.item = item
                                weakSelf.refreshPhotos()
                            }
                        }

                    }
                    
                    if weakSelf.dismissHUD {
                        dismissHUDForConnection()
                        weakSelf.dismissHUD = false
                    }
                }
            })
        }
        
        dismissHUD = true
        presentHUDForConnection()
    }

}

class GalleryImageCell: UICollectionViewCell {
    
    @IBOutlet weak var bottomOverlayView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var captionLabel: UILabel!
    
    func populateWithPhoto(_ photo: GalleryPhotoModel) {
        photo.loadThumbnailImageWithCompletionHandler { [weak photo] (image, error) in
            if let image = image {
                if let photo = photo {
                    photo.thumbnailImage = image
                }
                DispatchQueue.main.async(execute: { [weak self] () -> Void in
                    self?.imageView.image = image
                })
            }
        }

        DispatchQueue.main.async(execute: { [weak self] () -> Void in
            if photo.attributedTitle == nil || photo.attributedTitle!.string == "" {
                self?.bottomOverlayView.isHidden = true
            } else {
                self?.bottomOverlayView.isHidden = false
                self?.captionLabel.text = photo.attributedTitle!.string
            }
        })
    }
    
    func addCaption(_ caption: String) {
        if caption == "" {
            bottomOverlayView.isHidden = true
        } else {
            bottomOverlayView.isHidden = false
            captionLabel.text = caption
        }
    }
}
