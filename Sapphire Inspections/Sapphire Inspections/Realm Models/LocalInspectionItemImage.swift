//
//  LocalInspectionItemImage
//  Sapphire Inspections
//
//  Created by Stu Carney on 9/11/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import Foundation
import RealmSwift

class LocalInspectionItemImage: Object {
    
// Specify properties to ignore (Realm won't persist these)
    
//  override static func ignoredProperties() -> [String] {
//    return []
//  }
    
    override class func primaryKey() -> String? {
        return "key"
    }
    
    // Where it needs to be uploaded to in FIRStorage
    @objc dynamic var key = "" // timestamp, unix time
    
    // Unique properties, for saving to FIRDatabase
    @objc dynamic var inspectionKey = ""
    @objc dynamic var itemKey = ""
    @objc dynamic var imageData: Data? = nil
    @objc dynamic var caption = ""
    @objc dynamic var deleted = false
    @objc dynamic var synced = false
    @objc dynamic var downloadURL = ""
    
    @objc dynamic var isSignature = false
    
    
    func storageInspectionItemImageChildRef() -> String {
        return "\(self.inspectionKey)/\(self.itemKey)/\(key).jpg"
    }
    
    func databaseInspectionItemPhotosDataChildRef() -> String {
        return "\(self.inspectionKey)/template/items/\(self.itemKey)/photosData/\(key)"
    }
    
    func databaseInspectionItemChildRef() -> String {
        return "\(self.inspectionKey)/template/items/\(self.itemKey)"
    }
    
    func databaseInspectionChildRef() -> String {
        return "\(self.inspectionKey)"
    }
}
