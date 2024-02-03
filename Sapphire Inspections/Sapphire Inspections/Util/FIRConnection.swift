//
//  FIRConnection.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 2/21/17.
//  Copyright © 2017 Beta Nu Technologies LLC. All rights reserved.
//

class FIRConnection {
    
    static let sharedInstance = FIRConnection()
    
    var handle: UInt?
    var isConnected = false
    var offlineDataHUDShown = false
    
    class func startMonitoring() {
        sharedInstance.handle = connectedRef.observe(.value, with: { (snapshot) in
            guard let connected = snapshot.value as? Bool else {
                print("FIRConnection: Error occurred")
                return
            }
            
            DispatchQueue.main.async {
                if connected {
                    print("FIRConnection: Connected")
                    sharedInstance.isConnected = true
                    sharedInstance.offlineDataHUDShown = false
                } else {
                    print("FIRConnection: Not connected")
                    sharedInstance.isConnected = false
                }
                
                NotificationCenter.default.post(name: NSNotification.Name.FirebaseConnectionUpdate, object: nil)
            }
        })
    }
    
    class func stopMonitoring() {
        if let handle = sharedInstance.handle {
            connectedRef.removeObserver(withHandle: handle)
        }
    }
    
    class func connected() -> Bool {
        return sharedInstance.isConnected
    }
    
    class func showOfflineDataHUD() {
        if !sharedInstance.offlineDataHUDShown {
            SVProgressHUD.showInfo(withStatus: "Offline data, please reconnect to stay in sync")
            sharedInstance.offlineDataHUDShown = true
        }
    }
}
