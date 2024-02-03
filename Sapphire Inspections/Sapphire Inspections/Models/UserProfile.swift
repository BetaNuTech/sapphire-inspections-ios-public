//
//  User.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 7/24/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import ObjectMapper

class UserProfile: Mappable {
    var firstName: String?
    var lastName: String?
    var email: String?
    var pushOptOut: Bool = false
    var lastSignInDate: Date?
    var lastUserAgent: String?

    // Read Only: Updated by Backend
    var admin: Bool = false
    var corporate: Bool = false
    var properties: [String : AnyObject] = [:]
    var teams: [String : AnyObject] = [:]
    var isDisabled: Bool = false
    var isDeleted: Bool = false
    var isTestUser: Bool = false
    
    // For use with partial updates to database
    class func updateJSONToExcludeReadOnlyValues(json: [String: Any]) -> [String: Any] {
        var updatedJSON = json
        
        updatedJSON.removeValue(forKey: "admin")
        updatedJSON.removeValue(forKey: "corporate")
        updatedJSON.removeValue(forKey: "properties")
        updatedJSON.removeValue(forKey: "teams")
        updatedJSON.removeValue(forKey: "isDisabled")
        updatedJSON.removeValue(forKey: "isDeleted")
        updatedJSON.removeValue(forKey: "isTestUser")
        
        return updatedJSON
    }

    required init?(map: Map) {
        
    }
    
    // Mappable
    func mapping(map: Map) {
        firstName   <- map["firstName"]
        lastName    <- map["lastName"]
        email       <- map["email"]
        admin       <- map["admin"]
        corporate   <- map["corporate"]
        properties  <- map["properties"]
        teams       <- map["teams"]
        isDeleted   <- map["isDeleted"]
        isDisabled  <- map["isDisabled"]
        isTestUser  <- map["isTestUser"]
        pushOptOut  <- map["pushOptOut"]
        lastSignInDate <- (map["lastSignInDate"], DateTransform())
        lastUserAgent  <- map["lastUserAgent"]
    }

}
