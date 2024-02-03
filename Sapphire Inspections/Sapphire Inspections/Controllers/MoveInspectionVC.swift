//
//  MoveInspectionVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 11/25/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import FirebaseFirestore

typealias sectionTeam = (teamKey: String, teamTitle: String, keyProperties: [KeyProperty])


class MoveInspectionVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var fromPropertyNameLabel: UILabel!
    @IBOutlet weak var toPropertyNameLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    
    var keyInspectionToMove: keyInspection?
    var moveFromKeyProperty: (key: String, property: Property)?
    var moveToKeyProperty: (key: String, property: Property)?

    var sections: [sectionTeam] = []
    var allKeyProperties: [KeyProperty] = []
    
    var propertiesListener: ListenerRegistration?
    var teamsListener: ListenerRegistration?

    var allKeyTeams: [KeyTeam] = []
    
    var dismissHUD = false

    deinit {
        if let listener = propertiesListener {
            listener.remove()
        }
        if let listener = teamsListener {
            listener.remove()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Defaults
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.estimatedRowHeight = 40.0;
        
        // Setup
        let nib = UINib(nibName: "CategorySectionHeader", bundle: nil)
        tableView.register(nib, forHeaderFooterViewReuseIdentifier: "CategorySectionHeader")
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0.0
        } else {
            // Fallback on earlier versions
        }
        tableView.sectionHeaderHeight = 30.0

        setObservers()
        
        updateUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func cancelTapped(_ sender: AnyObject) {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        }
    }
    
    @IBAction func doneTapped(_ sender: AnyObject) {
        guard let keyInspectionToMove = keyInspectionToMove else {
            print("ERROR: keyInspectionToMove is nil")
            return
        }
        guard let moveToKeyProperty = moveToKeyProperty else {
            let alertController = UIAlertController(title: "Property Not Set", message: "Please select the property for which this inspection will move to.", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default) { action in
            }
            alertController.addAction(okAction)
            self.present(alertController, animated: true) {}
            return
        }
        
        // API Call
        if let user = currentUser {
            user.getIDToken { [weak self] (token, error) in
                if let token = token {
                    let headers: HTTPHeaders = [
                        "Authorization": "FB-JWT \(token)",
                        "Content-Type": "application/json"
                    ]
                    
                    let parameters: Parameters = [
                        "property": moveToKeyProperty.key
                    ]
                    
                    presentHUDForConnection()
                
                    AF.request(inspectionsURLString + "/\(keyInspectionToMove.key)", method: .patch, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { [weak self] response in
                        debugPrint(response)
                        
                        DispatchQueue.main.async {
                            if let statusCode = response.response?.statusCode, statusCode >= 200 && statusCode < 300 {
                                let alertController = UIAlertController(title: "Inspection Moved Successfully", message: nil, preferredStyle: .alert)
                                let okayAction = UIAlertAction(title: "OK", style: .default) { action in
                                    if let nav = self?.navigationController {
                                        nav.popViewController(animated: true)
                                    }
                                }
                                alertController.addAction(okayAction)
                                self?.present(alertController, animated: true, completion: nil)
                            } else {
                               let errorMessage = firebaseAPIErrorMessages(data: response.data, error: response.error, statusCode: response.response?.statusCode)
                               let alertController = UIAlertController(title: "Error Moving Inspection", message: errorMessage, preferredStyle: .alert)
                               let okayAction = UIAlertAction(title: "OK", style: .default)
                               alertController.addAction(okayAction)
                               self?.present(alertController, animated: true, completion: nil)
                            }
                            
                            dismissHUDForConnection()
                        }
                    }
                } else {
                    print("ERROR: user token is nil")
                }
            }
        } else {
            print("ERROR: currentUser is nil")
        }
    }
    
    
    func updateUI() {
        if let keyProperty = moveFromKeyProperty {
            fromPropertyNameLabel.text = keyProperty.property.name
        } else {
            fromPropertyNameLabel.text = "NOT SET"
        }
        
        if let keyProperty = moveToKeyProperty {
            toPropertyNameLabel.text = keyProperty.property.name
        } else {
            toPropertyNameLabel.text = "NOT SET"
        }
    }
    
    // MARK: UITableView DataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].keyProperties.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "propertyNameCell") as! PropertyNameTVCell
        let property = sections[indexPath.section].keyProperties[(indexPath as NSIndexPath).row].property
        
        cell.propertyName.text = property.name ?? "No Name"
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Dequeue with the reuse identifier
        let cell = self.tableView.dequeueReusableHeaderFooterView(withIdentifier: "CategorySectionHeader")
        let header = cell as! CategorySectionHeader
        header.titleLabel.text = sections[section].teamTitle
        header.titleLabel.textColor = UIColor.white
        header.background.backgroundColor = UIColor.darkGray

        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    // MARK: UITableView Delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let keyProperty = sections[indexPath.section].keyProperties[(indexPath as NSIndexPath).row]

        moveToKeyProperty = keyProperty
        updateUI()
    }

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }
    
    // MARK: Private Methods
    
    func updateSections() {
        let defaultTeamTitle = "NO TEAM"
        let keyProperties = allKeyProperties
        var newSections: [sectionTeam] = []
        
        for keyProperty in keyProperties {
            if keyProperty.key == moveFromKeyProperty?.key {
                continue
            }
            let teamKey = keyProperty.property.team ?? ""
            // Lookup Team Title
            let teamTitle = teamTitleForKey(teamKey: teamKey) ?? defaultTeamTitle
            if let teamSectionIndex = newSections.firstIndex(where: { $0.teamKey == teamKey }) {
                // Update existing section
                let teamSection = newSections[teamSectionIndex]
                var keyProperties = teamSection.keyProperties
                keyProperties.append(keyProperty)
                keyProperties = keyProperties.sorted(by: { $0.property.name?.lowercased() ?? "" < $1.property.name?.lowercased() ?? "" })
                newSections[teamSectionIndex] = (teamKey: teamKey, teamTitle: teamTitle, keyProperties: keyProperties)
            } else {
                // Add new section
                newSections.append((teamKey: teamKey, teamTitle: teamTitle, keyProperties: [keyProperty]))
            }
        }
        
        // Sort by Category name, "Uncategorized" first
        newSections.sort(by: { $0.teamTitle.lowercased() < $1.teamTitle.lowercased() })
        
        // Move defaultCategoryTitle to bottom, if it exists
        if let teamSectionIndex = newSections.firstIndex(where: { $0.teamKey == "" }) {
            let section = newSections.remove(at: teamSectionIndex)
            newSections.insert(section, at: newSections.endIndex)
        }
        
        sections = newSections
    }
    
    func teamTitleForKey(teamKey: String) -> String? {
        if let index = allKeyTeams.firstIndex(where: {$0.key == teamKey}) {
            return allKeyTeams[index].team.name
        }
        
        return nil
    }
    
    func setObservers() {
        
        presentHUDForConnection()
        
        dbCollectionProperties().getDocuments { [weak self] (querySnapshot, error) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                if let error = error {
                    dismissHUDForConnection()
                    print("Error getting Properties: \(error)")
                    return
                } else if querySnapshot!.documents.count == 0 {
                    dismissHUDForConnection()
                } else {
                    print("Properties count: \(querySnapshot!.documents.count)")
                    weakSelf.dismissHUD = true
                }
                
                
                weakSelf.propertiesListener = dbCollectionProperties().addSnapshotListener { (querySnapshot, error) in
                    DispatchQueue.main.async {
                        guard let weakSelf = self else {
                            return
                        }
                    
                        guard let snapshot = querySnapshot else {
                            if weakSelf.dismissHUD {
                                dismissHUDForConnection()
                                weakSelf.dismissHUD = false
                            }
                            print("Error fetching dbQueryDeficiencesWith snapshots: \(error!)")
                            return
                        }
                        snapshot.documentChanges.forEach { diff in
                            if (diff.type == .added) {
                                if weakSelf.dismissHUD {
                                    dismissHUDForConnection()
                                    weakSelf.dismissHUD = false
                                }
                                
                                let newProperty: (key: String, property: Property) = (diff.document.documentID, Mapper<Property>().map(JSONObject: diff.document.data())!)
                                weakSelf.allKeyProperties.append(newProperty)
                                weakSelf.updateSections()
                                weakSelf.tableView.reloadData()
                            } else if (diff.type == .modified) {
                                let changedProperty: (key: String, property: Property) = (diff.document.documentID, Mapper<Property>().map(JSONObject: diff.document.data())!)
                                if let index = weakSelf.allKeyProperties.index( where: { $0.key == diff.document.documentID} ) {
                                    weakSelf.allKeyProperties.remove(at: index)
                                    weakSelf.allKeyProperties.insert(changedProperty, at: index)
                                    weakSelf.updateSections()
                                    weakSelf.tableView.reloadData()
                                }
                            } else if (diff.type == .removed) {
                                if let index = weakSelf.allKeyProperties.index( where: { $0.key == diff.document.documentID} ) {
                                    weakSelf.allKeyProperties.remove(at: index)
                                    weakSelf.updateSections()
                                    weakSelf.tableView.reloadData()
                                }
                            }
                        }
                    }
                }
            }
        }
        
        
        teamsListener = dbCollectionTeams().addSnapshotListener { [weak self] (querySnapshot, error) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
            
                guard let snapshot = querySnapshot else {
                    print("Error fetching dbCollectionTeams snapshots: \(error!)")
                    return
                }
                snapshot.documentChanges.forEach { diff in
                    if (diff.type == .added) {
                        let newTeam: KeyTeam = (diff.document.documentID, Mapper<Team>().map(JSONObject: diff.document.data())!)
                        weakSelf.allKeyTeams.append(newTeam)
                        weakSelf.updateSections()
                        weakSelf.tableView.reloadData()
                    } else if (diff.type == .modified) {
                        let changedTeam: (key: String, team: Team) = (diff.document.documentID, Mapper<Team>().map(JSONObject: diff.document.data())!)
                        if let index = weakSelf.allKeyTeams.index( where: { $0.key == diff.document.documentID} ) {
                            weakSelf.allKeyTeams.remove(at: index)
                            weakSelf.allKeyTeams.insert(changedTeam, at: index)
                            weakSelf.updateSections()
                            weakSelf.tableView.reloadData()
                        }
                    } else if (diff.type == .removed) {
                        if let index = weakSelf.allKeyTeams.index( where: { $0.key == diff.document.documentID} ) {
                            weakSelf.allKeyTeams.remove(at: index)
                            weakSelf.updateSections()
                            weakSelf.tableView.reloadData()
                        }
                    }
                }
            }
        }
        
    }
}
