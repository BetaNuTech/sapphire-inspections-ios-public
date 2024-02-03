//
//  Notification.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 9/19/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import ObjectMapper

class NotificationModel: Mappable {
        
    var title: String = ""
    var summary: String = ""
    var markdownBody: String?
    var property: String?
    var creator: String = ""
    var userAgent: String = "iOS"

    required init?(map: Map) {
        
    }
    
    // Mappable
    func mapping(map: Map) {
        title          <- map["title"]
        summary        <- map["summary"]
        markdownBody   <- map["markdownBody"]
        property       <- map["property"]
        creator        <- map["creator"]
        userAgent      <- map["userAgent"]
    }
}
