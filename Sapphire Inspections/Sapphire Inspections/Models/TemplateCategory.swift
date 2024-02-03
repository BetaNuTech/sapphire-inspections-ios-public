//
//  TemplateCategory.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 1/11/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//


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


class TemplateCategory: Mappable {
    var name: String?
    
    required init?(map: Map) {
        
    }
    
    // Mappable
    func mapping(map: Map) {
        name           <- map["name"]
    }
}
