//
//  InspectionDeficientItem.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 4/5/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import ObjectMapper
import SwiftyJSON

enum InspectionDeficientItemState: String {
    case requiresAction = "requires-action"
    case pending = "pending"
    case deferred = "deferred"
    case requiresProgressUpdate = "requires-progress-update"
    case overdue = "overdue"
    case goBack = "go-back"
    case completed = "completed"
    case incomplete = "incomplete"
    case closed = "closed"
}

enum InspectionDeficientItemResponsibilityGroup: String {
    case siteLevel_InHouse = "site_level_in-house"
    case siteLevelManagesVendor = "site_level_manages_vendor"
    case corporate = "corporate"
    case corporateManagesVendor = "corporate_manages_vendor"
}

class InspectionDeficientItem: Mappable {
    var createdAt: Date?
    var updatedAt: Date?
    var property: String?  // New for Firestore
    var startDates: [String: AnyObject]?  // auto_id : { startDate : <unixtime> }
    var currentStartDate: Date?
    
    //    <auto-id> : {
    //        state : <string>,
    //        user : <user-id>,
    //        createdAt : <unixtime>
    //    }, ...
    var stateHistory: [String: AnyObject]?
    // "requires-action | pending | overdue | go-back | completed | incomplete | closed"
    var state: String?
    
    //    <auto-id> : {
    //        startDate : <copied from current>,
    //        dueDate : <unixtime>,
    //        user : <user-id>,
    //        createdAt : <unixtime>
    //    }, ...
    var dueDates: [String: AnyObject]?
    var currentDueDate: Date?
    var currentDueDateDay: String?

//    currentDeferredDate : <unixtime>,
//    deferredDates : {
//      <auto-id> : {
//      startDate : <copied from current>,
//      deferredDate : <unixtime>,
//      deferredDateDay : <string>,
//      user : <user-id>,
//      createdAt : <unixtime>
//    }, ...
//    }
    var currentDeferredDate: Date?
    var currentDeferredDateDay: String?
    var deferredDates: [String: AnyObject]?

    //    <auto-id> : {
    //        startDate : <copied from current>,
    //        planToFix : String,
    //        user : <user-id>,
    //        createdAt : <unixtime>
    //    }, ...
    var plansToFix: [String: AnyObject]?
    var currentPlanToFix: String?
    
    //    <auto-id> : {
    //        startDate : <copied from current>,
    //        groupResponsible : "site_level_in-house | site_level_manages_vendor | corporate | corporate_manages_vendor",
    //        user : <user-id>,
    //        createdAt : <unixtime>
    //    }, ...
    var responsibilityGroups: [String: AnyObject]?
    var currentResponsibilityGroup: String?
    
    //    <auto-id> : {
    //        startDate : <copied from current>,
    //        note : String,
    //        user : <user-id>,
    //        createdAt : <unixtime>
    //    }, ...
    var progressNotes: [String: AnyObject]?
    var unsavedProgressNote: String? // Doesn't go to database, except into progressNotes, on save

    //    <auto-id> : {
    //        startDate : <copied from current>,
    //        reasonIncomplete : String,
    //        user : <user-id>,
    //        createdAt : <unixtime>
    //    }, ...
    var reasonsIncomplete: [String: AnyObject]?
    var currentReasonIncomplete: String?
    
    //    <auto-id> : {
    //        completeNowReason : String,
    //        user : <user-id>,
    //        createdAt : <unixtime>
    //    }, ...
    var completeNowReasons: [String: AnyObject]?
    var currentCompleteNowReason: String?
    
    //    <auto-id> : {
    //        startDate : <copied from current>,
    //        storageDBPath : String,
    //        downloadURL : String,
    //        user : <user-id>,
    //        createdAt : <unixtime>
    //    }, ...
    var completedPhotos: [String: AnyObject]?
    
    var itemDataLastUpdatedDate: Date?
    var sectionTitle: String = ""
    var sectionSubtitle: String?
    var sectionType: String = ""
    var itemAdminEdits: [String: AnyObject] = [:]
    var itemInspectorNotes: String?
    var itemTitle: String = ""
    var itemMainInputType: String = ""
    var itemMainInputSelection: Int = 0
//    var itemPhotosData: [String: AnyObject] = [:]
    var hasItemPhotoData: Bool = false
    var itemScore: Int = 0

    var inspection: String = ""
    var item: String = ""
    
    // Is it an archive item?
    var archive: Bool = false
    
    // Trello card
    var trelloCardURL: String?
    
    var isDuplicate: Bool = false

    required init?(map: Map) {
        
    }
    
    // Mappable
    func mapping(map: Map) {
        // some values should be set nil
        map.shouldIncludeNilValues = true

        createdAt         <- (map["createdAt"], DateTransform())
        updatedAt         <- (map["updatedAt"], DateTransform())
        
        property          <- map["property"]
        
        startDates        <- map["startDates"]
        currentStartDate  <- (map["currentStartDate"], DateTransform())
        
        stateHistory      <- map["stateHistory"]
        state             <- map["state"]
        
        dueDates          <- map["dueDates"]
        currentDueDate    <- (map["currentDueDate"], DateTransform())
        currentDueDateDay <- map["currentDueDateDay"]
        
        currentDeferredDate    <- (map["currentDeferredDate"], DateTransform())
        currentDeferredDateDay    <- map["currentDeferredDateDay"]
        deferredDates          <- map["deferredDates"]

        plansToFix        <- map["plansToFix"]
        currentPlanToFix  <- map["currentPlanToFix"]
        
        responsibilityGroups        <- map["responsibilityGroups"]
        currentResponsibilityGroup  <- map["currentResponsibilityGroup"]
        
        progressNotes        <- map["progressNotes"]

        reasonsIncomplete <- map["reasonsIncomplete"]
        currentReasonIncomplete  <- map["currentReasonIncomplete"]
        
        completeNowReasons <- map["completeNowReasons"]
        currentCompleteNowReason  <- map["currentCompleteNowReason"]
        
        completedPhotos     <- map["completedPhotos"]
        
        itemDataLastUpdatedDate <- (map["itemDataLastUpdatedDate"], DateTransform())
        sectionTitle            <- map["sectionTitle"]
        sectionSubtitle         <- map["sectionSubtitle"]
        sectionType             <- map["sectionType"]
        itemAdminEdits          <- map["itemAdminEdits"]
        itemInspectorNotes      <- map["itemInspectorNotes"]
        itemTitle               <- map["itemTitle"]
        itemMainInputType       <- map["itemMainInputType"]
        itemMainInputSelection  <- map["itemMainInputSelection"]
        hasItemPhotoData        <- map["hasItemPhotoData"]
        itemScore               <- map["itemScore"]

        inspection              <- map["inspection"]
        item                    <- map["item"]
        
        archive                 <- map["archive"]
        
        trelloCardURL           <- map["trelloCardURL"]
        
        isDuplicate             <- map["isDuplicate"]
    }
    
    class func stateDescription(state: InspectionDeficientItemState?) -> String {
        guard let state = state else {
            return "ERROR: Unknown state"
        }
        
        switch state {
        case .requiresAction:
            return "NEW - Initial Due Date, Plan to Fix, and Responsibility Group required."
        case .pending:
            return "PENDING - Deficient Item needs to be completed before set Due Date."
        case .deferred:
            return "DEFERRED - Deficient Item has been deferred to a later date."
        case .requiresProgressUpdate:
            return "PROGRESS NOTE REQUIRED - Deficient Item currently requires a Progress Note."
        case .overdue:
            return "OVERDUE - The Deficient Item is now past due.  A Reason Incomplete is now required, before an extension can be granted."
        case .goBack:
            return "GO BACK - The Deficient Item now requires a new Due Date, Plan to Fix, and Responsibility Group set."
        case .completed:
            return "COMPLETED - The Deficient Item has been marked complete, and now needs Approval (Close) or Rejection (Go Back)."
        case .incomplete:
            return "INCOMPLETE - The Deficient Item was not completed on-time, and now needs to be Extended (Go Back), or Closed."
        case .closed:
            return "CLOSED"
        }
    }
    
    class func groupResponibleDescription(group: InspectionDeficientItemResponsibilityGroup?) -> String {
        guard let group = group else {
            return "ERROR: Unknown Responsibility Group"
        }
        
        switch group {
        case .corporateManagesVendor:
            return "Corporate, Managing Vendor"
        case .corporate:
            return "Corporate"
        case .siteLevel_InHouse:
            return "Site Level, In-House"
        case .siteLevelManagesVendor:
            return "Site Level, Managing Vendor"
        }
    }
    
    // Return Error Message, if it fails
    class func validateAddHistoryAndMoveToNewState(propertyKey: String, deficientItemKey: String, deficientItem: InspectionDeficientItem, newState: InspectionDeficientItemState) -> (InspectionDeficientItem?, String?) {
        guard let updatedDeficientItem = Mapper<InspectionDeficientItem>().map(JSON: deficientItem.toJSON()) else {
            return (nil, "Unable to create updated deficient Item, for saving")
        }

        guard let currentStateString = updatedDeficientItem.state else {
            return (nil, "Current State is nil")
        }
        
        guard let currentState = InspectionDeficientItemState(rawValue: currentStateString) else {
            return (nil, "Unknown Current State")
        }
        
        guard let currentUser = currentUser else {
            return (nil, "Current User is nil")
        }
        
        let updatedNowDate = Date()
        
        updatedDeficientItem.updatedAt = updatedNowDate
        
        switch currentState {
        case .requiresAction, .goBack:
            switch newState {
            case .pending:
                guard let currentPlanToFix = updatedDeficientItem.currentPlanToFix else {
                    return (nil, "Current Plan to Fix is NOT SET.")
                }
                guard let currentResponsibilityGroup = updatedDeficientItem.currentResponsibilityGroup else {
                    return (nil, "Current Responsibility Group is NOT SET.")
                }
                guard let currentDueDate = updatedDeficientItem.currentDueDate else {
                    return (nil, "Current Due Date is NOT SET.")
                }
                guard let currentDueDateDay = updatedDeficientItem.currentDueDateDay else {
                    return (nil, "Current Due Date Day is NOT SET.")
                }
                
                // Create New Start Date
                updatedDeficientItem.currentStartDate = updatedNowDate
                
                // Create new startDates entry
                var startDatesJSON = JSON(updatedDeficientItem.startDates ?? [:])
                startDatesJSON[dbCollectionDeficiencies().document().documentID] = JSON(["startDate" : updatedDeficientItem.currentStartDate!.timeIntervalSince1970])
                if let newStartDates = startDatesJSON.dictionaryObject as [String : AnyObject]? {
                    updatedDeficientItem.startDates = newStartDates
                }

                // Create new plansToFix entry
                var plansToFixJSON = JSON(updatedDeficientItem.plansToFix ?? [:])
                let planToFixJSON = JSON(["startDate": updatedDeficientItem.currentStartDate!.timeIntervalSince1970, "planToFix": currentPlanToFix, "user": currentUser.uid, "createdAt": updatedDeficientItem.currentStartDate!.timeIntervalSince1970])
                plansToFixJSON[dbCollectionDeficiencies().document().documentID] = planToFixJSON
                if let newPlansToFix = plansToFixJSON.dictionaryObject as [String : AnyObject]? {
                    updatedDeficientItem.plansToFix = newPlansToFix
                }
                
                // Create new responsibilityGroups entry
                var responsibilityGroupsJSON = JSON(updatedDeficientItem.responsibilityGroups ?? [:])
                let responsibilityGroupJSON = JSON(["startDate": updatedDeficientItem.currentStartDate!.timeIntervalSince1970, "groupResponsible": currentResponsibilityGroup, "user": currentUser.uid, "createdAt": updatedDeficientItem.currentStartDate!.timeIntervalSince1970])
                responsibilityGroupsJSON[dbCollectionDeficiencies().document().documentID] = responsibilityGroupJSON
                if let newResponsibilityGroups = responsibilityGroupsJSON.dictionaryObject as [String : AnyObject]? {
                    updatedDeficientItem.responsibilityGroups = newResponsibilityGroups
                }
                
                // Create new dueDates entry
                var dueDatesJSON = JSON(updatedDeficientItem.dueDates ?? [:])
                let dueDateJSON = JSON(["startDate": updatedDeficientItem.currentStartDate!.timeIntervalSince1970, "dueDate": currentDueDate.timeIntervalSince1970, "dueDateDay": currentDueDateDay, "user": currentUser.uid, "createdAt": updatedDeficientItem.currentStartDate!.timeIntervalSince1970])
                dueDatesJSON[dbCollectionDeficiencies().document().documentID] = dueDateJSON
                if let newDueDates = dueDatesJSON.dictionaryObject as [String : AnyObject]? {
                    updatedDeficientItem.dueDates = newDueDates
                }
                
                updatedDeficientItem.state = newState.rawValue
                // Create new stateHistory entry
                var stateHistoryJSON = JSON(updatedDeficientItem.stateHistory ?? [:])
                let stateJSON = JSON(["state": newState.rawValue, "user": currentUser.uid, "createdAt": updatedNowDate.timeIntervalSince1970])
                stateHistoryJSON[dbCollectionDeficiencies().document().documentID] = stateJSON
                if let newStateHistory = stateHistoryJSON.dictionaryObject as [String : AnyObject]? {
                    updatedDeficientItem.stateHistory = newStateHistory
                }
                
                return (updatedDeficientItem, nil)
            case .deferred:
                guard let currentDeferredDate = updatedDeficientItem.currentDeferredDate else {
                    return (nil, "Current Deferred Date is NOT SET.")
                }
                
                // Create new deferredDates entry
                var deferredDatesJSON = JSON(updatedDeficientItem.deferredDates ?? [:])
                let deferredDateJSON = JSON(["deferredDate": currentDeferredDate.timeIntervalSince1970, "user": currentUser.uid, "createdAt": updatedNowDate.timeIntervalSince1970])
                deferredDatesJSON[dbCollectionDeficiencies().document().documentID] = deferredDateJSON
                if let newDeferredDates = deferredDatesJSON.dictionaryObject as [String : AnyObject]? {
                    updatedDeficientItem.deferredDates = newDeferredDates
                }
                
                updatedDeficientItem.state = newState.rawValue
                // Create new stateHistory entry
                var stateHistoryJSON = JSON(updatedDeficientItem.stateHistory ?? [:])
                let stateJSON = JSON(["state": newState.rawValue, "user": currentUser.uid, "createdAt": updatedNowDate.timeIntervalSince1970])
                stateHistoryJSON[dbCollectionDeficiencies().document().documentID] = stateJSON
                if let newStateHistory = stateHistoryJSON.dictionaryObject as [String : AnyObject]? {
                    updatedDeficientItem.stateHistory = newStateHistory
                }
                
                return (updatedDeficientItem, nil)
            case .closed:
                guard let currentCompleteNowReason = updatedDeficientItem.currentCompleteNowReason else {
                    return (nil, "Current Complete Now Reason is NOT SET.")
                }
                
                guard let _ = updatedDeficientItem.createdAt else {
                    return (nil, "ERROR: Deficient Date NOT SET.")
                }
                
                // Create new deferredDates entry
                var completeNowReasonsJSON = JSON(updatedDeficientItem.completeNowReasons ?? [:])
                let completeNowReasonJSON = JSON(["completeNowReason": currentCompleteNowReason, "user": currentUser.uid, "createdAt": updatedNowDate.timeIntervalSince1970])
                completeNowReasonsJSON[dbCollectionDeficiencies().document().documentID] = completeNowReasonJSON
                if let newCompleteNowReasons = completeNowReasonsJSON.dictionaryObject as [String : AnyObject]? {
                    updatedDeficientItem.completeNowReasons = newCompleteNowReasons
                }
                
                updatedDeficientItem.state = newState.rawValue
                // Create new stateHistory entry
                var stateHistoryJSON = JSON(updatedDeficientItem.stateHistory ?? [:])
                let stateJSON = JSON(["state": newState.rawValue, "user": currentUser.uid, "createdAt": updatedNowDate.timeIntervalSince1970])
                stateHistoryJSON[dbCollectionDeficiencies().document().documentID] = stateJSON
                if let newStateHistory = stateHistoryJSON.dictionaryObject as [String : AnyObject]? {
                    updatedDeficientItem.stateHistory = newStateHistory
                }
                
                return (updatedDeficientItem, nil)
            default:
                return (nil, "Unsupported state transition. \(currentState.rawValue) to \(newState.rawValue)")
            }
        case .pending:
            switch newState {
            case .pending:
                guard let currentStartDate = updatedDeficientItem.currentStartDate else {
                    return (nil, "Current Start Date is nil")
                }
                
                // Save progress note, if new one exists.
                if deficientItem.unsavedProgressNote != nil {
                    var progressNotesJSON = JSON(updatedDeficientItem.progressNotes ?? [:])
                    let newProgressNoteJSON = JSON(["startDate": currentStartDate.timeIntervalSince1970, "progressNote": deficientItem.unsavedProgressNote!, "user": currentUser.uid, "createdAt": updatedNowDate.timeIntervalSince1970])
                    progressNotesJSON[dbCollectionDeficiencies().document().documentID] = newProgressNoteJSON
                    if let updatedProgressNotes = progressNotesJSON.dictionaryObject as [String : AnyObject]? {
                        updatedDeficientItem.progressNotes = updatedProgressNotes
                    }
                    
                    deficientItem.unsavedProgressNote = nil
                }
                
                return (updatedDeficientItem, nil)
            case .completed:
                updatedDeficientItem.state = newState.rawValue
                // Create new stateHistory entry
                var stateHistoryJSON = JSON(updatedDeficientItem.stateHistory ?? [:])
                let stateJSON = JSON(["state": newState.rawValue, "user": currentUser.uid, "createdAt": updatedNowDate.timeIntervalSince1970])
                stateHistoryJSON[dbCollectionDeficiencies().document().documentID] = stateJSON
                if let newStateHistory = stateHistoryJSON.dictionaryObject as [String : AnyObject]? {
                    updatedDeficientItem.stateHistory = newStateHistory
                }
                
                return (updatedDeficientItem, nil)
            case .deferred:
                guard let currentDeferredDate = updatedDeficientItem.currentDeferredDate else {
                    return (nil, "Current Deferred Date is NOT SET.")
                }
                
                // Create new deferredDates entry
                var deferredDatesJSON = JSON(updatedDeficientItem.deferredDates ?? [:])
                let deferredDateJSON = JSON(["deferredDate": currentDeferredDate.timeIntervalSince1970, "user": currentUser.uid, "createdAt": updatedNowDate.timeIntervalSince1970])
                deferredDatesJSON[dbCollectionDeficiencies().document().documentID] = deferredDateJSON
                if let newDeferredDates = deferredDatesJSON.dictionaryObject as [String : AnyObject]? {
                    updatedDeficientItem.deferredDates = newDeferredDates
                }
                
                // Clear fields that need new data
                updatedDeficientItem.currentDueDate = nil
                updatedDeficientItem.currentPlanToFix = nil
                updatedDeficientItem.currentReasonIncomplete = nil
                updatedDeficientItem.currentDueDateDay = nil
                updatedDeficientItem.currentResponsibilityGroup = nil
                updatedDeficientItem.currentStartDate = nil
                
                updatedDeficientItem.state = newState.rawValue
                // Create new stateHistory entry
                var stateHistoryJSON = JSON(updatedDeficientItem.stateHistory ?? [:])
                let stateJSON = JSON(["state": newState.rawValue, "user": currentUser.uid, "createdAt": updatedNowDate.timeIntervalSince1970])
                stateHistoryJSON[dbCollectionDeficiencies().document().documentID] = stateJSON
                if let newStateHistory = stateHistoryJSON.dictionaryObject as [String : AnyObject]? {
                    updatedDeficientItem.stateHistory = newStateHistory
                }
                
                return (updatedDeficientItem, nil)
            default:
                return (nil, "Unsupported state transition. \(currentState.rawValue) to \(newState.rawValue)")
            }
        case .deferred:
            switch newState {
            case .goBack:
                
                // Clear current deferred date
                updatedDeficientItem.currentDeferredDate = nil
                updatedDeficientItem.currentDeferredDateDay = nil

                // Clear fields that need new data
                updatedDeficientItem.currentDueDate = nil
                updatedDeficientItem.currentPlanToFix = nil
                updatedDeficientItem.currentReasonIncomplete = nil
                updatedDeficientItem.currentDueDateDay = nil
                updatedDeficientItem.currentResponsibilityGroup = nil
                updatedDeficientItem.currentStartDate = nil
                
                // Other properties that should be nil
                updatedDeficientItem.currentCompleteNowReason = nil
                
                updatedDeficientItem.state = newState.rawValue
                // Create new stateHistory entry
                var stateHistoryJSON = JSON(updatedDeficientItem.stateHistory ?? [:])
                let stateJSON = JSON(["state": newState.rawValue, "user": currentUser.uid, "createdAt": updatedNowDate.timeIntervalSince1970])
                stateHistoryJSON[dbCollectionDeficiencies().document().documentID] = stateJSON
                if let newStateHistory = stateHistoryJSON.dictionaryObject as [String : AnyObject]? {
                    updatedDeficientItem.stateHistory = newStateHistory
                }
                
                return (updatedDeficientItem, nil)
            case .closed:
                guard let _ = updatedDeficientItem.createdAt else {
                    return (nil, "ERROR: Deficient Date NOT SET.")
                }
                
                // Deferred -> Close can only be if duplicate
                updatedDeficientItem.isDuplicate = true
                
                updatedDeficientItem.state = newState.rawValue
                // Create new stateHistory entry
                var stateHistoryJSON = JSON(updatedDeficientItem.stateHistory ?? [:])
                let stateJSON = JSON(["state": newState.rawValue, "user": currentUser.uid, "createdAt": updatedNowDate.timeIntervalSince1970])
                stateHistoryJSON[dbCollectionDeficiencies().document().documentID] = stateJSON
                if let newStateHistory = stateHistoryJSON.dictionaryObject as [String : AnyObject]? {
                    updatedDeficientItem.stateHistory = newStateHistory
                }
                
                return (updatedDeficientItem, nil)

            default:
                return (nil, "Unsupported state transition. \(currentState.rawValue) to \(newState.rawValue)")
            }
        case .requiresProgressUpdate:
            switch newState {
            case .pending:
                guard let currentStartDate = updatedDeficientItem.currentStartDate else {
                    return (nil, "Current Start Date is nil")
                }
                
                // Save progress note, if new one exists.
                if deficientItem.unsavedProgressNote != nil {
                    var progressNotesJSON = JSON(updatedDeficientItem.progressNotes ?? [:])
                    let newProgressNoteJSON = JSON(["startDate": currentStartDate.timeIntervalSince1970, "progressNote": deficientItem.unsavedProgressNote!, "user": currentUser.uid, "createdAt": updatedNowDate.timeIntervalSince1970])
                    progressNotesJSON[dbCollectionDeficiencies().document().documentID] = newProgressNoteJSON
                    if let updatedProgressNotes = progressNotesJSON.dictionaryObject as [String : AnyObject]? {
                        updatedDeficientItem.progressNotes = updatedProgressNotes
                    }
                    
                    deficientItem.unsavedProgressNote = nil
                } else {
                    return (nil, "NEW Progress Note required")
                }

                updatedDeficientItem.state = newState.rawValue
                // Create new stateHistory entry
                var stateHistoryJSON = JSON(updatedDeficientItem.stateHistory ?? [:])
                let stateJSON = JSON(["state": newState.rawValue, "user": currentUser.uid, "createdAt": updatedNowDate.timeIntervalSince1970])
                stateHistoryJSON[dbCollectionDeficiencies().document().documentID] = stateJSON
                if let newStateHistory = stateHistoryJSON.dictionaryObject as [String : AnyObject]? {
                    updatedDeficientItem.stateHistory = newStateHistory
                }
                
                return (updatedDeficientItem, nil)
            default:
                return (nil, "Unsupported state transition. \(currentState.rawValue) to \(newState.rawValue)")
            }
        case .overdue:
            switch newState {
            case .incomplete:
                guard let currentStartDate = updatedDeficientItem.currentStartDate else {
                    return (nil, "Current Start Date is nil")
                }
                guard let currentReasonIncomplete = updatedDeficientItem.currentReasonIncomplete else {
                    return (nil, "Current Reason Incomplete is NOT SET")
                }

                // Create new reasonsIncomplete entry
                var reasonsIncompleteJSON = JSON(updatedDeficientItem.reasonsIncomplete ?? [:])
                let reasonIncompleteJSON = JSON(["startDate": currentStartDate.timeIntervalSince1970, "reasonIncomplete": currentReasonIncomplete, "user": currentUser.uid, "createdAt": updatedNowDate.timeIntervalSince1970])
                reasonsIncompleteJSON[dbCollectionDeficiencies().document().documentID] = reasonIncompleteJSON
                if let newReasonsIncomplete = reasonsIncompleteJSON.dictionaryObject as [String : AnyObject]? {
                    updatedDeficientItem.reasonsIncomplete = newReasonsIncomplete
                }
                
                updatedDeficientItem.state = newState.rawValue
                // Create new stateHistory entry
                var stateHistoryJSON = JSON(updatedDeficientItem.stateHistory ?? [:])
                let stateJSON = JSON(["state": newState.rawValue, "user": currentUser.uid, "createdAt": updatedNowDate.timeIntervalSince1970])
                stateHistoryJSON[dbCollectionDeficiencies().document().documentID] = stateJSON
                if let newStateHistory = stateHistoryJSON.dictionaryObject as [String : AnyObject]? {
                    updatedDeficientItem.stateHistory = newStateHistory
                }
                
                return (updatedDeficientItem, nil)
            default:
                return (nil, "Unsupported state transition. \(currentState.rawValue) to \(newState.rawValue)")
            }
        case .completed, .incomplete:
            switch newState {
            case .goBack:
                // Clear current deferred date
                updatedDeficientItem.currentDeferredDate = nil
                updatedDeficientItem.currentDeferredDateDay = nil

                // Clear fields that need new data
                updatedDeficientItem.currentDueDate = nil
                updatedDeficientItem.currentPlanToFix = nil
                updatedDeficientItem.currentReasonIncomplete = nil
                updatedDeficientItem.currentDueDateDay = nil
                updatedDeficientItem.currentResponsibilityGroup = nil
                updatedDeficientItem.currentStartDate = nil
                
                // Other properties that should be nil
                updatedDeficientItem.currentCompleteNowReason = nil

                updatedDeficientItem.state = newState.rawValue
                // Create new stateHistory entry
                var stateHistoryJSON = JSON(updatedDeficientItem.stateHistory ?? [:])
                let stateJSON = JSON(["state": newState.rawValue, "user": currentUser.uid, "createdAt": updatedNowDate.timeIntervalSince1970])
                stateHistoryJSON[dbCollectionDeficiencies().document().documentID] = stateJSON
                if let newStateHistory = stateHistoryJSON.dictionaryObject as [String : AnyObject]? {
                    updatedDeficientItem.stateHistory = newStateHistory
                }
                
                return (updatedDeficientItem, nil)
            case .closed:
                updatedDeficientItem.state = newState.rawValue
                // Create new stateHistory entry
                var stateHistoryJSON = JSON(updatedDeficientItem.stateHistory ?? [:])
                let stateJSON = JSON(["state": newState.rawValue, "user": currentUser.uid, "createdAt": updatedNowDate.timeIntervalSince1970])
                stateHistoryJSON[dbCollectionDeficiencies().document().documentID] = stateJSON
                if let newStateHistory = stateHistoryJSON.dictionaryObject as [String : AnyObject]? {
                    updatedDeficientItem.stateHistory = newStateHistory
                }
                
                return (updatedDeficientItem, nil)
            default:
                return (nil, "Unsupported state transition. \(currentState.rawValue) to \(newState.rawValue)")
            }
        case .closed:
            return (nil, "Unsupported state transition. \(currentState.rawValue) to \(newState.rawValue)")
        }
    }
}
