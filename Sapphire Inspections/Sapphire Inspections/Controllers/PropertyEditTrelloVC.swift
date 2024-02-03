//
//  PropertyEditTrelloVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 8/13/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

enum TrelloSetting {
    case open
    case closed
}

class PropertyEditTrelloVC: UIViewController {
    
    @IBOutlet weak var trelloStatusLabel: UILabel!
    
    @IBOutlet weak var openBoardLabel: UILabel!
    @IBOutlet weak var openListLabel: UILabel!
    @IBOutlet weak var closedBoardLabel: UILabel!
    @IBOutlet weak var closedListLabel: UILabel!

    
    var organizationTrelloListener: ListenerRegistration?
    var propertyTrelloListener: ListenerRegistration?


    var keyProperty: KeyProperty?
    var originalKeyPropertyTrello: (key: String, propertyTrello: PropertyTrello?)?
    var keyPropertyTrello: (key: String, propertyTrello: PropertyTrello?)?

    var isLoading = false
    var dismissHUD = false
    
    var settingForSetup = TrelloSetting.open
    var listNotBoardForSetup = false

    deinit {
        if let listener = organizationTrelloListener {
            listener.remove()
        }
        if let listener = propertyTrelloListener {
            listener.remove()
        }
        
        if let keyProperty = keyProperty, let prevKeyPropertyTrello = originalKeyPropertyTrello, let keyPropertyTrello = keyPropertyTrello {
            
            if prevKeyPropertyTrello.propertyTrello?.toJSONString() != keyPropertyTrello.propertyTrello?.toJSONString() {
                Notifications.sendPropertyTrelloSettingsUpdate(keyProperty: keyProperty, prevKeyPropertyTrello: prevKeyPropertyTrello, keyPropertyTrello: keyPropertyTrello)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        isLoading = true

        updateUI()
        
        if let keyPropertyTrello = keyPropertyTrello {
            originalKeyPropertyTrello = (key: keyPropertyTrello.key, propertyTrello: nil)
            dbDocumentIntegrationTrelloPropertyWith(propertyId: keyPropertyTrello.key).getDocument(completion: { [weak self] (documentSnapshot, error) in
                DispatchQueue.main.async {
                    print("Original Property Trello Observed, observed by PropertyEditTrelloVC")
                    if let document = documentSnapshot, document.exists {
                        if let propertyTrello = Mapper<PropertyTrello>().map(JSONObject: document.data()) {
                            self?.originalKeyPropertyTrello?.propertyTrello = propertyTrello
                        } else {
                            self?.originalKeyPropertyTrello?.propertyTrello = nil
                        }
                    } else {
                        self?.originalKeyPropertyTrello?.propertyTrello = nil
                    }
                }
            })
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if isLoading {
            presentHUDForConnection()
            setObservers()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func resetTapped(_ sender: UIButton) {
        guard let propertyKey = keyPropertyTrello?.key else {
            print("ERROR: propertyKey not set")
            return
        }
        
        var keyValues: [String : AnyObject] = [:]
        keyValues = [
            "openBoard" : NSNull(),
            "openBoardName" : NSNull(),
            "openList" : NSNull(),
            "openListName" : NSNull(),
            "closedBoard" : NSNull(),
            "closedBoardName" : NSNull(),
            "closedList" : NSNull(),
            "closedListName" : NSNull()
        ]
        
        presentHUDForConnection()

        dbDocumentIntegrationTrelloPropertyWith(propertyId: propertyKey).setData(keyValues, merge: true) { [weak self] (error) in
            DispatchQueue.main.async {
                var title: String?
                var message: String?
                if (error != nil) {
                    print("ERROR: \(error!.localizedDescription)")
                    title = "Reset Unsuccessful"
                    message = error!.localizedDescription
                } else {
                    print("SUCCESS: propertyTrelloIntegration updated values")
                    title = "Reset Successful"
                    message = nil
                }
            
                let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
                let okayAction = UIAlertAction(title: "OK", style: .default) { action in
                }
                alertController.addAction(okayAction)
                self?.present(alertController, animated: true, completion: nil)
            
                dismissHUDForConnection()
            }
        }
    }
    
    @IBAction func openBoardTapped(_ sender: UIControl) {
        if currentOrganizationTrello != nil {
            settingForSetup = .open
            listNotBoardForSetup = false
            performSegue(withIdentifier: "showTrelloBoardListSetup", sender: self)
        }
    }
    @IBAction func openListTapped(_ sender: UIControl) {
        if let propertyTrello = keyPropertyTrello?.propertyTrello {
            if propertyTrello.openBoard == nil || propertyTrello.openBoard == "" {
                print("ERROR: No Open Board set")
                return
            }
        } else {
            print("ERROR: No Open Board set")
            return
        }
        if currentOrganizationTrello != nil {
            settingForSetup = .open
            listNotBoardForSetup = true
            performSegue(withIdentifier: "showTrelloBoardListSetup", sender: self)
        }
    }
    @IBAction func closeBoardTapped(_ sender: UIControl) {
        if currentOrganizationTrello != nil {
            settingForSetup = .closed
            listNotBoardForSetup = false
            performSegue(withIdentifier: "showTrelloBoardListSetup", sender: self)
        }
    }
    @IBAction func closeListTapped(_ sender: UIControl) {
        if let propertyTrello = keyPropertyTrello?.propertyTrello {
            if propertyTrello.closedBoard == nil || propertyTrello.closedBoard == "" {
                print("ERROR: No Closed Board set")
                return
            }
        } else {
            print("ERROR: No Closed Board set")
            return
        }
        if currentOrganizationTrello != nil {
            settingForSetup = .closed
            listNotBoardForSetup = true
            performSegue(withIdentifier: "showTrelloBoardListSetup", sender: self)
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showTrelloBoardListSetup" {
            if let vc = segue.destination as? TrelloBoardListSelectVC {
                vc.setting = settingForSetup
                vc.listsNotBoards = listNotBoardForSetup
                vc.propertyKey = keyPropertyTrello?.key
                if let propertyTrello = keyPropertyTrello?.propertyTrello {
                    switch settingForSetup {
                        case .open:
                            vc.currentBoardId = propertyTrello.openBoard
                            vc.currentListId = propertyTrello.openList
                        case .closed:
                            vc.currentBoardId = propertyTrello.closedBoard
                            vc.currentListId = propertyTrello.closedList
                    }
                }
            }
        }
    }
    
    // MARK: Private Methods
    
    func updateUI() {
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
                trelloStatusLabel.text = "Not Logged In (Go to Settings)"
            }
        } else {
            if isLoading {
                trelloStatusLabel.text = "Authorization Unknown"
            } else {
                trelloStatusLabel.text = "Not Logged In (Go to Settings)"
            }
        }
        
        if let propertyTrello = keyPropertyTrello?.propertyTrello {
            if let name = propertyTrello.openBoardName {
                openBoardLabel.text = name
            } else {
                openBoardLabel.text = "NOT SET"
            }
            
            if let name = propertyTrello.openListName {
                openListLabel.text = name
            } else {
                openListLabel.text = "NOT SET"
            }
            
            if let name = propertyTrello.closedBoardName {
                closedBoardLabel.text = name
            } else {
                closedBoardLabel.text = "NOT SET"
            }
            
            if let name = propertyTrello.closedListName {
                closedListLabel.text = name
            } else {
                closedListLabel.text = "NOT SET"
            }
        } else {
            openBoardLabel.text   = "NOT SET"
            openListLabel.text    = "NOT SET"
            closedBoardLabel.text = "NOT SET"
            closedListLabel.text  = "NOT SET"
        }
    }
    
    
    func setObservers() {
        
        guard let propertyId = keyPropertyTrello?.key else {
            print("No Property Id")
            return
        }
        
        organizationTrelloListener = dbDocumentIntegrationOrganizationTrello().addSnapshotListener({ [weak self] (documentSnapshot, error) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                print("Organization Trello Updated, observed by PropertyEditTrelloVC")
                if let document = documentSnapshot, document.exists {
                    if let trelloOrg = Mapper<OrganizationTrello>().map(JSONObject: document.data()) {
                        currentOrganizationTrello = trelloOrg
                    } else {
                        currentOrganizationTrello = nil
                    }
                } else {
                    currentOrganizationTrello = nil
                }
                
                weakSelf.updateUI()
            }
        })
        
        propertyTrelloListener = dbDocumentIntegrationTrelloPropertyWith(propertyId: propertyId).addSnapshotListener({ [weak self] (documentSnapshot, error) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                print("Property Trello Updated, observed by PropertyEditTrelloVC")
                if let document = documentSnapshot, document.exists {
                    if let propertyTrello = Mapper<PropertyTrello>().map(JSONObject: document.data()) {
                        weakSelf.keyPropertyTrello?.propertyTrello = propertyTrello
                    } else {
                        weakSelf.keyPropertyTrello?.propertyTrello = nil
                    }
                } else {
                    weakSelf.keyPropertyTrello?.propertyTrello = nil
                }

                weakSelf.updateUI()

                if weakSelf.isLoading {
                    weakSelf.isLoading = false
                    dismissHUDForConnection()
                }
            }
        })
    
    }
}
