//
//  LocalInspectionImages.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 9/12/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import Foundation
import RealmSwift
import Reachability

class LocalInspectionImages {
    
    static let singleton = LocalInspectionImages()
    
    let reachability = try! Reachability()
    var isUploading = false
    
    deinit {
        reachability.stopNotifier()
    }
    
    // Image for a specific Inspection and Item, that still need to be uploaded
    class func localInspectionItemImages(inspectionKey: String, itemKey: String) -> Results<LocalInspectionItemImage> {
        let realm = try! Realm()
        
        return realm.objects(LocalInspectionItemImage.self).filter("inspectionKey == '\(inspectionKey)' AND itemKey == '\(itemKey)' AND deleted == false")
    }
    
    class func localInspectionItemImagesSynced(inspectionKey: String, itemKey: String) -> Results<LocalInspectionItemImage> {
        let realm = try! Realm()
        
        return realm.objects(LocalInspectionItemImage.self).filter("inspectionKey == '\(inspectionKey)' AND itemKey == '\(itemKey)' AND deleted == false AND synced == true")
    }
    
    class func localInspectionItemImagesDeletedSynced(inspectionKey: String, itemKey: String) -> Results<LocalInspectionItemImage> {
        let realm = try! Realm()
        
        return realm.objects(LocalInspectionItemImage.self).filter("inspectionKey == '\(inspectionKey)' AND itemKey == '\(itemKey)' AND deleted == true AND synced == true")
    }
    
    class func localInspectionItemImage(inspectionKey: String, itemKey: String, key: String) -> LocalInspectionItemImage? {
        let realm = try! Realm()
        
        return realm.objects(LocalInspectionItemImage.self).filter("inspectionKey == '\(inspectionKey)' AND itemKey == '\(itemKey)' AND key == '\(key)'").first
    }
    
    class func localImagesNotDeletedNotSynced() -> Results<LocalInspectionItemImage> {
        let realm = try! Realm()
        
        return realm.objects(LocalInspectionItemImage.self).filter("deleted == false AND synced == false")
    }

    class func addImage(imageObject: LocalInspectionItemImage) {
        let realm = try! Realm()
        
        try! realm.write {
            realm.add(imageObject, update: .modified)
        }
    }
    
    class func addImages(imageObjects: [LocalInspectionItemImage]) {
        let realm = try! Realm()
        
        try! realm.write {
            realm.add(imageObjects, update: .modified)
        }
    }
    
    class func deleteImage(imageObject: LocalInspectionItemImage) {
        let realm = try! Realm()
        
        try! realm.write {
            imageObject.deleted = true
        }
    }
    
    class func removeSyncedImages() {
        let realm = try! Realm()
        
        let syncedImages = realm.objects(LocalInspectionItemImage.self).filter("synced == true")
        if syncedImages.count > 0 {
            try! realm.write {
                realm.delete(syncedImages)
            }
        }
        
    }
    
    func setup() {
        // Flush synced objects
        LocalInspectionImages.removeSyncedImages()
        
        reachability.whenReachable = { reachability in
            // this is called on a background thread, but UI updates must
            // be on the main thread, like this:
            DispatchQueue.main.async(execute: { () -> Void in
                if self.reachability.connection == .wifi {
                    print("Reachable via WiFi")
                } else {
                    print("Reachable via Cellular")
                }
                
                if (!pauseUploadingPhotos) {
                    self.startSyncing()
                }
            })
        }
        reachability.whenUnreachable = { reachability in
            // this is called on a background thread, but UI updates must
            // be on the main thread, like this:
            DispatchQueue.main.async(execute: { () -> Void in
                print("Not reachable")
            })
        }
        
        do {
            try reachability.startNotifier()
        } catch {
            print("Unable to start notifier")
        }        
    }
    
    func startSyncing() {
        // notificationCenter.post(name: Notification.Name(rawValue: ImageUploader_ChangedNotification), object:self)
        if isUploading || Auth.auth().currentUser == nil {
            return
        } else if reachability.connection != .unavailable {
            isUploading = true
            syncOne()
        }
    }
    
    func syncOne() {
        let realm = try! Realm()
        if let imageToSync = realm.objects(LocalInspectionItemImage.self).filter("synced == false").first {
            // If Image needs to be deleted
            if imageToSync.deleted {
                let imageRef = storageInspectionItemImagesRef.child(imageToSync.storageInspectionItemImageChildRef())
                imageRef.delete(completion: { (error) in
                    DispatchQueue.main.async(execute: { () -> Void in
                        let realm = try! Realm()

                        if (error != nil) {
                            if Auth.auth().currentUser != nil && self.reachability.connection != .unavailable {
                                try! realm.write {
                                    realm.delete(imageToSync)
                                }
                            } else {
                                self.isUploading = false
                            }
                            print("Error occurred when syncing image")
                            return
                        }
                        
                        dbDocumentInspectionWith(documentId: imageToSync.inspectionKey).setData([
                            "updatedAt" : NSNumber(value: Date().timeIntervalSince1970),
                            "template": [
                                "items": [
                                    imageToSync.itemKey: [
                                        "photosData": [ imageToSync.key: FieldValue.delete() ]
                                    ]
                                ]
                            ]
                        ], merge: true)
                        
                        print("Image sync (remove) complete")
                        
                        try! realm.write {
                            imageToSync.synced = true
                        }
                        self.syncOne()
                    })
                })
            } else { // If Image needs to be uploaded
                let imageRef = storageInspectionItemImagesRef.child(imageToSync.storageInspectionItemImageChildRef())
                
                if let imageData = imageToSync.imageData {
                    imageRef.putData(imageData, metadata: nil) { metadata, error in
                        DispatchQueue.main.async(execute: { () -> Void in
                            if (error != nil) {
                                if Auth.auth().currentUser != nil && self.reachability.connection != .unavailable {
                                    print("Image Sync Error: \(error!)")
                                    LocalInspectionImages.deleteImage(imageObject: imageToSync)
                                    self.syncOne()
                                } else {
                                    self.isUploading = false
                                }
                                print("Error occurred when syncing image")
                            } else {
                                storageInspectionItemImagesRef.child(imageToSync.storageInspectionItemImageChildRef()).downloadURL(completion: { (downloadURL, error) in
                                    
                                    guard error == nil, let downloadURL = downloadURL else {
                                        if Auth.auth().currentUser != nil && self.reachability.connection != .unavailable {
                                            print("Image Sync Error: \(error!)")
                                            LocalInspectionImages.deleteImage(imageObject: imageToSync)
                                            self.syncOne()
                                        } else {
                                            self.isUploading = false
                                        }
                                        print("Error occurred when syncing image")
                                        return
                                    }
                                    
                                    var photoData: [String : Any] = [
                                        "updatedAt": NSNumber(value: Date().timeIntervalSince1970),
                                        "template": [
                                            "items": [
                                                imageToSync.itemKey: [
                                                    "photosData": [
                                                        imageToSync.key: [
                                                            "downloadURL": "\(downloadURL.absoluteString)" as NSString,
                                                            "caption": imageToSync.caption as NSString
                                                        ]
                                                    ]
                                                ]
                                            ]
                                        ]
                                    ]
                                    if imageToSync.isSignature {
                                        photoData = [
                                            "updatedAt": NSNumber(value: Date().timeIntervalSince1970),
                                            "template": [
                                                "items": [
                                                    imageToSync.itemKey: [
                                                        "signatureDownloadURL": "\(downloadURL.absoluteString)" as NSString
                                                    ]
                                                ]
                                            ]
                                        ]
                                    }
                                    dbDocumentInspectionWith(documentId: imageToSync.inspectionKey).setData(photoData, merge: true) { [unowned self] (error) in
                                        DispatchQueue.main.async(execute: { () -> Void in
                                            if (error != nil) {
                                                if Auth.auth().currentUser != nil && self.reachability.connection != .unavailable {
                                                    print("Image Sync Error: \(error!)")
                                                    LocalInspectionImages.deleteImage(imageObject: imageToSync)
                                                    self.syncOne()
                                                } else {
                                                    self.isUploading = false
                                                }
                                                print("Error occurred when syncing image")
                                            } else {
                                                print("Image sync (add) successful")
                                                let realm = try! Realm()
                                                
                                                try! realm.write {
                                                    imageToSync.synced = true
                                                    imageToSync.downloadURL = downloadURL.absoluteString
                                                }
                                                NotificationCenter.default.post(name: NSNotification.Name.OfflinePhotoUploaded, object: nil)
                                                self.syncOne()
                                            }
                                        })
                                    }
                                })

                            }
                        })
                        
                    }
                } else {
                    LocalInspectionImages.deleteImage(imageObject: imageToSync)
                    syncOne()
                }
            }
        } else {
            isUploading = false
        }
    }
}
