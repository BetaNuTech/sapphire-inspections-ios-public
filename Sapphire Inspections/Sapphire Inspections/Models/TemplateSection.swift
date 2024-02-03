//
//  TemplateSection.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 8/07/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

enum TemplateSectionType: String {
    case single = "single"
    case multi = "multi"
}

import ObjectMapper

class TemplateSection: Mappable {
    var title: String?
    var index: Int?
    var sectionType: String = "single" // single or multi
    var addedMultiSection: Bool = false // Was this section added from an inspection
    
    required init?(map: Map) {
        
    }
    
    // Mappable
    func mapping(map: Map) {
        title       <- map["title"]
        index       <- map["index"]
        sectionType <- map["section_type"]
        addedMultiSection <- map["added_multi_section"]
    }
}
