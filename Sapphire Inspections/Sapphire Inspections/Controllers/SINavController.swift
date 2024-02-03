//
//  SINavController.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 2/22/17.
//  Copyright © 2017 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class SINavController: UINavigationController {
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(SINavController.connectionUpdated(_:)),
                                               name: NSNotification.Name.FirebaseConnectionUpdate,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(SINavController.offlineImageUploaded(_:)),
                                               name: NSNotification.Name.OfflinePhotoUploaded,
                                               object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateUI()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func offlineImageUploaded(_ note: Notification) {
        var remainingOfflineImagesCount = LocalInspectionImages.localImagesNotDeletedNotSynced().count
        remainingOfflineImagesCount += LocalDeficientImages.localImagesNotDeletedNotSynced().count
        SVProgressHUD.showInfo(withStatus: "Image Uploaded\n(\(remainingOfflineImagesCount) images remaining)")
    }
    
    @objc func connectionUpdated(_ note: Notification) {
        updateUI()
        
        if FIRConnection.connected() && SVProgressHUD.isVisible() {
            // Remove any offline Info message, if just coming online
            SVProgressHUD.dismiss()
        }
    }
    
    func updateUI() {
        if let navigationBar = self.navigationBar as? SparkleNavigationBar {
            navigationBar.backgroundView?.alpha = firebaseConnectionAlpha()
        }
        
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = firebaseConnectionColor()
            appearance.titleTextAttributes = [.foregroundColor: UIColor.white] // With a red background, make the title more readable.
            self.navigationBar.standardAppearance = appearance
            self.navigationBar.scrollEdgeAppearance = appearance
            self.navigationBar.compactAppearance = appearance // For iPhone small navigation bar in landscape.
        } else {
            self.navigationBar.barTintColor = firebaseConnectionColor()
            self.navigationBar.tintColor = UIColor.white
            UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.white]
            self.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        }

        print("SINavController Updated")
        self.navigationBar.setNeedsLayout()
        self.navigationBar.layoutIfNeeded()
        self.navigationBar.setNeedsDisplay()
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
