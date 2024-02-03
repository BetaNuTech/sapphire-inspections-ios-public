//
//  LocalDeficientItemImage
//  Sapphire Inspections
//
//  Created by Stu Carney on 4/29/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import Foundation
import RealmSwift

class LocalDeficientItemImage: Object {
    
// Specify properties to ignore (Realm won't persist these)
    
//  override static func ignoredProperties() -> [String] {
//    return []
//  }
    
    override class func primaryKey() -> String? {
        return "key"
    }
    
    // Where it needs to be uploaded to in FIRStorage
    @objc dynamic var key = "" // auto-id
    
    // database properties
    @objc dynamic var startDate: Date? = nil
    @objc dynamic var createdAt: Date? = nil
    @objc dynamic var user = ""
    @objc dynamic var caption = ""
    @objc dynamic var storageDBPath = ""
    @objc dynamic var downloadURL = ""
    
    // ref properties
    @objc dynamic var propertyKey = ""
    @objc dynamic var deficientItemKey = ""
    @objc dynamic var imageSubPathToKey = "completedPhotos"
    
    // Local properties
    @objc dynamic var imageData: Data? = nil
    @objc dynamic var deleted = false
    @objc dynamic var synced = false



    
    // OLD.. now using full storageDBPath
    func storageDeficientItemImageChildRef() -> String {
        return "\(self.propertyKey)/\(self.deficientItemKey)/\(key).jpg"
    }
    
//    func databaseDeficientItemPhotosDataChildRef() -> String {
//        return "\(self.propertyKey)/\(self.deficientItemKey)/\(imageSubPathToKey)/\(key)"
//    }
}
