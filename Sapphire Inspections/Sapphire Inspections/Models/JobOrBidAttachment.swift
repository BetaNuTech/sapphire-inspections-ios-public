//
//  JobOrBidAttachment.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 3/22/22.
//  Copyright © 2022 Beta Nu Technologies LLC. All rights reserved.
//

import ObjectMapper

class JobOrBidAttachment: Mappable {
    var createdAt: Int?

    var name: String?
    
    var size: Int?
    
    var storageRef: String?
    var type: String?
    var url: String?
    
    required init?(map: Map) {
        
    }
    
    // Mappable
    func mapping(map: Map) {
        createdAt       <- map["createdAt"]

        name            <- map["name"]
        size            <- map["size"]
        storageRef      <- map["storageRef"]
        type            <- map["type"]
        url             <- map["url"]
    }
    
    func add(toArray arrayName: String, atDocumentRef ref: DocumentReference) {
        ref.updateData([
            arrayName: FieldValue.arrayUnion([self.toJSON()])
        ])
    }
    
    func remove(fromArray arrayName: String, atDocumentRef ref: DocumentReference) {
        ref.updateData([
            arrayName: FieldValue.arrayRemove([self.toJSON()])
        ])
    }
}
