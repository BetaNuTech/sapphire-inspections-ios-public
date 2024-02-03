//
//  JobEditVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 12/30/21.
//  Copyright © 2021 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import FirebaseFirestore
import Alamofire

class JobEditVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    enum JobEditVCRows : Int {
        case title       = 0
        case need        = 1
        case projectType = 2
        case sow         = 3
        case trelloCard  = 4
        case bids        = 5
        case action      = 6
    }
    
    @IBOutlet var stateView: UIView!
    @IBOutlet var stateLabel: UILabel!
    @IBOutlet var cancelButton: UIBarButtonItem!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var navBar: UINavigationItem!
    
    // Inputs
    var keyProperty: (key: String, property: Property)?
    var keyJobToEdit: KeyJob?
    var keyJobToCreate: KeyJob?  // For New Jobs Only
    
    // This is used for only updating properties editted
    var keyJobToUpdate: KeyJob?
    
    var keyBids: [KeyBid] = []
    
    var isSaveAllowed = false
    var isUserAdmin = false
    var isUserCorporate = false

    var userListener: ListenerRegistration?
    var jobListener: ListenerRegistration?
    var bidsListener: ListenerRegistration?
    
    var dismissHUD = false

    deinit {
        if let listener = userListener {
            listener.remove()
        }
        if let listener = jobListener {
            listener.remove()
        }
        if let listener = bidsListener {
            listener.remove()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
            
        // Defaults
        saveButton.isEnabled = false
        removeCancelButton()
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.estimatedRowHeight = 21.0;
        tableView.keyboardDismissMode = UIScrollView.KeyboardDismissMode.none
        
        // Setup
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0.0
        } else {
            // Fallback on earlier versions
        }
        tableView.sectionHeaderHeight = 0.0
        tableView.sectionFooterHeight = 0.0

        updateStateViews()
        
        setObservers()
        
        if keyJobToEdit != nil {
            title = "View Job"
        } else {
            title = "New Job"
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func cancelButtonTapped(_ sender: UIBarButtonItem) {
        keyJobToUpdate = nil
        tableView.reloadData()
        saveButton.isEnabled = false
        removeCancelButton()
    }
    
    
    @IBAction func saveButtonTapped(_ sender: Any) {
        
        view.endEditing(true)
        
        guard let propertyKey = keyProperty?.key else {
            showAlertWithOkayButton(title: "Property Not Set", message: nil)
            return
        }
        
        guard let currentUserProfile = currentUserProfile else {
            showAlertWithOkayButton(title: "Not Logged In", message: nil)
            return
        }
        
        // Confirm user account is not disabled
        guard !currentUserProfile.isDisabled else {
            showAlertWithOkayButton(title: "User Account Disabled", message: nil)
            return
        }
        
        guard let keyJobToUpdate = keyJobToUpdate else {
            showAlertWithOkayButton(title: "Error: Nothing to update", message: nil)
            saveButton.isEnabled = false
            removeCancelButton()
            return
        }
            
        if keyJobToEdit != nil {
            // UPDATE JOB
            let parameters = keyJobToUpdate.job.toJSON()
            updateJobWith(propertyKey: propertyKey, jobId: keyJobToUpdate.key, parameters: parameters, dirtyUpdate: true, alertTitle: "Job Updated", alertMessage: nil)
        } else {
            guard let user = currentUser else {
                return
            }
            
            user.getIDToken { [weak self] (token, error) in
                guard let token = token else {
                    return
                }
                
                // NEW JOB
                let parameters = keyJobToUpdate.job.toJSON()
//                        let parameters: Parameters =  [
//                            "title": title,
//                            "need": need,
//                            "type": projectType.rawValue
//                        ]
                
                // Check for Title
                guard let title = keyJobToUpdate.job.title, title != "" else {
                    self?.showAlertWithOkayButton(title: "Title is required", message: nil)
                    return
                }
                
                // Check for Project Type
                guard keyJobToUpdate.job.type != nil else {
                    self?.showAlertWithOkayButton(title: "Project Type is required", message: nil)
                    return
                }
                
                let headers: HTTPHeaders = [
                    "Authorization": "FB-JWT \(token)",
                    "Content-Type": "application/json"
                ]
                
                presentHUDForConnection()

                AF.request(createNewJobURLString(propertyId: propertyKey), method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { [weak self] response in
                    
                    DispatchQueue.main.async {
                        debugPrint(response)
                        
                        if let statusCode = response.response?.statusCode, statusCode >= 200 && statusCode < 300 {
                            let alertController = UIAlertController(title: "New Job Created", message: nil, preferredStyle: .alert)
                            let okayAction = UIAlertAction(title: "OK", style: .default) { action in
                                self?.navigationController?.popViewController(animated: true)
                            }
                            alertController.addAction(okayAction)
                            self?.present(alertController, animated: true, completion: nil)
                        } else {
                           let errorMessage = firebaseAPIErrorMessages(data: response.data, error: response.error, statusCode: response.response?.statusCode)
                           let alertController = UIAlertController(title: "Error Creating Job", message: errorMessage, preferredStyle: .alert)
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
    
    func addCancelButton() {
        guard var leftBarButtonItems = navBar?.leftBarButtonItems else {
            return
        }
        
        if !leftBarButtonItems.contains(cancelButton) {
            leftBarButtonItems.append(cancelButton)
            navBar?.leftBarButtonItems = leftBarButtonItems
        }
    }
    
    func removeCancelButton() {
        guard var leftBarButtonItems = navBar?.leftBarButtonItems else {
            return
        }
        
        if let index = leftBarButtonItems.index(of: cancelButton) {
            leftBarButtonItems.remove(at: index)
            navBar?.leftBarButtonItems = leftBarButtonItems
        }
    }
        
    // MARK: UITableView DataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if keyJobToEdit == nil {
            return 3
        }
        
        if let keyJobToEdit = keyJobToEdit, let state = keyJobToEdit.job.state,
            state == JobState.open.rawValue || state == JobState.approved.rawValue {
            return 7 // Add Action Cell
        }
        
        return 6
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var job: Job?
        var jobId: String?
        if let keyJobToEdit = keyJobToEdit {
            job = keyJobToEdit.job
            jobId = keyJobToEdit.key
        } else if let keyJobToCreate = keyJobToCreate {
            job = keyJobToCreate.job
        }
        
        
        guard let job = job else {
            return UITableViewCell()
        }
        
        let rowType = JobEditVCRows(rawValue: indexPath.row)
        
        switch rowType {
        case .title:
            let cell = tableView.dequeueReusableCell(withIdentifier: "jobTitleEditCell") as? TextFieldEditTVCell ?? TextFieldEditTVCell()
            
            cell.delegate = self

            if let jobToUpdate = keyJobToUpdate?.job, let updatedTitle = jobToUpdate.title {
                cell.textField.text = updatedTitle
            } else {
                cell.textField.text = job.title
            }

            return cell
        case .need:
            let cell = tableView.dequeueReusableCell(withIdentifier: "jobNeedEditCell") as? TextViewEditTVCell ?? TextViewEditTVCell()
            
            cell.delegate = self
            
            if let jobToUpdate = keyJobToUpdate?.job, let updatedNeed = jobToUpdate.need {
                cell.textView.text = updatedNeed
            } else {
                cell.textView.text = job.need
            }

            return cell
        case .projectType:
            let cell = tableView.dequeueReusableCell(withIdentifier: "jobProjectTypeEditCell") as? JobProjectTypeEditTVCell ?? JobProjectTypeEditTVCell()
            
            cell.delegate = self

            if let jobToUpdate = keyJobToUpdate?.job, let updatedType = jobToUpdate.type {
                let projectType = JobProjectType(rawValue: updatedType)
                cell.setProjectType(projectType: projectType)
            } else if let type = job.type {
                let projectType = JobProjectType(rawValue: type)
                cell.setProjectType(projectType: projectType)
            } else {
                cell.setProjectType(projectType: nil)
            }
            
            return cell
        case .sow:
            let cell = tableView.dequeueReusableCell(withIdentifier: "sowEditCell") as? SOWEditTVCell ?? SOWEditTVCell()

            cell.delegate = self

            cell.uploadsButton.setTitle("0 Uploads", for: .normal)
            if let scopeOfWorkAttachments = job.scopeOfWorkAttachments {
                let count = scopeOfWorkAttachments.count
                if count > 1 {
                    cell.uploadsButton.setTitle("\(count) Uploads", for: .normal)
                } else {
                    cell.uploadsButton.setTitle("\(count) Upload", for: .normal)
                }
            }
            
            cell.uploadsButtonAction =  { [weak self] () in
                DispatchQueue.main.async {
                    self?.performSegue(withIdentifier: "showJobUploads", sender: nil)
                }
            }
            
            if let jobToUpdate = keyJobToUpdate?.job, let updatedSOW = jobToUpdate.scopeOfWork {
                cell.sowTextView.text = updatedSOW
            } else {
                cell.sowTextView.text = job.scopeOfWork
            }
            
            return cell
        case .trelloCard:
            let cell = tableView.dequeueReusableCell(withIdentifier: "jobTrelloCardCell") as? JobTrelloCardTVCell ?? JobTrelloCardTVCell()

            cell.viewController = self
            cell.delegate = self
            
            if let jobToUpdate = keyJobToUpdate?.job, let updatedtrelloCardURL = jobToUpdate.trelloCardURL {
                cell.trelloCardURL = updatedtrelloCardURL
            } else {
                cell.trelloCardURL = job.trelloCardURL
            }
            
            if cell.trelloCardURL == nil || cell.trelloCardURL == "" {
                cell.openButton.isEnabled = false
            } else {
                cell.openButton.isEnabled = true
            }
            
            return cell
        case .bids:
            let cell = tableView.dequeueReusableCell(withIdentifier: "jobBidsCell") as? JobBidsTVCell ?? JobBidsTVCell()

            // # of Bids required
            if let minBids = job.minBids {
                if keyBids.count >= minBids {
                    cell.bidsLabel.text = "✓ Bids (\(minBids)+ required)"
                } else {
                    cell.bidsLabel.text = "Bids (\(minBids)+ required)"
                }
            } else {
                cell.bidsLabel.text = "Bids"
            }
            
            // Default, hidden
            cell.expediteButton.isHidden = true
            
            if let authorizedRules = job.authorizedRules {
                switch authorizedRules {
                case JobAuthorizedRule.expediteRule.rawValue:
                    cell.expediteButton.isHidden = false
                    cell.expediteButton.setTitle("Expedited ✓", for: .normal)
                    if let expediteReason = job.expediteReason {
                        cell.expediteButtonAction = { [weak self] () in
                            self?.showAlertWithOkayButton(title: "Expedited Reason", message: expediteReason)
                        }
                    } else {
                        cell.expediteButtonAction = nil
                    }
                default:
                    if let minBids = job.minBids, keyBids.count < minBids,
                        let state = job.state, state == JobState.approved.rawValue {
                        
                        cell.expediteButton.isHidden = false
                        cell.expediteButton.setTitle("Expedite", for: .normal)
                        cell.expediteButtonAction = { [weak self] () in
                            DispatchQueue.main.async {
                                self?.showTextInputPrompt(withMessage: "Expedite Reason?") { (userPressedOK, userInput) in
                                    
                                    if userPressedOK && userInput != "" {
                                        let parameters: Parameters = ["authorizedRules": "expedite"]
                                        
                                        guard let propertyKey = self?.keyProperty?.key else {
                                            return
                                        }

                                        guard let jobId = jobId else {
                                            return
                                        }

                                        self?.updateJobWith(propertyKey: propertyKey, jobId: jobId, parameters: parameters, dirtyUpdate: false, alertTitle: "Job Expedited", alertMessage: "The minimum number of bids required is now set to 1.")
                                    } else if userPressedOK {
                                        self?.showAlertWithOkayButton(title: "Invalid Input", message: "A reason is required for expediting.")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Default
            cell.completedApprovedLabel.text = "APPROVED"
            
            let completedKeyBids: [KeyBid] = keyBids.filter({ $0.bid.state == BidState.complete.rawValue })
            if completedKeyBids.count > 0 {
                cell.completedApprovedLabel.text = "COMPLETE"
                var newVendorList = ""
                completedKeyBids.forEach { keyBid in
                    if newVendorList != "" {
                        newVendorList += "\n"
                    }
                    newVendorList += keyBid.bid.vendor ?? "Unknown"
                }
                cell.completedApprovedBidsLabel.text = newVendorList
            } else {
                let approvedKeyBids: [KeyBid] = keyBids.filter({ $0.bid.state == BidState.approved.rawValue })
                var newVendorList = ""
                approvedKeyBids.forEach { keyBid in
                    if newVendorList != "" {
                        newVendorList += "\n"
                    }
                    newVendorList += keyBid.bid.vendor ?? "Unknown"
                }
                cell.completedApprovedBidsLabel.text = newVendorList
            }
            let openKeyBids: [KeyBid] = keyBids.filter({ $0.bid.state == BidState.open.rawValue })
            var newVendorList = ""
            openKeyBids.forEach { keyBid in
                if newVendorList != "" {
                    newVendorList += "\n"
                }
                newVendorList += keyBid.bid.vendor ?? "Unknown"
            }
            cell.openBidsLabel.text = newVendorList
            
            let rejectedKeyBids: [KeyBid] = keyBids.filter({ $0.bid.state == BidState.rejected.rawValue })
            newVendorList = ""
            rejectedKeyBids.forEach { keyBid in
                if newVendorList != "" {
                    newVendorList += "\n"
                }
                newVendorList += keyBid.bid.vendor ?? "Unknown"
            }
            cell.rejectedBidsLabel.text = newVendorList
            
            let incompleteKeyBids: [KeyBid] = keyBids.filter({ $0.bid.state == BidState.incomplete.rawValue })
            newVendorList = ""
            incompleteKeyBids.forEach { keyBid in
                if newVendorList != "" {
                    newVendorList += "\n"
                }
                newVendorList += keyBid.bid.vendor ?? "Unknown"
            }
            cell.incompleteBidsLabel.text = newVendorList

            return cell
            
        case .action:
            let cell = tableView.dequeueReusableCell(withIdentifier: "jobActionCell") as? JobActionTVCell ?? JobActionTVCell()
            switch job.state {
            case JobState.open.rawValue:
                cell.actionButton.setTitle("APPROVE JOB", for: .normal)
                cell.actionButton.configuration?.baseBackgroundColor = GlobalColors.sectionHeaderBlue
                cell.actionButton.isEnabled = true
                cell.actionButtonAction = { [weak self] in
                    guard let weakSelf = self else {
                        return
                    }
                    guard weakSelf.keyJobToUpdate == nil else {
                        weakSelf.showAlertWithOkayButton(title: "Unsaved Edit(s)", message: "Please Save or Cancel your edits prior to changing the job's state.")
                        return
                    }
                    guard let propertyKey = weakSelf.keyProperty?.key else {
                        return
                    }
                    guard let jobId = jobId else {
                        return
                    }
                    
                    guard weakSelf.isApprovalAllowed() else {
                        weakSelf.showAlertWithOkayButton(title: "Missing SOW", message: "A Scope of Work is required before approval.")
                        return
                    }

                    let parameters: Parameters = ["state": JobState.approved.rawValue]
                    weakSelf.updateJobWith(propertyKey: propertyKey, jobId: jobId, parameters: parameters, dirtyUpdate: false, alertTitle: "Job Approved", alertMessage: "Please enter the required number of bids, with one bid approved, before authorizing the job.")
                }
            case JobState.approved.rawValue:
                cell.actionButton.setTitle("AUTHORIZE JOB", for: .normal)
                cell.actionButton.configuration?.baseBackgroundColor = GlobalColors.sectionHeaderGreen
                cell.actionButton.isEnabled = true
                cell.actionButtonAction = { [weak self] in
                    guard let weakSelf = self else {
                        return
                    }
                    guard weakSelf.keyJobToUpdate == nil else {
                        weakSelf.showAlertWithOkayButton(title: "Unsaved Edit(s)", message: "Please Save or Cancel your edits prior to changing the job's state.")
                        return
                    }
                    guard let propertyKey = weakSelf.keyProperty?.key else {
                        return
                    }
                    guard let jobId = jobId else {
                        return
                    }
                    
                    let (minBidsMet, approvedBidExists) = weakSelf.isAuthorizationAllowed()
                    
                    guard minBidsMet else {
                        weakSelf.showAlertWithOkayButton(title: "Bids Requirement Not Met", message: "There must be enough bids, before the job can be authorized.")
                        return
                    }

                    guard approvedBidExists else {
                        weakSelf.showAlertWithOkayButton(title: "Approved Bid Required", message: "There must be an approved bid, before the job can be authorized.")
                        return
                    }

                    let parameters: Parameters = ["state": JobState.authorized.rawValue]
                    weakSelf.updateJobWith(propertyKey: propertyKey, jobId: jobId, parameters: parameters, dirtyUpdate: false, alertTitle: "Job Authorized", alertMessage: "Once a bid is completed, the job will be completed as well.")
                }
            default:
                print("INVALID JOB STATE FOR ACTION")
                cell.actionButton.isHidden = true
            }
            
            return cell

        default:
            return UITableViewCell()
        }
    }
        
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    
    // MARK: UITableView Delegates
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        view.endEditing(true)

        guard let rowType = JobEditVCRows(rawValue: indexPath.row) else {
            return
        }

        guard rowType == JobEditVCRows.bids else {
            return
        }
        
        var job: Job?
        if let keyJobToEdit = keyJobToEdit {
            job = keyJobToEdit.job
        } else if let keyJobToCreate = keyJobToCreate {
            job = keyJobToCreate.job
        }
        guard let job = job else {
            return
        }
        
        switch job.state {
        case JobState.open.rawValue:
            showAlertWithOkayButton(title: "Job must be approved before managing bids.", message: nil)
        default:
            performSegue(withIdentifier: "showJobBids", sender: self)
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    // MARK: Keyboard

    @objc private func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardSize.height - view.safeAreaInsets.bottom, right: 0)
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        tableView.contentInset = .zero
    }
    
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showJobUploads" {
            if let vc = segue.destination as? JobEditUploadsVC {
                vc.keyJobToEdit = keyJobToEdit
                vc.keyProperty = keyProperty
            }
        }
        if segue.identifier == "showJobBids" {
            if let vc = segue.destination as? BidsListVC {
                vc.keyJob = keyJobToEdit
                vc.keyProperty = keyProperty
            }
        }
    }
    
    // MARK: Private Methods

    private
    
    func isApprovalAllowed() -> Bool {
        guard let job = keyJobToEdit?.job else {
            return false
        }
        if let scopeOfWork = job.scopeOfWork, scopeOfWork != "" {
            return true
        } else if let scopeOfWorkAttachments = job.scopeOfWorkAttachments, scopeOfWorkAttachments.count > 0 {
            return true
        }
        
        return false
    }
    
    // (minBids met, approved bid exists)
    func isAuthorizationAllowed() -> (Bool, Bool) {
        guard let job = keyJobToEdit?.job else {
            return (false, false)
        }
        guard let minBids = job.minBids else {
            return (false, false)
        }
        
        if keyBids.count >= minBids {
            let filteredKeyBids = keyBids.filter( { $0.bid.state ?? "" == BidState.approved.rawValue } )
            if filteredKeyBids.count > 0 {
                return (true, true)
            } else {
                return (true, false)
            }
        }
        
        return (false, false)
    }
    
    func updateJobWith(propertyKey: String, jobId: String, parameters: Parameters, dirtyUpdate: Bool, alertTitle: String, alertMessage: String?) {
        
        guard let user = currentUser else {
            return
        }
        
        user.getIDToken { [weak self] (token, error) in
            guard let token = token else {
                return
            }
            
            let headers: HTTPHeaders = [
                "Authorization": "FB-JWT \(token)",
                "Content-Type": "application/json"
            ]
            
            presentHUDForConnection()

            AF.request(updateJobURLString(propertyId: propertyKey, jobId: jobId), method: .put, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
                
                DispatchQueue.main.async {
                    debugPrint(response)
                    
                    if let statusCode = response.response?.statusCode, statusCode >= 200 && statusCode < 300 {
                        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
                        let okayAction = UIAlertAction(title: "OK", style: .default) { action in
                            if dirtyUpdate {
                                self?.keyJobToUpdate = nil
                                self?.saveButton.isEnabled = false
                                self?.removeCancelButton()
                            }
                        }
                        alertController.addAction(okayAction)
                        self?.present(alertController, animated: true, completion: nil)
                    } else {
                       let errorMessage = firebaseAPIErrorMessages(data: response.data, error: response.error, statusCode: response.response?.statusCode)
                       let alertController = UIAlertController(title: "Error Updating Job", message: errorMessage, preferredStyle: .alert)
                       let okayAction = UIAlertAction(title: "OK", style: .default)
                       alertController.addAction(okayAction)
                       self?.present(alertController, animated: true, completion: nil)
                    }
                    
                    dismissHUDForConnection()
                }

            }
        }
    }
    
    func updateStateViews() {
        if keyJobToCreate != nil && keyJobToEdit == nil {
            stateView.backgroundColor = .white
            stateLabel.textColor = .black
            stateLabel.text = ""
            return
        }
        
        guard let job = keyJobToEdit?.job else {
            return
        }
        
        switch job.state {
        case JobState.open.rawValue:
            stateView.backgroundColor = GlobalColors.sectionHeaderPurple
            stateLabel.textColor = .white
            stateLabel.text = "OPEN (Approve with required SOW)"
        case JobState.approved.rawValue:
            stateView.backgroundColor = GlobalColors.sectionHeaderBlue
            stateLabel.textColor = .white
            stateLabel.text = "APPROVED (Authorize after bid approved)"
        case JobState.authorized.rawValue:
            stateView.backgroundColor = GlobalColors.sectionHeaderGreen
            stateLabel.textColor = .white
            stateLabel.text = "AUTHORIZED (Completed when bid completed)"
        case JobState.complete.rawValue:
            stateView.backgroundColor = GlobalColors.veryLightBlue
            stateLabel.textColor = .white
            stateLabel.text = "COMPLETED"

        default:
            stateView.backgroundColor = .red
            stateLabel.textColor = .white
            stateLabel.text = "UNKNOWN STATE"
        }
        
    }
    
    func sortBids() {
        keyBids = sortKeyBids(keyBids, bidsSort: .vendor)
    }
    
    func setObservers() {
        if let user = currentUser {
            userListener = dbDocumentUserWith(userId: user.uid).addSnapshotListener({ [weak self] (documentSnapshot, error) in
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        return
                    }
                    
                    print("Current User Profile Updated, observed by TemplateCategoriesVC")
                    if let document = documentSnapshot, document.exists {
                        if let profile = Mapper<UserProfile>().map(JSONObject: document.data()), !profile.isDisabled {
                            var property = false
                            if let keyProperty = weakSelf.keyProperty, let propertyValue = profile.properties[keyProperty.key] as? NSNumber , propertyValue.boolValue {
                                property = true
                            }
                            var team = false
                            if let keyProperty = weakSelf.keyProperty {
                                for teamDict in profile.teams.values {
                                    if let dict = teamDict as? [String : AnyObject] {
                                        if let propertyValue = dict[keyProperty.key] as? NSNumber, propertyValue.boolValue {
                                            team = true
                                            break
                                        }
                                    }
                                }
                            }
                        
                            weakSelf.isSaveAllowed = profile.admin || profile.corporate || property || team
                            weakSelf.isUserAdmin = profile.admin
                            weakSelf.isUserCorporate = profile.corporate
                        } else {
                            weakSelf.isSaveAllowed = false
                        }
                    }
                    
                    dismissHUDForConnection()
                }
            })
        }
        
        if let jobKey = keyJobToEdit?.key {
            jobListener = dbDocumentJobWith(documentId: jobKey).addSnapshotListener({ [weak self] (documentSnapshot, error) in
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        return
                    }
                    
                    if let document = documentSnapshot, document.exists {
                        print("Job Updated")
                        let updatedJob: KeyJob = (document.documentID, Mapper<Job>().map(JSONObject: document.data())!)
                        weakSelf.keyJobToEdit = updatedJob
                        weakSelf.tableView.reloadData()
                        weakSelf.updateStateViews()
                    } else {
                        print("ERROR: Property Not Found")
                    }
                }
            })
            
            bidsListener = dbQueryBidsWith(jobId: jobKey).addSnapshotListener { [weak self] (querySnapshot, error) in
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        return
                    }
                    
                    guard let snapshot = querySnapshot else {
                        print("Error fetching dbQueryBidsWith snapshot: \(error!)")
                        return
                    }
                    snapshot.documentChanges.forEach { diff in
                        if (diff.type == .added) {
                            let newBid = KeyBid(key: diff.document.documentID, bid: Mapper<Bid>().map(JSONObject: diff.document.data())!)
                            weakSelf.keyBids.append(newBid)
                        } else if (diff.type == .modified) {
                            let changedBid: KeyBid = (diff.document.documentID, Mapper<Bid>().map(JSONObject: diff.document.data())!)
                            if let index = weakSelf.keyBids.index( where: { $0.key == diff.document.documentID} ) {
                                weakSelf.keyBids.remove(at: index)
                                weakSelf.keyBids.insert(changedBid, at: index)
                            }
                        } else if (diff.type == .removed) {
                            if let index = weakSelf.keyBids.index( where: { $0.key == diff.document.documentID} ) {
                                weakSelf.keyBids.remove(at: index)
                            }
                        }
                        
                        weakSelf.sortBids()
                        weakSelf.tableView.reloadData()
                    }
                }
            }
            
        }
        
        presentHUDForConnection()
    }
    
    func updateSaveCancelButtons() {
        if isSaveAllowed {
            addCancelButton()
            saveButton.isEnabled = true
        }
    }
    
    func getJobId() -> String? {
        var jobId: String?
        if let keyJobToEdit = keyJobToEdit {
            jobId = keyJobToEdit.key
        } else if let keyJobToCreate = keyJobToCreate {
            jobId = keyJobToCreate.key
        }
        
        return jobId
    }
    
}


extension JobEditVC: TextFieldEditTVCellDelegate {
    
    func textFieldUpdated(text: String) {
        updateSaveCancelButtons()
        
        guard let jobId = getJobId() else {
            return
        }
        
        if keyJobToUpdate == nil {
            let newJobToUpdateJSON: [String: Any] = [
                "title" : text
            ]
            guard let newJobToUpdate = Mapper<Job>().map(JSON: newJobToUpdateJSON) else {
                print("newJobToUpdate model failed to map")
                return
            }
            keyJobToUpdate = (key: jobId, job: newJobToUpdate)
        } else {
            keyJobToUpdate!.job.title = text
        }
    }
}

extension JobEditVC: TextViewEditTVCellDelegate {
    
    func textViewUpdated(text: String) {
        updateSaveCancelButtons()
        
        guard let jobId = getJobId() else {
            return
        }
        
        if keyJobToUpdate == nil {
            let newJobToUpdateJSON: [String: Any] = [
                "need" : text
            ]
            guard let newJobToUpdate = Mapper<Job>().map(JSON: newJobToUpdateJSON) else {
                print("newJobToUpdate model failed to map")
                return
            }
            keyJobToUpdate = (key: jobId, job: newJobToUpdate)
        } else {
            keyJobToUpdate!.job.need = text
        }
    }
}

extension JobEditVC: JobProjectTypeEditTVCellDelegate {
    
    func projectTypeUpdated(type: JobProjectType) {
        updateSaveCancelButtons()
        
        guard let jobId = getJobId() else {
            return
        }
        
        if keyJobToUpdate == nil {
            let newJobToUpdateJSON: [String: Any] = [
                "type" : type.rawValue
            ]
            guard let newJobToUpdate = Mapper<Job>().map(JSON: newJobToUpdateJSON) else {
                print("newJobToUpdate model failed to map")
                return
            }
            keyJobToUpdate = (key: jobId, job: newJobToUpdate)
        } else {
            keyJobToUpdate!.job.type = type.rawValue
        }
    }
}

extension JobEditVC: SOWEditTVCellDelegate {
    
    func scopeOfWorkUpdated(text: String) {
        updateSaveCancelButtons()

        guard let jobId = getJobId() else {
            return
        }
        
        if keyJobToUpdate == nil {
            let newJobToUpdateJSON: [String: Any] = [
                "scopeOfWork" : text
            ]
            guard let newJobToUpdate = Mapper<Job>().map(JSON: newJobToUpdateJSON) else {
                print("newJobToUpdate model failed to map")
                return
            }
            keyJobToUpdate = (key: jobId, job: newJobToUpdate)
        } else {
            keyJobToUpdate!.job.scopeOfWork = text
        }
    }
}

extension JobEditVC: JobTrelloCardTVCellDelegate {
    
    func trelloCardURLUpdated(text: String) {
        updateSaveCancelButtons()

        guard let jobId = getJobId() else {
            return
        }
        
        if keyJobToUpdate == nil {
            let newJobToUpdateJSON: [String: Any] = [
                "trelloCardURL" : text
            ]
            guard let newJobToUpdate = Mapper<Job>().map(JSON: newJobToUpdateJSON) else {
                print("newJobToUpdate model failed to map")
                return
            }
            keyJobToUpdate = (key: jobId, job: newJobToUpdate)
        } else {
            keyJobToUpdate!.job.trelloCardURL = text
        }
    }
}
