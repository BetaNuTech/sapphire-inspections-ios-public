//
//  SideMenuVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 7/26/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import SideMenuController
import FirebaseFirestore

class SideMenuVC: UIViewController, SideMenuControllerDelegate {

    var userListener: ListenerRegistration?

    @IBOutlet weak var templatesButton: UIButton!
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var incognitoModeImageView: UIImageView!
    @IBOutlet weak var goToAdminButton: UIButton!
    
    var adminUser = false
    
    deinit {
        if let listener = userListener {
            listener.remove()
        }
    }
    
    var rootSideMenuVC: SparkleSideMenuVC?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        if rootSideMenuVC != nil {
            rootSideMenuVC?.delegate = self
        }
        
        setObservers()
        
        // Set version #
        if let version = Bundle.main.releaseVersionNumber, let build = Bundle.main.buildVersionNumber {
            versionLabel.text = "v\(version) (\(build))"
        }
        
        incognitoModeImageView.image = UIImage(named: "incognito")?.withRenderingMode(.alwaysTemplate)
        incognitoModeImageView.tintColor = UIColor.white
        incognitoModeImageView.isHidden = !incognitoMode
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func tapGestureRecognized(_ sender: UITapGestureRecognizer) {
//        updateIncognitoMode(toggled: true)
    }
    
    @IBAction func propertiesButtonTapped(_ sender: AnyObject) {
        if rootSideMenuVC != nil {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let centerVC = storyboard.instantiateViewController(withIdentifier: "properties")
            rootSideMenuVC!.embed(centerViewController: centerVC)
        }
    }
    
    @IBAction func templatesButtonTapped(_ sender: AnyObject) {
        if rootSideMenuVC != nil {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let centerVC = storyboard.instantiateViewController(withIdentifier: "templates")
            rootSideMenuVC!.embed(centerViewController: centerVC)
        }
    }
    
    @IBAction func inspectionsButtonTapped(_ sender: AnyObject) {
        if rootSideMenuVC != nil {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let centerVC = storyboard.instantiateViewController(withIdentifier: "completedInspections")
            rootSideMenuVC!.embed(centerViewController: centerVC)
        }
    }
    
    @IBAction func profileButtonTapped(_ sender: AnyObject) {
        if rootSideMenuVC != nil {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let centerVC = storyboard.instantiateViewController(withIdentifier: "profile")
            rootSideMenuVC!.embed(centerViewController: centerVC)
        }
    }
    
    @IBAction func settingsButtonTapped(_ sender: AnyObject) {
        if rootSideMenuVC != nil {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let centerVC = storyboard.instantiateViewController(withIdentifier: "settings")
            rootSideMenuVC!.embed(centerViewController: centerVC)
        }
    }
    
    
    @IBAction func signOutButtonTapped(_ sender: AnyObject) {
        do {
            try Auth.auth().signOut()
        } catch {
            print("SignOut failed")
        }
    }
    
    @IBAction func goToAdminTapped(_ sender: UIButton) {
        let urlString = webAppBaseURL + "/admin"
        guard let url = URL(string: urlString) else {
            print("ERROR: URL malformed")
            return
        }
        
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            UIApplication.shared.openURL(url)
        }
    }
    
    
    // MARK: - Side Menu Controller Delegate
    
    func sideMenuControllerDidReveal(_ sideMenuController: SideMenuController) {
        print("Side Menu did reveal")
    }
    
    func sideMenuControllerDidHide(_ sideMenuController: SideMenuController) {
        print("Side Menu did hide")
    }
    
    // MARK: Private Methods
    
    private func setObservers() {
        if let user = currentUser {
            userListener = dbDocumentUserWith(userId: user.uid).addSnapshotListener({ [weak self] (documentSnapshot, error) in
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        return
                    }
                    
                    print("Current User Profile Updated, observed by SideMenuVC")
                    if let document = documentSnapshot, document.exists {
                        if let profile = Mapper<UserProfile>().map(JSONObject: document.data()), !profile.isDisabled {
                            let admin = profile.admin
                            let corporate = profile.corporate
                            weakSelf.templatesButton.isHidden = !(admin || corporate)
                            weakSelf.goToAdminButton.isHidden = !admin
                            weakSelf.adminUser = admin
                            weakSelf.updateIncognitoMode(toggled: false)
                        } else {
                            weakSelf.templatesButton.isHidden = true
                            weakSelf.goToAdminButton.isHidden = true
                            weakSelf.adminUser = false
                            weakSelf.updateIncognitoMode(toggled: false)
                        }
                    }
                }
            })
        }
    }
    
    private func updateIncognitoMode(toggled: Bool) {
        
        if adminUser && toggled {
            incognitoMode = !incognitoMode
        } else if !adminUser {
            incognitoMode = false
        }
        
        incognitoModeImageView.isHidden = !incognitoMode
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
