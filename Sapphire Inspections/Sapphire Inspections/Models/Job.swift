//
//  Job.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 7/8/21.
//  Copyright © 2021 Beta Nu Technologies LLC. All rights reserved.
//

import ObjectMapper

typealias KeyJob = (key: String, job: Job)

enum JobProjectType : String {
    case small_pm     = "small:pm"
    case small_hybrid = "small:hybrid"
    case large_am     = "large:am"
    case large_sc     = "large:sc"
}

enum JobState: String {
    case open = "open"
    case approved = "approved"
    case authorized = "authorized"
    case complete = "complete"
}

enum JobAuthorizedRule: String {
    case defaultRule = "default"
    case expediteRule = "expedite"
}


class Job: Mappable {
    var updatedAt: Date?
    var createdAt: Date?

    var title: String?
    var need: String?
    var scopeOfWork: String?
    var type: String?
    var authorizedRules: String?
    var expediteReason: String?
    var state: String?
    var trelloCardURL: String?
    var scopeOfWorkAttachments: [JobOrBidAttachment]?

    var minBids: Int?

    // For use with partial updates to database
    class func updateJSONToExcludeReadOnlyValues(json: [String: Any]) -> [String: Any] {
        var updatedJSON = json
        
        updatedJSON.removeValue(forKey: "updatedAt")
        updatedJSON.removeValue(forKey: "createdAt")
        updatedJSON.removeValue(forKey: "minBids")

        return updatedJSON
    }
    
    required init?(map: Map) {
        
    }
    
    // Mappable
    func mapping(map: Map) {
        updatedAt       <- (map["updatedAt"], DateTransform())
        createdAt       <- (map["createdAt"], DateTransform())

        title           <- map["title"]
        need            <- map["need"]
        scopeOfWork     <- map["scopeOfWork"]
        type            <- map["type"]
        authorizedRules <- map["authorizedRules"]
        expediteReason  <- map["expediteReason"]
        state           <- map["state"]
        trelloCardURL   <- map["trelloCardURL"]
        scopeOfWorkAttachments   <- map["scopeOfWorkAttachments"]

        minBids         <- map["minBids"]

    }
}
