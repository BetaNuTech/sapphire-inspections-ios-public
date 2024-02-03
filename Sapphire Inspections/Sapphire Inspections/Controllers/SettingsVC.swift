//
//  SettingsVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 7/29/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import FirebaseFirestore

class SettingsVC: UIViewController {
    
    @IBOutlet weak var trelloStatusLabel: UILabel!
    @IBOutlet weak var slackStatusLabel: UILabel!
    @IBOutlet weak var pushNotificationsOptOutSwitch: UISwitch!
    @IBOutlet weak var slackSystemChannelButton: UIButton!
    @IBOutlet weak var goToAdminButton: UIButton!

    
    
//    var trelloAuthCallSuccessful = false
    
    var userListener: ListenerRegistration?
    var organizationTrelloListener: ListenerRegistration?
    var organizationSlackListener: ListenerRegistration?

    var isTrelloLoading = false
    var isSlackLoading = false
    var dismissHUD = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

//        // Do any additional setup after loading the view.
//        trelloOauthSwift = OAuth2Swift(
//            consumerKey:    "********",
//            consumerSecret: "********",
//            authorizeUrl:   "https://trello.com/1/authorize",
//            responseType:   "token"
//        )
        
        isTrelloLoading = true
        isSlackLoading = false
        updateUI()
        setObservers()        
    }
    
    deinit {
        if let listener = userListener {
            listener.remove()
        }
        if let listener = organizationTrelloListener {
            listener.remove()
        }
        if let listener = organizationSlackListener {
            listener.remove()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateUI()
    }
    
    @IBAction func pushNotificationsOptOutSwitched(_ sender: UISwitch) {
        if let currentUser = currentUser {
            var keyValues: [String : AnyObject] = [:]
            keyValues = [
                "pushOptOut" : NSNumber(booleanLiteral: sender.isOn)
            ]
            print(keyValues)
            dbDocumentUserWith(userId: currentUser.uid).setData(keyValues, merge: true) { [weak self] (error) in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.showMessagePrompt(error.localizedDescription)
                    } else {
                        print("SUCCESS: User's profile updated for pushNotficationsOptOut")
                    }
                }
            }
        }
    }
    
    @IBAction func goToAdminTapped(_ sender: UIButton) {
        guard let currentUserProfile = currentUserProfile else {
            return
        }
        
        guard currentUserProfile.admin == true, !currentUserProfile.isDisabled else {
            let alertController = UIAlertController(title: "Admin Access Required", message: nil, preferredStyle: .alert)
            let okayAction = UIAlertAction(title: "OK", style: .default)
            alertController.addAction(okayAction)
            present(alertController, animated: true, completion: nil)
            return
        }
        
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
    
    
    @IBAction func slackButtonTapped(_ sender: UIButton) {
        if isSlackLoading {
            return
        }
        
        guard let currentUserProfile = currentUserProfile else {
            return
        }
        
        guard currentUserProfile.admin == true, !currentUserProfile.isDisabled else {
            let alertController = UIAlertController(title: "Admin Only Feature", message: nil, preferredStyle: .alert)
            let okayAction = UIAlertAction(title: "OK", style: .default)
            alertController.addAction(okayAction)
            present(alertController, animated: true, completion: nil)
            return
        }
        
        if currentOrganizationSlack != nil {
            let title = "Remove Sparkle Settings and App from you Team?"
            let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
            let logoutAction = UIAlertAction(title: "Remove", style: .destructive) { action in
                if let user = currentUser {
                    user.getIDToken { [weak self] (token, error) in
                        if let token = token {
                            let headers: HTTPHeaders = [
                                "Authorization": "FB-JWT \(token)",
                                "Content-Type": "application/json"
                            ]
                            
                            let currentOrganizationSlackToBeDeleted = currentOrganizationSlack

                            presentHUDForConnection()
                            AF.request(setTrelloAuthorizorURLString, method: .delete, headers: headers).response { [weak self] dataResponse in
                                if let statusCode = dataResponse.response?.statusCode, statusCode >= 200 && statusCode < 300 {
                                    if let currentOrganization = currentOrganizationSlackToBeDeleted {
                                        Notifications.sendSlackIntegrationDeletion(organizationSlack: currentOrganization)
                                    }
                                    currentOrganizationSlack = nil
                                    self?.updateUI()
                                } else {
                                    let errorMessage = firebaseAPIErrorMessages(data: dataResponse.data, error: dataResponse.error, statusCode: dataResponse.response?.statusCode)
                                    let alertController = UIAlertController(title: "Removal Failed", message: errorMessage, preferredStyle: .alert)
                                    let okayAction = UIAlertAction(title: "OK", style: .default)
                                    alertController.addAction(okayAction)
                                    self?.present(alertController, animated: true, completion: nil)
                                }

                                dismissHUDForConnection()
                            }
                        }
                    }
                }
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { action in }
            alertController.addAction(logoutAction)
            alertController.addAction(cancelAction)
            present(alertController, animated: true, completion: nil)
        } else {
            performSegue(withIdentifier: "openSlackOAuth", sender: self)
        }
    }
    
    @IBAction func trelloButtonTapped(_ sender: UIButton) {
        if isTrelloLoading {
            return
        }
        
        guard let currentUserProfile = currentUserProfile else {
            return
        }
        
        guard currentUserProfile.admin == true, !currentUserProfile.isDisabled else {
            let alertController = UIAlertController(title: "Admin Only Feature", message: nil, preferredStyle: .alert)
            let okayAction = UIAlertAction(title: "OK", style: .default)
            alertController.addAction(okayAction)
            present(alertController, animated: true, completion: nil)
            return
        }
        
        if currentOrganizationTrello != nil {
            let title = "Log Out Current Trello User?"
            let message = "NOTE: Logging out will reset all trello boards and lists specified."
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let logoutAction = UIAlertAction(title: "Log Out", style: .destructive) { action in
                if let user = currentUser {
                    user.getIDToken { [weak self] (token, error) in
                        if let token = token {
                            let headers: HTTPHeaders = [
                                "Authorization": "FB-JWT \(token)",
                                "Content-Type": "application/json"
                            ]
                            
                            let currentOrganizationTrelloToBeDeleted = currentOrganizationTrello
                            
                            presentHUDForConnection()
                            AF.request(setTrelloAuthorizorURLString, method: .delete, headers: headers).response { [weak self] dataResponse in
                                if let statusCode = dataResponse.response?.statusCode, statusCode >= 200 && statusCode < 300 {
                                    if let currentOrganizationTrello = currentOrganizationTrelloToBeDeleted {
                                        Notifications.sendTrelloIntegrationDeletion(organizationTrello: currentOrganizationTrello)
                                    }
                                    currentOrganizationTrello = nil
                                    self?.updateUI()
                                } else {
                                    let errorMessage = firebaseAPIErrorMessages(data: dataResponse.data, error: dataResponse.error, statusCode: dataResponse.response?.statusCode)
                                    let alertController = UIAlertController(title: "Logout Failed", message: errorMessage, preferredStyle: .alert)
                                    let okayAction = UIAlertAction(title: "OK", style: .default)
                                    alertController.addAction(okayAction)
                                    self?.present(alertController, animated: true, completion: nil)
                                }
                                
                                dismissHUDForConnection()
                            }
                        }
                    }
                }
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { action in }
            alertController.addAction(logoutAction)
            alertController.addAction(cancelAction)
            present(alertController, animated: true, completion: nil)
        } else {
            performSegue(withIdentifier: "openTrelloOAuth", sender: self)
        }
        
//        trelloOauthSwift!.authorizeURLHandler = SafariURLHandler(viewController: self, oauthSwift: trelloOauthSwift!)
//
//        let handle = trelloOauthSwift!.authorize(withCallbackURL: URL(string: "oauth-swift://oauth-callback/instagram")!, scope: "read,write", state: "TRELLO", parameters: ["expiration":"1day"], headers: nil, success: { (credential, response, parameters) in
//            print(credential.oauthToken)
//        }, failure: { (error) in
//            print(error.localizedDescription)
//        })
    }
    
    @IBAction func slackSystemChannelButtonTapped(_ sender: Any) {
        guard currentOrganizationSlack != nil else {
            return
        }
        
        showTextInputPrompt(withMessage: "Enter System Channel Name") { [weak self] (userHitOkay, newString) in
            if userHitOkay {
                var keyValues: [String : AnyObject] = [:]
                
                keyValues = [
                    "defaultChannelName" : NSNull()
                ]
                
                if let channel = newString, channel != "" {
                    keyValues["defaultChannelName"] = channel as NSString
                    Notifications.sendSlackIntegrationSystemChannelUpdate(channelName: channel)
                } else {
                    Notifications.sendSlackIntegrationSystemChannelUpdate(channelName: "NOT SET")
                }
                
                dbDocumentIntegrationOrganizationSlack().setData(keyValues, merge: true) { [weak self] (error) in
                    DispatchQueue.main.async {
                        if let error = error {
                            self?.showMessagePrompt(error.localizedDescription)
                        } else {
                            self?.showMessagePrompt("Slack System Channel Updated")
                        }
                    }
                }
            }
        }
    }
    
    
    func updateUI() {
        if let profile = currentUserProfile {
            pushNotificationsOptOutSwitch.isOn = profile.pushOptOut
        } else {
            pushNotificationsOptOutSwitch.isOn = false
        }
        
        if let trelloOrg = currentOrganizationTrello {
            if trelloOrg.trelloUsername != "" {
                var fullName = ""
                var email = ""
                if let trelloUserEmail = trelloOrg.trelloEmail {
                    email = "\n\(trelloUserEmail)"
                }
                if let trelloUserFullName = trelloOrg.trelloFullName {
                    fullName = "\(trelloUserFullName) "
                }
                trelloStatusLabel.text = "\(fullName)(@\(trelloOrg.trelloUsername))\(email)"
            } else {
                trelloStatusLabel.text = "Not Logged In"
            }
        } else {
            if isTrelloLoading {
                trelloStatusLabel.text = "Authorization Unknown"
            } else {
                trelloStatusLabel.text = "Not Logged In"
            }
        }
        
        if let slackOrg = currentOrganizationSlack {
            if let teamId = slackOrg.teamId, teamId != "" {
                var teamName = "Unknown Team Name"
                var lastAddDate = "Added: Date Missing"
                if let name = slackOrg.teamName {
                    teamName = name
                }
                if let date = slackOrg.createdAt {
                    let formatter = DateFormatter()
                    formatter.dateStyle = DateFormatter.Style.medium
                    formatter.timeStyle = DateFormatter.Style.medium
                    lastAddDate = "Added: \(formatter.string(from: date))"
                }
                slackStatusLabel.text = "\(teamName)\n\(lastAddDate)"
            } else {
                slackStatusLabel.text = "App Not Added"
            }
            
            if let defaultChannel = slackOrg.defaultChannelName, defaultChannel != "" {
                if !defaultChannel.hasPrefix("#") {
                    slackSystemChannelButton.setTitle("#\(defaultChannel)", for: .normal)
                } else {
                    slackSystemChannelButton.setTitle(defaultChannel, for: .normal)
                }
            } else {
                slackSystemChannelButton.setTitle("NOT SET", for: .normal)
            }
        } else {
            if isSlackLoading {
                slackStatusLabel.text = "Authorization Unknown"
                slackSystemChannelButton.setTitle("", for: .normal)
            } else {
                slackStatusLabel.text = "App Not Added"
                slackSystemChannelButton.setTitle("NOT SET", for: .normal)
            }
        }
    }
    
    func setObservers() {
        
        presentHUDForConnection()
        
        if let user = currentUser {
            userListener = dbDocumentUserWith(userId: user.uid).addSnapshotListener({ [weak self] (documentSnapshot, error) in
                DispatchQueue.main.async {
                    print("Current User Profile Updated, observed by SettingsVC")
                    if let document = documentSnapshot, document.exists {
                        if let profile = Mapper<UserProfile>().map(JSONObject: document.data()) {
                            self?.pushNotificationsOptOutSwitch.isOn = profile.pushOptOut
                        }
                    }
                }
            })
        }
        
        organizationTrelloListener = dbDocumentIntegrationOrganizationTrello().addSnapshotListener({ [weak self] (documentSnapshot, error) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                print("Organization Trello Updated, observed by SettingsVC")
                if let document = documentSnapshot, document.exists {
                    if let trelloOrg = Mapper<OrganizationTrello>().map(JSONObject: document.data()) {
                        currentOrganizationTrello = trelloOrg
                    } else {
                        currentOrganizationTrello = nil
                    }
                } else {
                    currentOrganizationTrello = nil
                }
                
                if weakSelf.isTrelloLoading {
                    weakSelf.isTrelloLoading = false
                }
                
                weakSelf.updateUI()
                
                if !weakSelf.isSlackLoading {
                    dismissHUDForConnection()
                }
            }
        })
        
        organizationSlackListener = dbDocumentIntegrationOrganizationSlack().addSnapshotListener({ [weak self] (documentSnapshot, error) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                print("Organization Slack Updated, observed by SettingsVC")
                if let document = documentSnapshot, document.exists {
                    if let slackOrg = Mapper<OrganizationSlack>().map(JSONObject: document.data()) {
                        currentOrganizationSlack = slackOrg
                    } else {
                        currentOrganizationSlack = nil
                    }
                } else {
                    currentOrganizationSlack = nil
                }
                                
                if weakSelf.isSlackLoading {
                    weakSelf.isSlackLoading = false
                }
                
                weakSelf.updateUI()
                
                if !weakSelf.isTrelloLoading {
                    dismissHUDForConnection()
                }
            }
        })
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
