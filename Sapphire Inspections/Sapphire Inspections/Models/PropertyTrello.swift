//
//  PropertyTrello.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 8/13/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import ObjectMapper

class PropertyTrello: Mappable {
        
    var grantedBy: String?
    var grantedAt: Date?
    var openBoard: String?
    var openBoardName: String?
    var closedBoard: String?
    var closedBoardName: String?
    var openList: String?
    var openListName: String?
    var closedList: String?
    var closedListName: String?

    required init?(map: Map) {
        
    }
    
    // Mappable
    func mapping(map: Map) {
        grantedBy       <- map["grantedBy"]
        grantedAt       <- (map["grantedAt"], DateTransform())
        openBoard       <- map["openBoard"]
        openBoardName   <- map["openBoardName"]
        closedBoard     <- map["closedBoard"]
        closedBoardName <- map["closedBoardName"]
        openList       <- map["openList"]
        openListName   <- map["openListName"]
        closedList     <- map["closedList"]
        closedListName <- map["closedListName"]
    }
}
