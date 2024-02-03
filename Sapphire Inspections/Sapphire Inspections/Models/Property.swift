//
//  Property.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 7/29/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import ObjectMapper

class Property: Mappable {
    var name: String?
    var addr1: String?
    var addr2: String?
    var city: String?
    var state: String?
    var zip: String?
    var photoURL: String?
    var bannerPhotoURL: String?
    var logoPhotoURL: String? // Replacing bannerPhotoURL
    var photoName: String?
    var bannerPhotoName: String?
    var logoName: String? // Replacing bannerPhotoName
    var year_built: Int?
    var num_of_units: Int?
    var manager_name: String?
    var maint_super_name: String?
    var loan_type: String?
    var templates: [String : AnyObject] = [:]
    var code: String?
    var slackChannel: String?
    var team: String?

    // Read Only: Updated by Backend
    var lastInspectionDate: Date?
    var lastInspectionScore: Float?
    var numOfInspections: UInt = 0
    var numOfDeficientItems: UInt = 0
    var numOfRequiredActionsForDeficientItems: UInt = 0
    var numOfFollowUpActionsForDeficientItems: UInt = 0

    // For use with partial updates to database
    class func updateJSONToExcludeReadOnlyValues(json: [String: Any]) -> [String: Any] {
        var updatedJSON = json
        
        updatedJSON.removeValue(forKey: "lastInspectionDate")
        updatedJSON.removeValue(forKey: "lastInspectionScore")
        updatedJSON.removeValue(forKey: "numOfInspections")
        updatedJSON.removeValue(forKey: "numOfDeficientItems")
        updatedJSON.removeValue(forKey: "numOfRequiredActionsForDeficientItems")
        updatedJSON.removeValue(forKey: "numOfFollowUpActionsForDeficientItems")
        
        return updatedJSON
    }
    
    required init?(map: Map) {
        
    }
    
    // Mappable
    func mapping(map: Map) {
        name   <- map["name"]
        addr1    <- map["addr1"]
        addr2    <- map["addr2"]
        city       <- map["city"]
        state       <- map["state"]
        zip         <- map["zip"]
        photoURL  <- map["photoURL"]
        bannerPhotoURL  <- map["bannerPhotoURL"]
        logoPhotoURL  <- map["logoPhotoURL"]
        photoName  <- map["photoName"]
        logoName  <- map["logoName"]
        bannerPhotoName  <- map["bannerPhotoName"]
        year_built  <- map["year_built"]
        num_of_units  <- map["num_of_units"]
        manager_name  <- map["manager_name"]
        maint_super_name  <- map["maint_super_name"]
        loan_type  <- map["loan_type"]
        templates  <- map["templates"]
        code            <- map["code"]
        slackChannel    <- map["slackChannel"]
        team   <- map["team"]
        
        lastInspectionDate    <- (map["lastInspectionDate"], DateTransform())
        lastInspectionScore  <- map["lastInspectionScore"]
        numOfInspections  <- map["numOfInspections"]
        numOfDeficientItems    <- map["numOfDeficientItems"]
        numOfRequiredActionsForDeficientItems    <- map["numOfRequiredActionsForDeficientItems"]
        numOfFollowUpActionsForDeficientItems    <- map["numOfFollowUpActionsForDeficientItems"]
    }
}
