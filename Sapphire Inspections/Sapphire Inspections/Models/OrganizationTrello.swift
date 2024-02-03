//
//  OrganizationTrello.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 8/29/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import ObjectMapper

class OrganizationTrello: Mappable {
        
    var createdAt: Date?
    var updatedAt: Date?
    var trelloMemberId: String = ""
    var trelloUsername: String = ""
    var trelloEmail: String?
    var trelloFullName: String?

    required init?(map: Map) {
        
    }
    
    // Mappable
    func mapping(map: Map) {
        createdAt       <- (map["createdAt"], DateTransform())
        updatedAt       <- (map["updatedAt"], DateTransform())
        trelloMemberId  <- map["member"]
        trelloUsername  <- map["trelloUsername"]
        trelloEmail     <- map["trelloEmail"]
        trelloFullName  <- map["trelloFullName"]
    }
}
