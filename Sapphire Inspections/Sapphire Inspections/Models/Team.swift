//
//  Team.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 5/29/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import ObjectMapper

class Team: Mappable {
    var name: String?
    
    // Read Only: Updated by Backend
    var properties: [String : AnyObject] = [:]

    
    // For use with partial updates to database
    class func updateJSONToExcludeReadOnlyValues(json: [String: Any]) -> [String: Any] {
        var updatedJSON = json
        
        updatedJSON.removeValue(forKey: "properties")
        
        return updatedJSON
    }
    
    required init?(map: Map) {
        
    }
    
    // Mappable
    func mapping(map: Map) {
        name        <- map["name"]
        properties  <- map["properties"]
    }
}
