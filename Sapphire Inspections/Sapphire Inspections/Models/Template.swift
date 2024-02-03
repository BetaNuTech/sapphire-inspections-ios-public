//
//  Template.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 8/05/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

typealias KeySectionWithKeyItems = (key: String, section: TemplateSection, keyItems: [ (key: String, item: TemplateItem) ])
typealias KeySectionsWithKeyItems = [ KeySectionWithKeyItems ]

import ObjectMapper
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}


class Template: Mappable {
    var name: String?
    var category: String?
    var description: String?
    var sections: [String: AnyObject]?  // auto_id : String
    var items: [String: AnyObject]?  // auto_id : Item as a Dictionary
    var trackDeficientItems: Bool = false
    var requireDeficientItemNoteAndPhoto: Bool = false

    required init?(map: Map) {
        
    }
    
    // Mappable
    func mapping(map: Map) {
        name           <- map["name"]
        category       <- map["category"]
        description    <- map["description"]
        sections       <- map["sections"]
        items          <- map["items"]
        trackDeficientItems <- map["trackDeficientItems"]
        requireDeficientItemNoteAndPhoto <- map["requireDeficientItemNoteAndPhoto"]
    }
    
    class func keySectionsWithKeyItems(_ template: Template, completion: @escaping (KeySectionsWithKeyItems) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            var keySectionsWithKeyItems: KeySectionsWithKeyItems = []
            // Map existing sections to working sections array
            var totalItems = 0
            
            guard let sectionsDict = template.sections else {
                completion(keySectionsWithKeyItems)
                return
            }
            
            // All Items
            let itemsDict = template.items ?? [:]
            var keyItems: [(key: String, item: TemplateItem)] = []
            for itemDict in itemsDict {
                if let item = Mapper<TemplateItem>().map(JSONObject: itemDict.1) {
                    keyItems.append((key: itemDict.0, item: item))
                }
            }
            // Sort Items by index
            keyItems.sort( by: { $0.item.index < $1.item.index } )

            
            // All Sections
            var keySections: [(key: String, section: TemplateSection)] = []
            for sectionDict in sectionsDict {
                if let section = Mapper<TemplateSection>().map(JSONObject: sectionDict.1) {
                    keySections.append((key: sectionDict.0, section: section))
                }
            }
            // Sort Sections by index
            keySections.sort( by: { $0.section.index < $1.section.index } )

            
            for keySection in keySections {
                // Find all items that match section key
                var sectionKeyItems: [(key: String, item: TemplateItem)] = []
                for keyItem in keyItems {
                    if keyItem.item.sectionId == keySection.key {
                        sectionKeyItems.append(keyItem)
                    }
                }

                totalItems += keyItems.count
                
                // Add section key and value, plus corresponding items
                keySectionsWithKeyItems.append((keySection.key, keySection.section, sectionKeyItems))
            }
            
            print("Total Items = \(totalItems)")

            completion(keySectionsWithKeyItems)
        }
    }
    
    func resetAllItemVersions() {
        // All Items
        let itemsDict = items ?? [:]
        var keyItems: [(key: String, item: TemplateItem)] = []
        for itemDict in itemsDict {
            if let item = Mapper<TemplateItem>().map(JSONObject: itemDict.1) {
                keyItems.append((key: itemDict.0, item: item))
            }
        }
        // Sort Items by index
        keyItems.sort( by: { $0.item.index < $1.item.index } )

        var updatedItems: [String: AnyObject] = [:]
        for keyItem in keyItems {
            keyItem.item.version = 0
            updatedItems[keyItem.key] = keyItem.item.toJSON() as AnyObject?
        }
        
        items = updatedItems
    }
    
    func incrementUpdatedItemVersions(previousTemplateItems: [String: AnyObject]?) {
        guard let previousItems = previousTemplateItems else {
            return
        }
        
        // All Items
        let itemsDict = items ?? [:]
        var keyItems: [(key: String, item: TemplateItem)] = []
        for itemDict in itemsDict {
            if let item = Mapper<TemplateItem>().map(JSONObject: itemDict.1) {
                keyItems.append((key: itemDict.0, item: item))
            }
        }
        // Sort Items by index
        keyItems.sort( by: { $0.item.index < $1.item.index } )

        var updatedItems: [String: AnyObject] = [:]
        for keyItem in keyItems {
            if let previousItemDict = previousItems[keyItem.key], let previousItem = Mapper<TemplateItem>().map(JSONObject: previousItemDict) {
                if keyItem.item.toJSONString() != previousItem.toJSONString() {
                    keyItem.item.version = keyItem.item.version + 1
                }
            }
            updatedItems[keyItem.key] = keyItem.item.toJSON() as AnyObject?
        }
        
        items = updatedItems
    }
}
