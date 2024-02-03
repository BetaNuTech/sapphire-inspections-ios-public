//
//  TemplateItem.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 8/07/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

// Defaults
//let templateItemDefaultBinaryHighValue: Int = 3
//let templateItemDefaultBinaryLowValue: Int = 0
//let templateItemDefaultTrinaryHighValue: Int = 5
//let templateItemDefaultTrinaryMidValue: Int = 3
//let templateItemDefaultTrinaryLowValue: Int = 0

enum TemplateItemType: String {
    case main           = "main"
    case textInput      = "text_input"
    case signature      = "signature"
    case unsupported    = "unsupported"
}

import ObjectMapper

class TemplateItem: Mappable {
    var title: String?
    var sectionId: String?
    var index: Int?
    var inspectorNotes: String?
    var photos: Bool?
    var notes: Bool?
    var mainInputType: String?
    var mainInputZeroValue: Int?
    var mainInputOneValue: Int?
    var mainInputTwoValue: Int?
    var mainInputThreeValue: Int?
    var mainInputFourValue: Int?
    
    var mainInputSelected: Bool = false
    var mainInputSelection: Int?
    var value: Int?
    var deficient: Bool?
    var isDeficientItem = false // Used locally, only for require Note & Photo
    var requiredNoteAndPhotoIncomplete = false // Used locally, only for require Note & Photo

    var mainInputNotes: String? // Main input note
    
    var photosData: [String: AnyObject] = [:]
    
    // textInput
    var isTextInputItem: Bool = false // for supporting old version
    var textInputValue: String = ""
    
    var isItemNA: Bool = false
    
    var adminEdits: [String: AdminEdit] = [:]
    
    // signature
    var signatureTimestampKey: String = ""
    var signatureDownloadURL: String = ""
    
    // main, text_input, signature
    var itemType: String?
    
    // For when changes take place (+1)
    // Reset to zero, if template is duplicated
    // Default: 0
    var version: Int = 0

    required init?(map: Map) {
        
    }
    
    // Mappable
    func mapping(map: Map) {
        title             <- map["title"]
        sectionId         <- map["sectionId"]
        index             <- map["index"]
        inspectorNotes    <- map["inspectorNotes"]
        photos            <- map["photos"]
        notes             <- map["notes"]
        mainInputType     <- map["mainInputType"]
        mainInputZeroValue   <- map["mainInputZeroValue"]
        mainInputOneValue    <- map["mainInputOneValue"]
        mainInputTwoValue  <- map["mainInputTwoValue"]
        mainInputThreeValue   <- map["mainInputThreeValue"]
        mainInputFourValue   <- map["mainInputFourValue"]
        
        if let mainInputType = mainInputType, let mainInputTypeEnum = TemplateItemActions(rawValue: mainInputType.lowercased()) {
            setMainValues(mainInputTypeEnum: mainInputTypeEnum)
        } else {
            setMainValues(mainInputTypeEnum: defaultTemplateItemActions)
        }

        mainInputSelected   <- map["mainInputSelected"]
        mainInputSelection   <- map["mainInputSelection"]
        value   <- map["value"]
        deficient   <- map["deficient"]
//        isDeficientItem  <- map["isDeficientItem"]

        mainInputNotes   <- map["mainInputNotes"]
        
        photosData   <- map["photosData"]
        
        isTextInputItem   <- map["isTextInputItem"]
        textInputValue   <- map["textInputValue"]
        
        isItemNA   <- map["isItemNA"]
        
        adminEdits   <- map["adminEdits"]
        
        signatureTimestampKey   <- map["signatureTimestampKey"]
        signatureDownloadURL   <- map["signatureDownloadURL"]
        
        itemType   <- map["itemType"]
        
        version   <- map["version"]
    }
    
    func clearUserInputData() {
        inspectorNotes = nil
        mainInputSelected = false
        mainInputSelection = nil
        value = nil
        deficient = nil
        mainInputNotes = nil
        photosData = [:]
        textInputValue = ""
        isItemNA = false
        adminEdits = [:]
        signatureTimestampKey = ""
        signatureDownloadURL = ""
    }
    
    func add(adminEdit: AdminEdit, forKey key: String) {
        if adminEdit.editDate == nil {
            print("ERROR: add adminEdit - missing editDate")
            return
        }
        //let key = "\(editDate.timeIntervalSince1970)"
        adminEdits[key] = adminEdit
    }
    
    func sortedAdminEdits() -> [AdminEdit] {
        return adminEdits.values.sorted(by: { $0.editDate?.timeIntervalSince1970 ?? 0 < $1.editDate?.timeIntervalSince1970 ?? 0 } )
    }
    
    func setMainValues(mainInputTypeEnum: TemplateItemActions) {
        switch mainInputTypeEnum {
        case .TwoActions_checkmarkX:
            mainInputZeroValue  = mainInputZeroValue ?? twoActions_checkmarkX_default_iconValues.iconValue0
            mainInputOneValue   = mainInputOneValue ?? twoActions_checkmarkX_default_iconValues.iconValue1
            mainInputTwoValue   = mainInputTwoValue ?? twoActions_checkmarkX_default_iconValues.iconValue2
            mainInputThreeValue = mainInputThreeValue ?? twoActions_checkmarkX_default_iconValues.iconValue3
            mainInputFourValue  = mainInputFourValue ?? twoActions_checkmarkX_default_iconValues.iconValue4
        case .TwoActions_thumbs:
            mainInputZeroValue  = mainInputZeroValue ?? twoActions_thumbs_default_iconValues.iconValue0
            mainInputOneValue   = mainInputOneValue ?? twoActions_thumbs_default_iconValues.iconValue1
            mainInputTwoValue   = mainInputTwoValue ?? twoActions_thumbs_default_iconValues.iconValue2
            mainInputThreeValue = mainInputThreeValue ?? twoActions_thumbs_default_iconValues.iconValue3
            mainInputFourValue  = mainInputFourValue ?? twoActions_thumbs_default_iconValues.iconValue4
        case .ThreeActions_checkmarkExclamationX:
            mainInputZeroValue  = mainInputZeroValue ?? threeActions_checkmarkExclamationX_default_iconValues.iconValue0
            mainInputOneValue   = mainInputOneValue ?? threeActions_checkmarkExclamationX_default_iconValues.iconValue1
            mainInputTwoValue   = mainInputTwoValue ?? threeActions_checkmarkExclamationX_default_iconValues.iconValue2
            mainInputThreeValue = mainInputThreeValue ?? threeActions_checkmarkExclamationX_default_iconValues.iconValue3
            mainInputFourValue  = mainInputFourValue ?? threeActions_checkmarkExclamationX_default_iconValues.iconValue4
        case .ThreeActions_ABC:
            mainInputZeroValue  = mainInputZeroValue ?? threeActions_ABC_default_iconValues.iconValue0
            mainInputOneValue   = mainInputOneValue ?? threeActions_ABC_default_iconValues.iconValue1
            mainInputTwoValue   = mainInputTwoValue ?? threeActions_ABC_default_iconValues.iconValue2
            mainInputThreeValue = mainInputThreeValue ?? threeActions_ABC_default_iconValues.iconValue3
            mainInputFourValue  = mainInputFourValue ?? threeActions_ABC_default_iconValues.iconValue4
        case .FiveActions_oneToFive:
            mainInputZeroValue  = mainInputZeroValue ?? fiveActions_oneToFive_default_iconValues.iconValue0
            mainInputOneValue   = mainInputOneValue ?? fiveActions_oneToFive_default_iconValues.iconValue1
            mainInputTwoValue   = mainInputTwoValue ?? fiveActions_oneToFive_default_iconValues.iconValue2
            mainInputThreeValue = mainInputThreeValue ?? fiveActions_oneToFive_default_iconValues.iconValue3
            mainInputFourValue  = mainInputFourValue ?? fiveActions_oneToFive_default_iconValues.iconValue4
        case .OneAction_notes:
            mainInputZeroValue  = mainInputZeroValue ?? oneAction_notes_default_iconValues.iconValue0
            mainInputOneValue   = mainInputOneValue ?? oneAction_notes_default_iconValues.iconValue1
            mainInputTwoValue   = mainInputTwoValue ?? oneAction_notes_default_iconValues.iconValue2
            mainInputThreeValue = mainInputThreeValue ?? oneAction_notes_default_iconValues.iconValue3
            mainInputFourValue  = mainInputFourValue ?? oneAction_notes_default_iconValues.iconValue4
        }
    }
    
    func templateItemType() -> TemplateItemType {
        if let type = itemType {
            switch type {
            case TemplateItemType.main.rawValue:
                return .main
            case TemplateItemType.textInput.rawValue:
                return .textInput
            case TemplateItemType.signature.rawValue:
                return .signature
            default:
                return .unsupported
            }
        }
        
        if isTextInputItem {
            return .textInput
        } else {
            return .main
        }
    }
    
    func changeItemType() {
        if let type = itemType {
            switch type {
            case TemplateItemType.main.rawValue:
                itemType = TemplateItemType.textInput.rawValue
                isTextInputItem = true
            case TemplateItemType.textInput.rawValue:
                itemType = TemplateItemType.signature.rawValue
                isTextInputItem = false
            case TemplateItemType.signature.rawValue:
                itemType = TemplateItemType.main.rawValue
                isTextInputItem = false
            default:
                print("ERROR: Unsupported current itemType")
                return
            }
        } else {  // if itemType is set nil, then it is considered a text_input type
            if isTextInputItem {
                itemType = TemplateItemType.signature.rawValue
                isTextInputItem = false
            } else { // if nothing set, we assume we have main input as the type
                itemType = TemplateItemType.textInput.rawValue
                isTextInputItem = true
            }
        }
        
    }
    
    func updateRequiredNoteAndPhotoIncomplete(isRequired: Bool) {
        if !isRequired {
            requiredNoteAndPhotoIncomplete = false
            return
        }
        
        let notesEnabled = notes ?? false
        let photosEnabled = photos ?? false

        var requirementNotMet = false
        
        if let inspectorNotes = inspectorNotes , inspectorNotes != "" {
        } else if isDeficientItem && notesEnabled && !isItemNA {
            requirementNotMet = true
        }
        
        if photosData.values.count > 0 {
        } else if isDeficientItem && photosEnabled && !isItemNA {
            requirementNotMet = true
        }
        
        requiredNoteAndPhotoIncomplete = requirementNotMet
    }
}
