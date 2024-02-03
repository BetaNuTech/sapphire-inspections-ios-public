//
//  AdminEdit.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 2/24/17.
//  Copyright © 2017 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import ObjectMapper

class AdminEdit: Mappable {
    var editDate: Date?
    var adminUserId = ""
    var adminName = ""
    var action = ""
    
    required init?(map: Map) {
        
    }
    
    // Mappable
    func mapping(map: Map) {
        editDate   <- (map["edit_date"], DateTransform())
        adminUserId  <- map["admin_uid"]
        adminName  <- map["admin_name"]
        action     <- map["action"]
    }
}
