//
//  ProfileVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 7/26/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class ProfileVC: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var firstNameField: UITextField!
    @IBOutlet weak var lastNameField: UITextField!
    @IBOutlet weak var saveButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        firstNameField.text = currentUserProfile?.firstName
        lastNameField.text = currentUserProfile?.lastName
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
//        disableUsers()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func saveButtonTapped(_ sender: AnyObject) {
        updateFirstAndLastNames()
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        saveButton.isEnabled = true
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == firstNameField {
            lastNameField.becomeFirstResponder()
        } else {
            lastNameField.resignFirstResponder()
        }
        
        return true
    }

    func updateFirstAndLastNames() {
        if !checkNames() {
            return
        }
        
        SVProgressHUD.show()
        let changeRequest = currentUser?.createProfileChangeRequest()
        changeRequest?.displayName = firstNameField.text! + " " + lastNameField.text!
        changeRequest?.commitChanges() { [weak self] (error) in
            SVProgressHUD.dismiss()
            if let error = error {
                self?.showMessagePrompt(error.localizedDescription)
                return
            }
            if let currentUser = currentUser {
                var keyValues: [String : AnyObject] = [:]
                keyValues = [
                    "firstName" : NSNull(),
                    "lastName" : NSNull()
                ]
                
                if let firstName = self?.firstNameField.text {
                    keyValues["firstName"] = firstName as NSString
                }
                if let lastName = self?.lastNameField.text {
                    keyValues["lastName"] = lastName as NSString
                }
                dbDocumentUserWith(userId: currentUser.uid).setData(keyValues, merge: true) { (error) in
                    DispatchQueue.main.async {
                        if let error = error {
                            self?.showMessagePrompt(error.localizedDescription)
                        } else {
                            self?.showMessagePrompt("User Profile Updated")
                        }
                    }
                }
            } else {
                self?.showMessagePrompt("Error, not logged in.")
            }
            
            SVProgressHUD.dismiss()
        }
    }
    
    func checkNames() -> Bool {
        if firstNameField.text == "" {
            self.showMessagePrompt("Please enter a first name")
            return false
        }
        if lastNameField.text == "" {
            self.showMessagePrompt("Please enter a last name")
            return false
        }
        
        return true
    }
    
    func disableUsers() {
//        let usersToDisableByEmail_2022_05_03 = ["aberry@bluestone-prop.com", "mglass@bluestone-prop.com", "mgoodwin@bluestone-prop.com", "wpardue@bluestone-prop.com", "cridgway@bluestone-prop.com", "jbailey@bluestone-prop.com", "ahahn@bluestone-prop.com", "cmagee@bluestone-prop.com", "dcross@bluestone-prop.com", "drodriguez@bluestone-prop.com", "dbailey@bluestone-prop.com", "jgoss@bluestone-prop.com", "apatrick@bluestone-prop.com", "jransom@bluestone-prop.com", "avanic@bluestone-prop.com", "jscheivelhud@bluestone-prop.com", "gbaker@bluestone-prop.com", "abell@bluestone-prop.com", "ccreamer@bluestone-prop.com", "mfreire@bluestone-prop.com", "lmyers@bluestone-prop.com", "mwatson@bluestone-prop.com", "rwilson@bluestone-prop.com", "alcarballo@bluestone-prop.com", "sdavis@bluestone-prop.com", "aregalado@bluestone-prop.com", "lizaguirre@bluestone-prop.com", "ameyer@bluestone-prop.com", "crosado@bluestone-prop.com", "snaules@bluestone-prop.com", "oarizpe@bluestone-prop.com", "kbacon@bluestone-prop.com", "nbushey@bluestone-prop.com", "dlassiter@bluestone-prop.com", "npatton@bluestone-prop.com", "brebollar@bluestone-prop.com", "javiles@bluestone-prop.com", "cconner@bluestone-prop.com", "ejimmerson@bluestone-prop.com", "acastro@bluestone-prop.com", "nvillalva@bluestone-prop.com", "tday@bluestone-prop.com", "sfloyd@bluestone-prop.com", "jgonzalez@bluestone-prop.com", "akarns@bluestone-prop.com", "troush@bluestone-prop.com", "ksoutherland@bluestone-prop.com", "jtopping@bluestone-prop.com", "ovaden@bluestone-prop.com", "sclontz@bluestone-prop.com", "slane@bluestone-prop.com", "amiles@bluestone-prop.com", "sowens@bluestone-prop.com", "lhowell@bluestone-prop.com", "acamden@bluestone-prop.com", "rdunn@bluestone-prop.com", "ahodgens@bluestone-prop.com", "machellem@bluestone-prop.com", "cmoore@bluestone-prop.com", "jmoulder@bluestone-prop.com", "preed@bluestone-prop.com", "ashokunbi@bluestone-prop.com", "sstafford@bluestone-prop.com", "jblankenbaker@bluestone-prop.com", "kfranzman@bluestone-prop.com", "mmcclure@bluestone-prop.com", "kphillips@bluestone-prop.com", "cadams@bluestone-prop.com", "ygreen@bluestone-prop.com", "mjohnson@bluestone-prop.com", "jmccray@bluestone-prop.com", "jpeace@bluestone-prop.com", "tporter@bluestone-prop.com", "fsnelson@bluestone-prop.com", "nrobbs@bluestone-prop.com", "ccooksey@bluestone-prop.com", "tgraves@bluestone-prop.com", "bmonroe@bluestone-prop.com", "rpullen@bluestone-prop.com", "smarvel@bluestone-prop.com", "dbowman@bluestone-prop.com", "rgudiel@bluestone-prop.com", "joshuah@bluestone-prop.com", "djenkins@bluestone-prop.com", "towens@bluestone-prop.com", "aprate@bluestone-prop.com", "jcallis@bluestone-prop.com", "kavery@bluestone-prop.com", "kdains@bluestone-prop.com", "jmayfield@bluestone-prop.com", "kmosley@bluestone-prop.com", "twilliams@bluestone-prop.com", "milwilson@bluestone-prop.com", "twilliams@bluestone-prop.com", "vbyes@bluestone-prop.com", "gcombs@bluestone-proop.com", "shedge@bluestone-prop.com", "rjackson@bluestone-prop.com", "klibka@bluestone-prop.com", "jrobey@bluestone-prop.com", "callen@bluestone-prop.com", "jdean@bluestone-prop.com", "gfangman@bluestone-prop.com", "jhendley@bluestone-prop.com", "sjackson@bluestone-prop.com", "hkoschka@bluestone-prop.com", "esims@bluestone-prop.com", "mbartee@bluestone-prop.com", "jfletcher@bluestone-prop.com", "jwiessner@bluestone-prop.com", "kcummings@bluestone-prop.com", "cjackson@bluestone-prop.com", "ssierra@bluestone-prop.com", "avaldez@bluestone-prop.com", "klukefahr@bluestone-prop.com", "sreynolds@bluestone-prop.com", "dshular@bluestone-prop.com", "jwilliams@bluestone-prop.com", "fbracero@bluestone-prop.com", "cdelafuente@bluestone-prop.com", "alopez@bluestone-prop.com", "alexm@bluestone-prop.com", "cpargas@bluestone-prop.com", "malcolmb@bluestone-prop.com", "thayden@bluestone-prop.com", "kholmes@bluestone-prop.com", "sphillips@bluestone-prop.com", "rvazquez@bluestone-prop.com", "mwebb@bluestone-prop.com", "lyoung@bluestone-prop.com", "lallen@bluestone-prop.com", "jharrison@bluestone-prop.com", "clee@bluestone-prop.com", "hperry@bluestone-prop.com", "mtodd@bluestone-prop.com", "tyoung@bluestone-prop.com", "shaller@bluestone-prop.com", "wharrington@bluestone-prop.com", "rking@bluestone-prop.com", "rpaul@bluestone-prop.com", "areiniche@bluestone-prop.com", "alinton@bluestone-prop.com", "jstafford@bluestone-prop.com", "hterrell@bluestone-prop.com", "mward@bluestone-prop.com", "tbaird@bluestone-prop.com", "jbrowning@bluestone-prop.com", "tcarithers@bluestone-prop.com", "hdurliat@bluestone-prop.com", "mmoser@bluestone-prop.com", "kscott@bluestone-prop.com", "rcandanoza@bluestone-prop.com", "tclevenger@bluestone-prop.com", "chaywood@bluestone-prop.com", "tcannon@bluestone-prop.com", "eboucher@bluestone-prop.com", "jcombs@bluestone-prop.com", "acook@bluestone-prop.com", "mflermoen@bluestone-prop.com", "mweiss@bluestone-prop.com", "dwirt@bluestone-prop.com", "fbrewer@bluestone-prop.com", "aharper@bluestone-prop.com", "msalisbury@bluestone-prop.com", "aroe@bluestone-prop.com", "maguilar@bluestone-prop.com", "dkowalk@bluestone-prop.com"]
        
        let usersToDisableByEmail_2022_05_31 = ["mhash@bluestone-prop.com", "ahayden@bluestone-prop.com", "ktrumbull@bluestone-prop.com", "jwebb@bluestone-prop.com", "dcaldwell@bluestone-prop.com", "scockrell@bluestone-prop.com", "mgutierrez@bluestone-prop.com", "jkakuk@bluestone-prop.com", "tmoffatt@bluestone-prop.com", "cmorris@bluestone-prop.com", "ecopeland@bluestone-prop.com", "hgallegos@bluestone-prop.com", "tgilbert@bluestone-prop.com", "iguerrero@bluestone-prop.com", "chartgraves@bluestone-prop.com", "mmesa@bluestone-prop.com", "nwallace@bluestone-prop.com", "azuniga@bluestone-prop.com", "lblair@bluestone-prop.com", "aharris@bluestone-prop.com", "edorwart@bluestone-prop.com", "ehayden@bluestone-prop.com", "jhopson@bluestone-prop.com", "njewell@bluestone-prop.com", "acarballo@bluestone-prop.com", "cbaker@bluestone-prop.com", "hcaldwell@bluestone-prop.com", "sdickens@bluestone-prop.com"]
            
            
        presentHUDForConnection()
        
        dbCollectionUsers().getDocuments { (querySnapshot, error) in
            DispatchQueue.main.async {
                if let error = error {
                    dismissHUDForConnection()
                    print("Error getting Users: \(error)")
                    return
                } else if querySnapshot!.documents.count == 0 {
                    dismissHUDForConnection()
                } else {
                    for user in querySnapshot!.documents {
                        if let profile = Mapper<UserProfile>().map(JSONObject: user.data()) {
                            if let email = profile.email, usersToDisableByEmail_2022_05_31.contains(email) {
                                dbDocumentUserWith(userId: user.documentID).updateData(["isDisabled" : true])
                                print("Disabled User: \(email)")
                            }
                        }
                    }
                    dismissHUDForConnection()
                }
            }
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
