//
//  SparkleNavigationBar.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 2/14/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class SparkleNavigationBar : UINavigationBar {
    var backgroundView: SparkleNavigationBarView?
    var plainBackgroundView: UIView?

    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
//    override func draw(_ rect: CGRect) {
//        super.
//        // Drawing code
//
//    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Remove default background view
        var barBackgroundIndex = -1
        for (index, subview) in self.subviews.enumerated() {
            let typeString = NSStringFromClass(subview.classForCoder)
            if typeString.contains("UIBarBackground") {
                barBackgroundIndex = index
//                subview.removeFromSuperview()
            }
        }
        
        #if RELEASE_BLUESTONE
        self.clipsToBounds = false
        if backgroundView == nil || backgroundView?.superview == nil {
            let statusBarHeight = min(UIApplication.shared.statusBarFrame.size.width, UIApplication.shared.statusBarFrame.size.height)
            
            backgroundView = SparkleNavigationBarView(frame: CGRect(x: 0, y: -statusBarHeight, width: self.bounds.width, height: self.bounds.height + statusBarHeight))
            backgroundView!.isUserInteractionEnabled = false
            backgroundView!.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.insertSubview(backgroundView!, at: barBackgroundIndex + 1)
        } else {
            backgroundView!.removeFromSuperview()
            self.insertSubview(backgroundView!, at: barBackgroundIndex + 1)
        }
        #elseif RELEASE_STAGING
        self.clipsToBounds = false
        if plainBackgroundView == nil || plainBackgroundView?.superview == nil {
            let statusBarHeight = min(UIApplication.shared.statusBarFrame.size.width, UIApplication.shared.statusBarFrame.size.height)
            
            plainBackgroundView = UIView(frame: CGRect(x: 0, y: -statusBarHeight, width: self.bounds.width, height: self.bounds.height + statusBarHeight))
            plainBackgroundView!.backgroundColor = firebaseConnectionColor()
            plainBackgroundView!.isUserInteractionEnabled = false
            plainBackgroundView!.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.insertSubview(plainBackgroundView!, at: barBackgroundIndex + 1)
        } else {
            plainBackgroundView!.removeFromSuperview()
            plainBackgroundView!.backgroundColor = firebaseConnectionColor()
            self.insertSubview(plainBackgroundView!, at: barBackgroundIndex + 1)
        }
//        self.backgroundColor = firebaseConnectionColor()
        #else
        self.clipsToBounds = false
        if plainBackgroundView == nil || plainBackgroundView?.superview == nil {
            let statusBarHeight = min(UIApplication.shared.statusBarFrame.size.width, UIApplication.shared.statusBarFrame.size.height)
            
            plainBackgroundView = UIView(frame: CGRect(x: 0, y: -statusBarHeight, width: self.bounds.width, height: self.bounds.height + statusBarHeight))
            plainBackgroundView!.backgroundColor = firebaseConnectionColor()
            plainBackgroundView!.isUserInteractionEnabled = false
            plainBackgroundView!.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.insertSubview(plainBackgroundView!, at: barBackgroundIndex + 1)
        } else {
            plainBackgroundView!.removeFromSuperview()
            plainBackgroundView!.backgroundColor = firebaseConnectionColor()
            self.insertSubview(plainBackgroundView!, at: barBackgroundIndex + 1)
        }
//        self.backgroundColor = firebaseConnectionColor()
        #endif
    }
}
