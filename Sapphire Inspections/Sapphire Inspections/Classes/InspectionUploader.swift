//
//  InspectionUploader.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 9/12/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import Foundation
import RealmSwift

class InspectionUploader {
    
    static let singleton = InspectionUploader()
    
    func initiateSyncWithSuccess(success succeed: () -> Void, updated update: () -> Void, failure fail: ((NSError) -> ())? = nil) {
        // TODO: Create sync logic
    }
    
}
