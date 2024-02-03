//
//  LocalDeficientImages.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 4/29/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import Foundation
import RealmSwift
import Reachability

class LocalDeficientImages {
    
    static let singleton = LocalDeficientImages()
    
    let reachability = try! Reachability()
    var isUploading = false
    
    deinit {
        reachability.stopNotifier()
    }
    
    // Image for a specific Inspection and Item, that still need to be uploaded
    class func localDeficientItemImages(propertyKey: String, deficientItemKey: String) -> Results<LocalDeficientItemImage> {
        let realm = try! Realm()
        
        return realm.objects(LocalDeficientItemImage.self).filter("propertyKey == '\(propertyKey)' AND deficientItemKey == '\(deficientItemKey)' AND deleted == false")
    }
    
    class func localDeficientItemImagesSynced(propertyKey: String, deficientItemKey: String) -> Results<LocalDeficientItemImage> {
        let realm = try! Realm()
        
        return realm.objects(LocalDeficientItemImage.self).filter("propertyKey == '\(propertyKey)' AND deficientItemKey == '\(deficientItemKey)' AND deleted == false AND synced == true")
    }
    
    class func localDeficientItemImagesDeletedSynced(propertyKey: String, deficientItemKey: String) -> Results<LocalDeficientItemImage> {
        let realm = try! Realm()
        
        return realm.objects(LocalDeficientItemImage.self).filter("propertyKey == '\(propertyKey)' AND deficientItemKey == '\(deficientItemKey)' AND deleted == true AND synced == true")
    }
    
    class func localDeficientItemImage(propertyKey: String, deficientItemKey: String, key: String) -> LocalDeficientItemImage? {
        let realm = try! Realm()
        
        return realm.objects(LocalDeficientItemImage.self).filter("propertyKey == '\(propertyKey)' AND deficientItemKey == '\(deficientItemKey)' AND key == '\(key)'").first
    }
    
    class func localImagesNotDeletedNotSynced() -> Results<LocalDeficientItemImage> {
        let realm = try! Realm()
        
        return realm.objects(LocalDeficientItemImage.self).filter("deleted == false AND synced == false")
    }

    class func addImage(imageObject: LocalDeficientItemImage) {
        let realm = try! Realm()
        
        try! realm.write {
            realm.add(imageObject, update: .modified)
        }
    }
    
    class func addImages(imageObjects: [LocalDeficientItemImage]) {
        let realm = try! Realm()
        
        try! realm.write {
            realm.add(imageObjects, update: .modified)
        }
    }
    
    class func deleteImage(imageObject: LocalDeficientItemImage) {
        let realm = try! Realm()
        
        try! realm.write {
            imageObject.deleted = true
        }
    }
    
    class func removeSyncedImages() {
        let realm = try! Realm()
        
        let syncedImages = realm.objects(LocalDeficientItemImage.self).filter("synced == true")
        if syncedImages.count > 0 {
            try! realm.write {
                realm.delete(syncedImages)
            }
        }
        
    }
    
    func setup() {
        // Flush synced objects
        LocalDeficientImages.removeSyncedImages()
        
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
        if let imageToSync = realm.objects(LocalDeficientItemImage.self).filter("synced == false").first {
            // If Image needs to be deleted
            if imageToSync.deleted {
                let imageRef = storageDeficientItemImagesRef.child(imageToSync.storageDeficientItemImageChildRef())
                imageRef.delete(completion: { [unowned self] (error) in
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
                        
                        dbDocumentDeficientItemWith(documentId: imageToSync.deficientItemKey).setData([
                            "updatedAt" : NSNumber(value: Date().timeIntervalSince1970),
                            imageToSync.imageSubPathToKey: [ imageToSync.key: FieldValue.delete() ]
                        ], merge: true)
                        print("Image sync (remove) complete")
                        
                        try! realm.write {
                            imageToSync.synced = true
                        }
                        self.syncOne()
                    })
                })
            } else { // If Image needs to be uploaded
                let imageRef = storageDeficientItemImagesRef.child(imageToSync.storageDeficientItemImageChildRef())
                
                if let imageData = imageToSync.imageData {
                    imageRef.putData(imageData, metadata: nil) { [unowned self] metadata, error in
                        DispatchQueue.main.async(execute: { () -> Void in
                            if (error != nil) {
                                if Auth.auth().currentUser != nil && self.reachability.connection != .unavailable {
                                    print("Image Sync Error: \(error!)")
                                    LocalDeficientImages.deleteImage(imageObject: imageToSync)
                                    self.syncOne()
                                } else {
                                    self.isUploading = false
                                }
                                print("Error occurred when syncing image")
                            } else {
                                storageDeficientItemImagesRef.child(imageToSync.storageDeficientItemImageChildRef()).downloadURL(completion: { (downloadURL, error) in
                                    
                                    guard error == nil, let downloadURL = downloadURL else {
                                        if Auth.auth().currentUser != nil && self.reachability.connection != .unavailable {
                                            print("Image Sync Error: \(error!)")
                                            LocalDeficientImages.deleteImage(imageObject: imageToSync)
                                            self.syncOne()
                                        } else {
                                            self.isUploading = false
                                        }
                                        print("Error occurred when syncing image")
                                        return
                                    }
                                    
                                    let photoData: [String : AnyObject] = ["downloadURL" : "\(downloadURL.absoluteString)" as NSString,
                                                                           "caption" : imageToSync.caption as NSString,
                                                                           "user" : imageToSync.user as NSString,
                                                                           "storageDBPath" : imageToSync.storageDBPath as NSString,
                                                                           "startDate" : (imageToSync.startDate?.timeIntervalSince1970 ?? 0) as NSNumber,
                                                                           "createdAt" : (imageToSync.createdAt?.timeIntervalSince1970 ?? 0) as NSNumber]
                                    dbDocumentDeficientItemWith(documentId: imageToSync.deficientItemKey).setData([
                                        "updatedAt" : NSNumber(value: Date().timeIntervalSince1970),
                                        imageToSync.imageSubPathToKey: [ imageToSync.key: photoData ]
                                    ], merge: true) { (error) in
                                        DispatchQueue.main.async(execute: { () -> Void in
                                            if (error != nil) {
                                                if Auth.auth().currentUser != nil && self.reachability.connection != .unavailable {
                                                    print("Image Sync Error: \(error!)")
                                                    LocalDeficientImages.deleteImage(imageObject: imageToSync)
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
                    LocalDeficientImages.deleteImage(imageObject: imageToSync)
                    syncOne()
                }
            }
        } else {
            isUploading = false
        }
    }
}
