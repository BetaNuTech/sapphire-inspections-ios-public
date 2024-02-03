//
//  SparkleSideMenuVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 7/26/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import SideMenuController

class SparkleSideMenuVC: SideMenuController {

    override func viewDidLoad() {
        super.viewDidLoad()

        performSegue(withIdentifier: "embedInitialCenterController", sender: nil)
        performSegue(withIdentifier: "embedSideController", sender: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "embedSideController" {
            if let vc = segue.destination as? SideMenuVC {
                vc.rootSideMenuVC = self
            }
        }
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }

}
