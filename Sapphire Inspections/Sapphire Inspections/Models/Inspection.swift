//
//  Template.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 8/05/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import ObjectMapper

class Inspection: Mappable {
    var updatedAt: Date?
    var creationDate: Date?
    var deficienciesExist = false
    var inspectionCompleted = false
    var inspectionReportURL: String?
    var inspector: String?
    var inspectorName: String? // TODO: Update for name changes
    var itemsCompleted: Int = 0
    var property: String?
    var score: Double = 0
    var templateId: String?
    var template: [String: AnyObject]? // Copy of template, at time of init
    var templateName: String?
    var totalItems: Int = 0
    var updatedLastDate: Date?

    var completionDate: Date?
    var inspectionReportFilename: String?

    var migrationDate: Date?
    
    var templateCategory: String?
    
    var propertyName: String? // Not in Model
    
    // Backend, generated Inspection Reports
    var inspectionReportStatus: String?
    var inspectionReportUpdateLastDate: Date?


    required init?(map: Map) {
        
    }
    
    // Mappable
    func mapping(map: Map) {
        templateId       <- map["templateId"]
        template       <- map["template"]
        totalItems     <- map["totalItems"]
        itemsCompleted  <- map["itemsCompleted"]
        score           <- map["score"]
        inspectionCompleted <- map["inspectionCompleted"]
        deficienciesExist <- map["deficienciesExist"]
        inspector       <- map["inspector"]
        inspectorName   <- map["inspectorName"]
//        inspectorEmail  <- map["inspectorEmail"]
        creationDate    <- (map["creationDate"], DateTransform())
        updatedLastDate <- (map["updatedLastDate"], DateTransform())
        updatedAt       <- (map["updatedAt"], DateTransform())
        completionDate <- (map["completionDate"], DateTransform())
        property        <- map["property"]
        inspectionReportURL <- map["inspectionReportURL"]
        inspectionReportFilename <- map["inspectionReportFilename"]
        inspectionReportStatus    <- map["inspectionReportStatus"]
        inspectionReportUpdateLastDate <- (map["inspectionReportUpdateLastDate"], DateTransform())
        templateName <- map["templateName"]
        migrationDate    <- (map["migrationDate"], DateTransform())
        templateCategory    <- map["templateCategory"]
    }
    
    class func newKeyAndInspectionFromTemplate(_ keyTemplate: (key: String, template: Template), propertyKey: String, completion: @escaping (_ key: String, _ inspection: Inspection) -> Void) {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let newKey = dbCollectionInspections().document().documentID
            let inspection = Inspection(JSONString: "{}")!
            inspection.templateId = keyTemplate.key
            inspection.template = keyTemplate.template.toJSON() as [String : AnyObject]?
            if let currentUser = currentUser {
                inspection.inspector = currentUser.uid
            }
            if let currentUserProfile = currentUserProfile {
                inspection.inspectorName = "\(currentUserProfile.firstName ?? "") \(currentUserProfile.lastName ?? "")"
            } else {
                inspection.inspectorName = ""
            }
            inspection.creationDate = Date()
            inspection.property = propertyKey
            
            completion(newKey, inspection)
        }
    }
}
