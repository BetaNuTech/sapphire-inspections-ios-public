//
//  TrelloUser.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 8/9/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import ObjectMapper

class TrelloUser: Mappable {
    var fullName = ""
    var trelloUsername = ""
    var trelloMemberId = ""
    var email: String?

    required init?(map: Map) {
        
    }
    
    // Mappable
    func mapping(map: Map) {
        fullName      <- map["fullName"]
        trelloUsername <- map["trelloUsername"]
        trelloMemberId <- map["trelloMemberId"]
        email          <- map["email"]
    }
}
