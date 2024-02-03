//
//  DeficientItemGalleryVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 4/29/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import RealmSwift
import SwiftyJSON

protocol DeficientItemGalleryVCDelegate: class {
    func updatedPhotosData(photosData: JSON)
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


class DeficientItemGalleryVC: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, ImagePickerDelegate {
    
    typealias StartDatePhotos = (startDate: Date, photos: [GalleryPhotoModel])

    @IBOutlet weak var itemTitle: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBOutlet weak var doneButton: UIBarButtonItem!
    
    var readOnly = true
    var titleText = ""
    weak var delegate: DeficientItemGalleryVCDelegate?

    var startDatePhotos: [StartDatePhotos] = []
    var offlineImagesToAdd: [LocalDeficientItemImage] = []
    var captions: [String] = []
    
    var imagesToUpload: [UIImage] = []
    
    // Deficient Item - REQUIRED
    var keyProperty: KeyProperty?
    var keyDeficientItem: keyInspectionDeficientItem?
    var startDate: Date?
    var photosData: JSON = JSON([:])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        itemTitle.text = titleText
        
        addButton.isEnabled = !readOnly
    
        refreshPhotos()
        
        if !readOnly {
            if startDatePhotos.count == 0 {
                addButtonTapped(addButton)
            } else if let first = startDatePhotos.first, first.photos.count == 0 {
                addButtonTapped(addButton)
            }
        }
    }
    
    func allowedToCloseView() -> Bool {
        // Photo(s) required for completed DIs
        if readOnly {
            return true
        } else if let first = startDatePhotos.first, first.photos.count > 0 {
            delegate?.updatedPhotosData(photosData: photosData)  // Just to ensure new photo(s) goes through on exit, for any previous save issues.
            return true
        } else {
            return false
        }
    }
    
//    func addDoneButton() {
//        navigationItem.leftBarButtonItems = [doneButton]
//    }
//
//    func removeDoneButton() {
//        navigationItem.leftBarButtonItems = []
//    }
    
    func refreshPhotos() {
        guard let keyProperty = keyProperty, let keyDeficientItem = keyDeficientItem else {
            print("keyProperty and/or keyDeficientItem is/are nil")
            return
        }
        
        var allPhotos: [GalleryPhotoModel] = []
        for (key, json) in photosData.dictionaryValue {
            if let downloadURL = json["downloadURL"].string {
                let caption = json["caption"].stringValue
                let photoStartDate = Date(timeIntervalSince1970: json["startDate"].doubleValue)
                let photo = GalleryPhotoModel()
                photo.itemPhotoDataKey = key
                photo.startDate = photoStartDate
                if downloadURL == "" {
                    if let localImage = LocalDeficientImages.localDeficientItemImage(propertyKey: keyProperty.key, deficientItemKey: keyDeficientItem.key, key: key) {
                        print("Loaded offline photo with key=\(key)")
                        photo.image = UIImage(data: localImage.imageData!)
                        photo.thumbnailImage = UIImage(data: localImage.imageData!)
                    }
                }
                photo.imageURL = URL(string: downloadURL)
                photo.thumbnailImageURL = URL(string: downloadURL)
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor.white
                ]
                photo.attributedTitle = NSAttributedString(string: caption, attributes: attributes)
                
                allPhotos.append(photo)
            }
        }
        
        var newStartDatePhotos: [StartDatePhotos] = []
        var photos: [GalleryPhotoModel] = []
        var currentStartDate = startDate
        allPhotos.sort(by: { $0.startDate?.timeIntervalSince1970 ?? 0 > $1.startDate?.timeIntervalSince1970 ?? 0 })
        for photo in allPhotos {
            let photoStartDate = photo.startDate
            if currentStartDate?.timeIntervalSince1970 != photoStartDate?.timeIntervalSince1970 {
                photos.sort(by: { $0.itemPhotoDataKey < $1.itemPhotoDataKey })
                newStartDatePhotos.append((currentStartDate!, photos))
                currentStartDate = photoStartDate
                photos = []
            }
            
            photos.append(photo)
        }
        if photos.count > 0 && currentStartDate != nil {
            photos.sort(by: { $0.itemPhotoDataKey < $1.itemPhotoDataKey })
            newStartDatePhotos.append((currentStartDate!, photos))
        }
        
        startDatePhotos = newStartDatePhotos
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
    
    // MARK: Actions
    
    @IBAction func addButtonTapped(_ sender: AnyObject) {
        let imagePickerController = ImagePickerController()
        imagePickerController.modalPresentationStyle = .fullScreen
        imagePickerController.delegate = self
        present(imagePickerController, animated: true, completion: nil)
    }
    
    @IBAction func doneButtonTapped(_ sender: Any) {
        if allowedToCloseView() {
            navigationController?.popViewController(animated: true)
        } else {
            alertForNoPhotos()
        }
    }
    
    @IBAction func longPress(_ sender: UILongPressGestureRecognizer) {
        if (sender.state != UIGestureRecognizer.State.began || readOnly) {
            return
        }
        
        let p = sender.location(in: self.collectionView)
        
        if let indexPath = (self.collectionView?.indexPathForItem(at: p)) {
            // Ignore any edits to previously saved images
            if indexPath.section != 0 {
                return
            }
            alertForCaptionUpdateOrDelete(indexPath)
        }
    }
    
    // MARK: - UICollectionView
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return startDatePhotos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        let sectionHeader = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeader", for: indexPath) as! GallerySectionHeaderView
        
        if indexPath.section == 0 && !readOnly {
            sectionHeader.sectionTitleLabel.text = "NEW Completed Photo(s)"
        } else {
            let startDate = startDatePhotos[indexPath.section].startDate
            let formatter = DateFormatter()
            formatter.dateStyle = DateFormatter.Style.medium
            formatter.timeStyle = DateFormatter.Style.short
            sectionHeader.sectionTitleLabel.text = "COMPLETED: \(formatter.string(from: startDate))"
        }
        
        return sectionHeader
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return startDatePhotos[section].photos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "imageCell", for: indexPath) as! GalleryImageCell
        
        cell.populateWithPhoto(startDatePhotos[indexPath.section].photos[(indexPath as NSIndexPath).row])
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
        let currentPhoto = startDatePhotos[indexPath.section].photos[(indexPath as NSIndexPath).row]
        let galleryPreview = INSPhotosViewController(photos: startDatePhotos[indexPath.section].photos, initialPhoto: currentPhoto, referenceView: cell)
        
        galleryPreview.referenceViewForPhotoWhenDismissingHandler = { [weak self] photo in
            if let index = self?.startDatePhotos[indexPath.section].photos.index(where: {$0 === photo}) {
                let indexPath = IndexPath(item: index, section: indexPath.section)
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
            DispatchQueue.main.async(execute: { () -> Void in
                self.alertForEnterPhotoCaption(images)
            })
        }
    }
    
    func cancelButtonDidPress(_ imagePicker: ImagePickerController) {
        print("Cancel Button Did Press")
        dismiss(animated: true)
    }
    
    // MARK: Uploading
    
    func updateNextImage(_ caption: String) {
        guard let keyProperty = keyProperty, let keyDeficientItem = keyDeficientItem, let startDate = startDate else {
            print("updateNextImage: keyProperty, keyDeficientItem, and/or startDate is/are nil")
            return
        }
        let newImageKey = dbCollectionDeficiencies().document().documentID
        
        if imagesToUpload.count > 0 {
            let image = imagesToUpload.removeFirst()
            if let imageData = image.jpegData(compressionQuality: 0.5) {
                let createdAt = Date()

                let imageRef = storageDeficientItemImagesRef.child("\(keyProperty.key)/\(keyDeficientItem.key)/\(newImageKey).jpg")
                
                let newLocalImage = LocalDeficientItemImage()
                newLocalImage.key = newImageKey
                newLocalImage.user = currentUser?.uid ?? ""
                newLocalImage.imageData = imageData
                newLocalImage.caption = caption
                newLocalImage.propertyKey = keyProperty.key
                newLocalImage.deficientItemKey = keyDeficientItem.key
                newLocalImage.createdAt = createdAt
                newLocalImage.startDate = startDate
                newLocalImage.storageDBPath = imageRef.fullPath
                
                var photoData: [String : AnyObject] = ["downloadURL" : "" as NSString,
                                                       "caption" : caption as NSString,
                                                       "user" : (currentUser?.uid ?? "") as NSString,
                                                       "storageDBPath" : imageRef.fullPath as NSString,
                                                       "startDate" : startDate.timeIntervalSince1970 as NSNumber,
                                                       "createdAt" : createdAt.timeIntervalSince1970 as NSNumber]

                if FIRConnection.connected() {
                    // Upload the file using the property key as the image name
                    imageRef.putData(imageData, metadata: nil) { metadata, error in
                        DispatchQueue.main.async(execute: { [weak self] () -> Void in
                            guard let weakSelf = self else {
                                print("ERROR: imageRef.putData, self is nil")
                                return
                            }
                            
                            if (error != nil) {
                                weakSelf.photosData[newImageKey] = JSON(photoData)
                                print(newImageKey)
                                print(weakSelf.photosData)
                                weakSelf.offlineImagesToAdd.append(newLocalImage)
                                print("Added offline photo")
//                                self.delegate?.galleryUpdated(item: keyItem.item, action: "added photo with filename: \(timestamp).jpg, and caption: \"\(caption)\"", binaryUpdate: true)
                                weakSelf.delegate?.updatedPhotosData(photosData: weakSelf.photosData)
                                weakSelf.updateNextImage(caption)
                            } else {
                                imageRef.downloadURL(completion: { [weak self] (downloadURL, error) in
                                    
                                    guard error == nil, let downloadURL = downloadURL else {
                                        DispatchQueue.main.async(execute: { [weak self] () -> Void in
                                            self?.showMessagePrompt("Error occurred when saving image")
                                            self?.updateNextImage(caption)
                                        })
                                        return
                                    }
                                    
                                    photoData["downloadURL"] = "\(downloadURL.absoluteString)" as NSString
                                    weakSelf.photosData[newImageKey] = JSON(photoData)
                                    weakSelf.delegate?.updatedPhotosData(photosData: weakSelf.photosData)
//                                    weakSelf.delegate?.galleryUpdated(item: keyItem.item, action: "added photo with filename: \(timestamp).jpg, and caption: \"\(caption)\"", binaryUpdate: true)
                                    weakSelf.updateNextImage(caption)
                                })
                            }
                        })
                    }
                } else {
                    photosData[newImageKey] = JSON(photoData)
                    delegate?.updatedPhotosData(photosData: photosData)
                    print(newImageKey)
                    print(photosData)
                    offlineImagesToAdd.append(newLocalImage)
                    print("Added offline photo")
//                    self.delegate?.galleryUpdated(item: keyItem.item, action: "added photo with filename: \(timestamp).jpg, and caption: \"\(caption)\"", binaryUpdate: true)
                    self.updateNextImage(caption)
                }
            } else {
                DispatchQueue.main.async(execute: { () -> Void in
                    self.showMessagePrompt("Error occurred when creating image data")
                    self.updateNextImage(caption)
                })
            }
        } else {
            if offlineImagesToAdd.count > 0 {
                LocalDeficientImages.addImages(imageObjects: offlineImagesToAdd)
                offlineImagesToAdd.removeAll()
            }

            self.refreshPhotos()
            SVProgressHUD.dismiss()
        }
    }

    // MARK: Alerts
    
    func alertForNoPhotos() {
        let alertController = UIAlertController(title: "At least one photo required", message: nil, preferredStyle: .alert)
        let okayAction = UIAlertAction(title: NSLocalizedString("OKAY", comment: "OKAY action"), style: .cancel, handler: { (action) in
            print("OKAY Action")
        })
        
        alertController.addAction(okayAction)
        
        present(alertController, animated: true, completion: {})
    }
    
    func alertForCaptionUpdateOrDelete(_ indexPath: IndexPath) {
        let alertController = UIAlertController(title: "Photo Options", message: nil, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel action"), style: .cancel, handler: { (action) in
            print("Cancel Action")
        })
        let captionAction = UIAlertAction(title: "CAPTION", style: .default) { [weak self] (action) -> Void in
            if let photo = self?.startDatePhotos[indexPath.section].photos[(indexPath as NSIndexPath).row] {
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
        guard let keyProperty = keyProperty, let keyDeficientItem = keyDeficientItem else {
            print("alertForDeletingImage: keyProperty and/or keyDeficientItem is/are nil")
            return
        }
        
        let alertController = UIAlertController(title: "Are you sure you want to delete this image?", message: nil, preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel action"), style: .cancel, handler: { (action) in
            print("Cancel Action")
        })
        let deleteAction = UIAlertAction(title: NSLocalizedString("DELETE", comment: "Delete Action"), style: .destructive, handler: { (action) in
            DispatchQueue.main.async(execute: { [weak self] () -> Void in
                guard let weakSelf = self else {
                    return
                }
                
                let photo = weakSelf.startDatePhotos[indexPath.section].photos[(indexPath as NSIndexPath).row] as GalleryPhotoModel
                if let itemPhotoDataKey = photo.itemPhotoDataKey {
                    if let localImage = LocalDeficientImages.localDeficientItemImage(propertyKey: keyProperty.key, deficientItemKey: keyDeficientItem.key, key: itemPhotoDataKey) {
                        if !localImage.synced {
                            let realm = try! Realm()
                            try! realm.write {
                                realm.delete(localImage)
                            }
                            weakSelf.photosData.dictionaryObject?.removeValue(forKey: itemPhotoDataKey)
                            weakSelf.delegate?.updatedPhotosData(photosData: weakSelf.photosData)
                            weakSelf.refreshPhotos()
                        } else  {
                            let realm = try! Realm()
                            try! realm.write {
                                localImage.deleted = true
                            }
                            
                            weakSelf.photosData.dictionaryObject?.removeValue(forKey: itemPhotoDataKey)
                            weakSelf.delegate?.updatedPhotosData(photosData: weakSelf.photosData)
                            weakSelf.refreshPhotos()
                        }
                    } else {
                        let imageRef = storageDeficientItemImagesRef.child("\(keyProperty.key)/\(keyDeficientItem.key)/\(itemPhotoDataKey).jpg")
                        if FIRConnection.connected() {
                            SVProgressHUD.show(withStatus: "Deleting Photo")
                            imageRef.delete(completion: { (error) in
                                if error != nil {
                                    let newLocalImage = LocalDeficientItemImage()
                                    newLocalImage.deleted = true
                                    newLocalImage.key = itemPhotoDataKey
                                    newLocalImage.propertyKey = keyProperty.key
                                    newLocalImage.deficientItemKey = keyDeficientItem.key
                                    let realm = try! Realm()
                                    try! realm.write {
                                        realm.add(newLocalImage, update: .modified)
                                    }
                                }
                                
                                weakSelf.photosData.dictionaryObject?.removeValue(forKey: itemPhotoDataKey)
                                weakSelf.delegate?.updatedPhotosData(photosData: weakSelf.photosData)
                                weakSelf.refreshPhotos()
                                SVProgressHUD.dismiss()
                            })
                        } else {
                            weakSelf.photosData.dictionaryObject?.removeValue(forKey: itemPhotoDataKey)
                            weakSelf.delegate?.updatedPhotosData(photosData: weakSelf.photosData)
                            weakSelf.refreshPhotos()
                            SVProgressHUD.dismiss()
                        }

                    }
//                    weakSelf.delegate?.galleryUpdated(item: keyItem.item, action: "deleted photo with filename: \(itemPhotoDataKey).jpg", binaryUpdate: true)
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
        guard let keyProperty = keyProperty, let keyDeficientItem = keyDeficientItem else {
            print("alertForUpdatingPhotoCaption: keyProperty and/or keyDeficientItem is/are nil")
            return
        }
        
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
            if let itemPhotoDataKey = photo.itemPhotoDataKey {
                var photoData = weakSelf.photosData[itemPhotoDataKey]
                if photoData != JSON.null {
//                    weakSelf.delegate?.galleryUpdated(item: keyItem.item, action: "changed caption for photo with filename: \(itemPhotoDataKey).jpg from \"\(photoData!["caption"] as? String ?? "")\" to \"\(caption)\"", binaryUpdate: false)
                    photoData["caption"].string = caption
                    weakSelf.photosData[itemPhotoDataKey] = photoData
                    weakSelf.delegate?.updatedPhotosData(photosData: weakSelf.photosData)
                }
                if let localImage = LocalDeficientImages.localDeficientItemImage(propertyKey: keyProperty.key, deficientItemKey: keyDeficientItem.key, key: itemPhotoDataKey) {
                    print("Loaded offline photo with key=\(itemPhotoDataKey)")
//                    if photoData == nil { weakSelf.delegate?.galleryUpdated(item: keyItem.item, action: "changed caption for photo with filename: \(itemPhotoDataKey).jpg from \"\(localImage.caption)\" to \"\(caption)\"", binaryUpdate: false) }
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

}
