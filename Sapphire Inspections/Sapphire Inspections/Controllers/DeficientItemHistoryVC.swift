//
//  DeficientItemHistoryVCswift
//  Sapphire Inspections
//
//  Created by Stu Carney on 4/18/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import SwiftyJSON
import FirebaseFirestore

class DeficientItemHistoryVC: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var titleLabel: UILabel!
    
    var usersListener: ListenerRegistration?
    var keyUsers: [(key: String, user: UserProfile)] = []

    var dismissHUD = false

    var headerText = ""
    var element: DICellElement?
    var historyJSON: JSON?
    var historyJSONArray: [JSON] = []
    
    deinit {
        if let listener = usersListener {
            listener.remove()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel.text = headerText
        
        // Defaults
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.estimatedRowHeight = 87.0;
        
        if let historyJSON = historyJSON {
            for valueJSON in historyJSON.dictionaryValue.values {
                historyJSONArray.append(valueJSON)
            }
            
            // Sort
            historyJSONArray.sort(by: { (first, second) -> Bool in
                let firstCreatedAt = first["createdAt"].doubleValue
                let secondCreatedAt = second["createdAt"].doubleValue
                return firstCreatedAt < secondCreatedAt
            })
        }
        
        setObservers()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - UITable Delegate
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return historyJSONArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "historyCell") as! DeficientItemHistoryTVCell
        cell.historyDataLabel.textAlignment = .center // default

        let jsonData = historyJSONArray[indexPath.row]
        
        if let userId = jsonData["user"].string {
            cell.userLabel.text = "USER UNKNOWN"
            let matchingUsers = keyUsers.filter {$0.key == userId}
            if matchingUsers.count > 0 {
                var userString = matchingUsers.first!.user.firstName ?? ""
                userString += " "
                userString += matchingUsers.first!.user.lastName ?? ""
                userString += " (\(matchingUsers.first!.user.email ?? ""))"
                cell.userLabel.text = userString
            }
            // Do look up of user profile and update
        } else {
            cell.userLabel.text = "SYSTEM"
        }
        
        if let createdAt = jsonData["createdAt"].double {
            let date = Date(timeIntervalSince1970: createdAt)
            let formatter = DateFormatter()
            formatter.dateStyle = DateFormatter.Style.medium
            formatter.timeStyle = DateFormatter.Style.medium
            cell.timestampLabel.text = "\(formatter.string(from: date))"
            // Do look up of user profile and update
        } else {
            cell.timestampLabel.text = "Timestamp Missing"
        }
        
        cell.historyDataLabel.text = ""
        if let element = element {
            switch element {
            case .stateHistory:
                if let stateString = jsonData["state"].string {
                    if let state = InspectionDeficientItemState(rawValue: stateString) {
                        cell.historyDataLabel.text = InspectionDeficientItem.stateDescription(state: state)
                    } else {
                        cell.historyDataLabel.text = "Unknown State"
                    }
                } else {
                    cell.historyDataLabel.text = "<data missing>"
                }
            case .dueDates:
                if let dueDate = jsonData["dueDate"].double {
                    let date = Date(timeIntervalSince1970: dueDate)
                    let formatter = DateFormatter()
                    formatter.dateStyle = DateFormatter.Style.medium
                    formatter.timeStyle = DateFormatter.Style.short
                    if let currentDueDateDay = jsonData["dueDateDay"].string {
                        cell.historyDataLabel.text = "\(currentDueDateDay)"
                    } else {
                        cell.historyDataLabel.text = "\(formatter.string(from: date))"
                    }
                } else {
                    cell.historyDataLabel.text = "<data missing>"
                }
            case .deferredDates:
                if let deferredDate = jsonData["deferredDate"].double {
                    let date = Date(timeIntervalSince1970: deferredDate)
                    let formatter = DateFormatter()
                    formatter.dateStyle = DateFormatter.Style.medium
                    formatter.timeStyle = DateFormatter.Style.short
                    if let currentDeferredDueDateDay = jsonData["deferredDateDay"].string {
                        cell.historyDataLabel.text = "\(currentDeferredDueDateDay)"
                    } else {
                        cell.historyDataLabel.text = "\(formatter.string(from: date))"
                    }
                    cell.historyDataLabel.text = "\(formatter.string(from: date))"
                } else {
                    cell.historyDataLabel.text = "<data missing>"
                }
            case .plansToFix:
                if let planToFix = jsonData["planToFix"].string {
                    cell.historyDataLabel.text = planToFix
                    cell.historyDataLabel.textAlignment = .left
                } else {
                    cell.historyDataLabel.text = "<data missing>"
                }
            case .progressNotes:
                if let progressNote = jsonData["progressNote"].string {
                    cell.historyDataLabel.text = progressNote
                    cell.historyDataLabel.textAlignment = .left
                } else {
                    cell.historyDataLabel.text = "<data missing>"
                }
            case .reasonsIncomplete:
                if let reasonIncomplete = jsonData["reasonIncomplete"].string {
                    cell.historyDataLabel.text = reasonIncomplete
                    cell.historyDataLabel.textAlignment = .left
                } else {
                    cell.historyDataLabel.text = "<data missing>"
                }
            case .responsibilityGroups:
                if let groupResponsible = jsonData["groupResponsible"].string {
                    cell.historyDataLabel.text = groupResponsible
                    if let group = InspectionDeficientItemResponsibilityGroup(rawValue: groupResponsible) {
                        cell.historyDataLabel.text = InspectionDeficientItem.groupResponibleDescription(group: group)
                    }
                } else {
                    cell.historyDataLabel.text = "<data missing>"
                }
            case .completeNowReasons:
                if let completeNowReason = jsonData["completeNowReason"].string {
                    cell.historyDataLabel.text = completeNowReason
                    cell.historyDataLabel.textAlignment = .left
                } else {
                    cell.historyDataLabel.text = "<data missing>"
                }
            default:
                cell.historyDataLabel.text = "Unsupported Data"
            }
        }
        
        return cell
    }
    
    func addUser(_ keyUser: (key: String, user: UserProfile)) {
        keyUsers.append(keyUser)
    }
    
    func removeUserByKey(_ key: String) {
        if let index = keyUsers.index( where: { $0.key == key } ) {
            keyUsers.remove(at: index)
        }
    }
    
    func updateUser(_ keyUser: (key: String, user: UserProfile)) {
        removeUserByKey(keyUser.key)
        addUser(keyUser)
    }

    func setObservers() {
        presentHUDForConnection()
        
        dbCollectionUsers().getDocuments { [weak self] (querySnapshot, error) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                if let error = error {
                    dismissHUDForConnection()
                    print("Error getting Users: \(error)")
                    return
                } else if querySnapshot!.documents.count == 0 {
                    dismissHUDForConnection()
                } else {
                    print("Users count: \(querySnapshot!.documents.count)")
                    weakSelf.dismissHUD = true
                }
                
                
                weakSelf.usersListener = dbCollectionUsers().addSnapshotListener { (querySnapshot, error) in
                    DispatchQueue.main.async {
                        guard let weakSelf = self else {
                            return
                        }
                    
                        guard let snapshot = querySnapshot else {
                            if weakSelf.dismissHUD {
                                dismissHUDForConnection()
                                weakSelf.dismissHUD = false
                            }
                            print("Error fetching dbCollectionUsers snapshots: \(error!)")
                            return
                        }
                        snapshot.documentChanges.forEach { diff in
                            if (diff.type == .added) {
                                if weakSelf.dismissHUD {
                                    dismissHUDForConnection()
                                    weakSelf.dismissHUD = false
                                }
                                
                                let newKeyUser = (diff.document.documentID, Mapper<UserProfile>().map(JSONObject: diff.document.data())!)
                                weakSelf.addUser(newKeyUser)
                                weakSelf.tableView.reloadData()
                            } else if (diff.type == .modified) {
                                let changedKeyUser = (diff.document.documentID, Mapper<UserProfile>().map(JSONObject: diff.document.data())!)
                                weakSelf.updateUser(changedKeyUser)
                                weakSelf.tableView.reloadData()
                            } else if (diff.type == .removed) {
                                weakSelf.removeUserByKey(diff.document.documentID)
                                weakSelf.tableView.reloadData()
                            }
                        }
                    }
                }
            }
        }
    }

}
