//
//  Bid.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 3/9/22.
//  Copyright © 2022 Beta Nu Technologies LLC. All rights reserved.
//

import ObjectMapper

typealias KeyBid = (key: String, bid: Bid)

enum BidState: String {
    case open = "open"
    case rejected = "rejected"
    case incomplete = "incomplete"
    case approved = "approved"
    case complete = "complete"
}

enum BidScope: String {
    case local = "local"
    case national = "national"
}

class Bid: Mappable {
    var updatedAt: Date?
    var createdAt: Date?
    
    var startAt: NSNumber?
    var completeAt: NSNumber?
    var costMax: NSNumber?
    var costMin: NSNumber?
    var scope: String?
    var state: String?
    var vendor: String?
    var vendorDetails: String?
    var vendorInsurance: Bool?
    var vendorLicense: Bool?
    var vendorW9: Bool?
    var attachments: [JobOrBidAttachment]?


    // For use with partial updates to database
    class func updateJSONToExcludeReadOnlyValues(json: [String: Any]) -> [String: Any] {
        var updatedJSON = json
        
        updatedJSON.removeValue(forKey: "updatedAt")
        updatedJSON.removeValue(forKey: "createdAt")

        return updatedJSON
    }
    
    required init?(map: Map) {
        
    }
    
    // Mappable
    func mapping(map: Map) {
        updatedAt       <- (map["updatedAt"], DateTransform())
        createdAt       <- (map["createdAt"], DateTransform())

        startAt         <- map["startAt"]
        completeAt      <- map["completeAt"]
        costMax         <- map["costMax"]
        costMin         <- map["costMin"]
        scope           <- map["scope"]
        state           <- map["state"]
        vendor          <- map["vendor"]
        vendorDetails   <- map["vendorDetails"]
        vendorInsurance <- map["vendorInsurance"]
        vendorLicense   <- map["vendorLicense"]
        vendorW9        <- map["vendorW9"]
        attachments     <- map["attachments"]

    }
}
