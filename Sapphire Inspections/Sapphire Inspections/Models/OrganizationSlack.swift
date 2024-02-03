//
//  OrganizationSlack.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 9/3/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import ObjectMapper

class OrganizationSlack: Mappable {
        
    var createdAt: Date?
    var updatedAt: Date?
    var defaultChannelName: String?
    var teamId: String?
    var teamName: String?
    var joinedChannelNames: [String: AnyObject]?

    required init?(map: Map) {
        
    }
    
    // Mappable
    func mapping(map: Map) {
        createdAt          <- (map["createdAt"], DateTransform())
        updatedAt          <- (map["updatedAt"], DateTransform())
        defaultChannelName <- map["defaultChannelName"]
        teamId             <- map["team"]
        teamName           <- map["teamName"]
        joinedChannelNames <- map["joinedChannelNames"]
    }
}
