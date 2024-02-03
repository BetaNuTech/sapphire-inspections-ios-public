//
//  SIConnectionView.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 2/22/17.
//  Copyright © 2017 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class SIConnectionView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        updateUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        updateUI()
    }
    
    // MARK: Observers
    
    override func didMoveToWindow() {
        
        if self.window != nil {
            NotificationCenter.default.addObserver(self, selector: #selector(connectionUpdated(_:)), name: NSNotification.Name.FirebaseConnectionUpdate, object: nil)
        }
    }
    
    override func willMove(toWindow newWindow: UIWindow?) {
        
        if newWindow == nil {
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.FirebaseConnectionUpdate, object: nil)
        }
    }
    
    @objc func connectionUpdated(_ notification : Notification) {
        updateUI()
    }
    
    func updateUI() {
        self.backgroundColor = firebaseConnectionColor()
    }
}
