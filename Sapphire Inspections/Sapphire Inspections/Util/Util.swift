//
//  Util.swift
//  ThatApp
//
//  Created by Stu Carney on 6/29/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import Foundation

func delay(_ delay:Double, closure:@escaping ()->()) {
    DispatchQueue.main.asyncAfter(
        deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure)
}

func docsPath() -> String {
    let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
    return paths[0]
}

extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
    var buildVersionNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
}

extension HTTPCookieStorage {
    func deleteAllCookies() {
        if let cookies = self.cookies {
            for cookie in cookies {
                self.deleteCookie(cookie)
            }
        }
    }
}

extension UIViewController {
    func topMostViewController() -> UIViewController {
        
        if let presented = self.presentedViewController {
            return presented.topMostViewController()
        }
        
        if let navigation = self as? UINavigationController {
            return navigation.visibleViewController?.topMostViewController() ?? navigation
        }
        
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostViewController() ?? tab
        }
        
        return self
    }
    
    // MARK: Alerts
    
    func showAlertWithOkayButton(title: String, message: String?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let okayAction = UIAlertAction(title: NSLocalizedString("OK", comment: "Okay action"), style: .default, handler: { (action) in
            print("Okay Action")
        })
        alertController.addAction(okayAction)

        present(alertController, animated: true, completion: {})
    }
}

extension UIApplication {
    func topMostViewController() -> UIViewController? {
        return self.keyWindow?.rootViewController?.topMostViewController()
    }
}

extension String {
    var digits: String {
        return components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
    }
}

extension NSNumber {
    var isFraction: Bool {
        var decimal = decimalValue, decimalRounded = decimal
        NSDecimalRound(&decimalRounded, &decimal, 0, .down)
        return NSDecimalNumber(decimal: decimalRounded) != self
    }
}
