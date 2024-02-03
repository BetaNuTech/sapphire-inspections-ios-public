//
//  JobBidEditVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 3/16/22.
//  Copyright © 2022 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import FirebaseFirestore
import Alamofire

class JobBidEditVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    enum BidEditVCRows : Int {
        case vendor         = 0
        case vendorDetails  = 1
        case scope          = 2
        case cost           = 3
        case timeline       = 4
        case vendorSwitches = 5
        case attachments    = 6
        case action         = 7
    }
    
    @IBOutlet var stateView: UIView!
    @IBOutlet var stateLabel: UILabel!
    @IBOutlet var cancelButton: UIBarButtonItem!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var navBar: UINavigationItem!
    
    // Inputs
    var keyProperty: KeyProperty?
    var keyJob: KeyJob?
    var keyBidToEdit: KeyBid?
    var keyBidToCreate: KeyBid?  // For New Bids Only

    // This is used for only updating properties editted
    var keyBidToUpdate: KeyBid?
    
    var keyBids: [KeyBid] = [] // We need to monitor all bids at once
    
    var isSaveAllowed = false
    var isUserAdmin = false
    var isUserCorporate = false

    var userListener: ListenerRegistration?
    var bidListener:  ListenerRegistration?
    var bidsListener: ListenerRegistration?

    var dismissHUD = false

    deinit {
        if let listener = userListener {
            listener.remove()
        }
        if let listener = bidListener {
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
        
        if keyBidToEdit != nil {
            title = "View Bid"
        } else {
            title = "New Bid"
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
        keyBidToUpdate = nil
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

        guard let jobKey = keyJob?.key else {
            showAlertWithOkayButton(title: "Job Not Set", message: nil)
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
        
        guard let keyBidToUpdate = keyBidToUpdate else {
            showAlertWithOkayButton(title: "Error: Nothing to update", message: nil)
            saveButton.isEnabled = false
            removeCancelButton()
            return
        }
        

        if keyBidToEdit != nil {
            // UPDATE BID
            let parameters = keyBidToUpdate.bid.toJSON()
            updateBidWith(propertyId: propertyKey, jobId: jobKey, bidId: keyBidToUpdate.key, parameters: parameters, dirtyUpdate: true, alertTitle: "Bid Updated", alertMessage: nil)
        } else {
            guard let user = currentUser else {
                return
            }
            
            user.getIDToken { [weak self] (token, error) in
                guard let token = token else {
                    return
                }
                
                // NEW JOB
                let parameters = keyBidToUpdate.bid.toJSON()
//                        let parameters: Parameters =  [
//                            "title": title,
//                            "need": need,
//                            "type": projectType.rawValue
//                        ]
                
                // Check for Title
                guard let vendor = keyBidToUpdate.bid.vendor, vendor != "" else {
                    self?.showAlertWithOkayButton(title: "Vendor name is required", message: nil)
                    return
                }
                
                // Check for Project Type
                guard keyBidToUpdate.bid.scope != nil else {
                    self?.showAlertWithOkayButton(title: "Scope is required", message: nil)
                    return
                }
                
                let headers: HTTPHeaders = [
                    "Authorization": "FB-JWT \(token)",
                    "Content-Type": "application/json"
                ]
                
                presentHUDForConnection()

                AF.request(createNewBidURLString(propertyId: propertyKey, jobId: jobKey), method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { [weak self] response in
                    
                    DispatchQueue.main.async {
                        debugPrint(response)
                        
                        if let statusCode = response.response?.statusCode, statusCode >= 200 && statusCode < 300 {
                            let alertController = UIAlertController(title: "New Bid Created", message: nil, preferredStyle: .alert)
                            let okayAction = UIAlertAction(title: "OK", style: .default) { action in
                                self?.navigationController?.popViewController(animated: true)
                            }
                            alertController.addAction(okayAction)
                            self?.present(alertController, animated: true, completion: nil)
                        } else {
                           let errorMessage = firebaseAPIErrorMessages(data: response.data, error: response.error, statusCode: response.response?.statusCode)
                           let alertController = UIAlertController(title: "Error Creating Bid", message: errorMessage, preferredStyle: .alert)
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
        if keyBidToEdit == nil {
            return 6
        }
        
        if let keyBidToEdit = keyBidToEdit, let state = keyBidToEdit.bid.state,
            (state == BidState.open.rawValue ||
            state == BidState.approved.rawValue ||
            state == BidState.rejected.rawValue) {
            return 8 // Add Action Cell
        }
        
        return 7
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var bid: Bid?
        var bidId: String?
        if let keyBidToEdit = keyBidToEdit {
            bid = keyBidToEdit.bid
            bidId = keyBidToEdit.key
        } else if let keyBidToCreate = keyBidToCreate {
            bid = keyBidToCreate.bid
        }
        
        guard let bid = bid else {
            return UITableViewCell()
        }
        
        let rowType = BidEditVCRows(rawValue: indexPath.row)
        
        switch rowType {
        case .vendor:
            let cell = tableView.dequeueReusableCell(withIdentifier: "bidVendorEditCell") as? TextFieldEditTVCell ?? TextFieldEditTVCell()
            
            cell.delegate = self

            if let bidToUpdate = keyBidToUpdate?.bid, let updatedVendor = bidToUpdate.vendor {
                cell.textField.text = updatedVendor
            } else {
                cell.textField.text = bid.vendor
            }

            return cell
        case .vendorDetails:
            let cell = tableView.dequeueReusableCell(withIdentifier: "bidVendorDetailsEditCell") as? TextViewEditTVCell ?? TextViewEditTVCell()
            
            cell.delegate = self
            
            if let bidToUpdate = keyBidToUpdate?.bid, let updatedVendorDetails = bidToUpdate.vendorDetails {
                cell.textView.text = updatedVendorDetails
            } else {
                cell.textView.text = bid.vendorDetails
            }

            return cell
        case .scope:
            let cell = tableView.dequeueReusableCell(withIdentifier: "bidScopeEditCell") as? BidScopeEditTVCell ?? BidScopeEditTVCell()
            
            cell.delegate = self
            
            if let bidToUpdate = keyBidToUpdate?.bid, let scope = bidToUpdate.scope {
                let bidScope = BidScope(rawValue: scope)
                cell.setScope(scope: bidScope)
            } else if let scope = bid.scope {
                let bidScope = BidScope(rawValue: scope)
                cell.setScope(scope: bidScope)
            } else {
                cell.setScope(scope: nil)
            }

            return cell
        case .cost:
            let cell = tableView.dequeueReusableCell(withIdentifier: "bidCostEditCell") as? BidCostEditTVCell ?? BidCostEditTVCell()
            
            cell.delegate = self
            
            var costMin = bid.costMin
            var costMax = bid.costMax

            if let bidToUpdate = keyBidToUpdate?.bid {
                if let value = bidToUpdate.costMin {
                    costMin = value
                }
                if let value = bidToUpdate.costMax {
                    costMax = value
                }
            }
            
            cell.setCost(costMin: costMin, costMax: costMax)

            return cell
        case .timeline:
            let cell = tableView.dequeueReusableCell(withIdentifier: "bidTimelineEditCell") as? BidTimelineEditTVCell ?? BidTimelineEditTVCell()
            
            cell.delegate = self
            
            var startAtDate = bid.startAt != nil ? Date(timeIntervalSince1970: bid.startAt!.doubleValue) : nil
            var completeAtAtDate = bid.completeAt != nil ? Date(timeIntervalSince1970: bid.completeAt!.doubleValue) : nil

            if let bidToUpdate = keyBidToUpdate?.bid {
                if let value = bidToUpdate.startAt {
                    let date = Date(timeIntervalSince1970: value.doubleValue)
                    startAtDate = date
                }
                if let value = bidToUpdate.completeAt {
                    let date = Date(timeIntervalSince1970: value.doubleValue)
                    completeAtAtDate = date
                }
            }
            
            cell.setDates(startAtDate: startAtDate, completeAtDate: completeAtAtDate)
            
            return cell
        case .vendorSwitches:
            let cell = tableView.dequeueReusableCell(withIdentifier: "bidVendorSwitchesEditCell") as? BidVendorSwitchesEditTVCell ?? BidVendorSwitchesEditTVCell()
            
            cell.delegate = self
            
            var vendorW9 = bid.vendorW9
            var vendorInsurance = bid.vendorInsurance
            var vendorLicense = bid.vendorLicense

            if let bidToUpdate = keyBidToUpdate?.bid {
                if let value = bidToUpdate.vendorW9 {
                    vendorW9 = value
                }
                if let value = bidToUpdate.vendorInsurance {
                    vendorInsurance = value
                }
                if let value = bidToUpdate.vendorLicense {
                    vendorLicense = value
                }
            }
            
            cell.setSwitches(hasW9: vendorW9, hasInsurance: vendorInsurance, hasLicense: vendorLicense)
            
            return cell
        case .attachments:
            let cell = tableView.dequeueReusableCell(withIdentifier: "bidAttachmentsEditCell") as? BidAttachmentsEditTVCell ?? BidAttachmentsEditTVCell()
            
            cell.uploadsButton.setTitle("0 Uploads", for: .normal)
            if let attachments = bid.attachments {
                let count = attachments.count
                if count > 1 {
                    cell.uploadsButton.setTitle("\(count) Uploads", for: .normal)
                } else {
                    cell.uploadsButton.setTitle("\(count) Upload", for: .normal)
                }
            }
            
            cell.uploadsButtonAction =  { [weak self] () in
                DispatchQueue.main.async {
                    self?.performSegue(withIdentifier: "showBidUploads", sender: nil)
                }
            }
            
            return cell
        case .action:
            guard let propertyId = keyProperty?.key else {
                return UITableViewCell()
            }
            guard let jobId = keyJob?.key else {
                return UITableViewCell()
            }
            guard let bidId = bidId else {
                return UITableViewCell()
            }
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "bidActionsCell") as? BidActionsTVCell ?? BidActionsTVCell()
            switch bid.state {
            case BidState.open.rawValue:
                cell.action1Button.setTitle("APPROVE BID", for: .normal)
                cell.action1Button.configuration?.baseBackgroundColor = GlobalColors.sectionHeaderBlue
                cell.action1Button.isHidden = false
                cell.action1Button.isEnabled = true

                cell.action2View.isHidden = true
                cell.action3View.isHidden = true

                cell.action1ButtonAction = { [weak self] in
                    guard let weakSelf = self else {
                        return
                    }
                    guard weakSelf.keyBidToUpdate == nil else {
                        weakSelf.showAlertWithOkayButton(title: "Unsaved Edit(s)", message: "Please Save or Cancel your edits prior to changing the bid's state.")
                        return
                    }
                    
                    guard !weakSelf.jobHasApprovedBid() else {
                        weakSelf.showAlertWithOkayButton(title: "Another Bid Approved", message: "A job can only have one approved bid.  If needed, reject or incomplete other approved bid first.")
                        return
                    }

                    guard !weakSelf.jobHasCompletedBid() else {
                        weakSelf.showAlertWithOkayButton(title: "Another Bid Completed", message: "A job can only have one completed bid.  Create a new job to manage new bids.")
                        return
                    }
                    
                    let parameters: Parameters = ["state": BidState.approved.rawValue]
                    weakSelf.updateBidWith(propertyId: propertyId, jobId: jobId, bidId: bidId, parameters: parameters, dirtyUpdate: false, alertTitle: "Bid Approved", alertMessage: "Job must now be authorized, before work can begin.")
                }
            case BidState.approved.rawValue:
                cell.action1Button.setTitle("COMPLETE BID", for: .normal)
                cell.action1Button.configuration?.baseBackgroundColor = GlobalColors.veryLightBlue
                cell.action1View.isHidden = false
                cell.action1Button.isEnabled = true

                cell.action2Button.setTitle("REJECT BID", for: .normal)
                cell.action2Button.configuration?.baseBackgroundColor = GlobalColors.sectionHeaderBrightRed
                cell.action2View.isHidden = false
                cell.action2Button.isEnabled = true

                cell.action3Button.setTitle("INCOMPLETE BID", for: .normal)
                cell.action3Button.configuration?.baseBackgroundColor = GlobalColors.sectionHeaderOrange
                cell.action3View.isHidden = false
                cell.action3Button.isEnabled = true
                
                cell.action1ButtonAction = { [weak self] in
                    guard let weakSelf = self else {
                        return
                    }
                    guard weakSelf.keyBidToUpdate == nil else {
                        weakSelf.showAlertWithOkayButton(title: "Unsaved Edit(s)", message: "Please Save or Cancel your edits prior to changing the bid's state.")
                        return
                    }
                    
                    guard weakSelf.jobIsAuthorized() else {
                        weakSelf.showAlertWithOkayButton(title: "Job Not Authorized", message: "Job has yet been authorized.  Once authorized, the bid can be marked complete, which also completes the job.")
                        return
                    }
                    
                    let parameters: Parameters = ["state": BidState.complete.rawValue]
                    weakSelf.updateBidWith(propertyId: propertyId, jobId: jobId, bidId: bidId, parameters: parameters, dirtyUpdate: false, alertTitle: "Bid Completed", alertMessage: "Job will also be completed, automatically.")
                }
                cell.action2ButtonAction = { [weak self] in
                    guard let weakSelf = self else {
                        return
                    }
                    guard weakSelf.keyBidToUpdate == nil else {
                        weakSelf.showAlertWithOkayButton(title: "Unsaved Edit(s)", message: "Please Save or Cancel your edits prior to changing the bid's state.")
                        return
                    }

                    let parameters: Parameters = ["state": BidState.rejected.rawValue]
                    weakSelf.updateBidWith(propertyId: propertyId, jobId: jobId, bidId: bidId, parameters: parameters, dirtyUpdate: false, alertTitle: "Bid Rejected", alertMessage: nil)
                }
                cell.action3ButtonAction = { [weak self] in
                    guard let weakSelf = self else {
                        return
                    }
                    guard weakSelf.keyBidToUpdate == nil else {
                        weakSelf.showAlertWithOkayButton(title: "Unsaved Edit(s)", message: "Please Save or Cancel your edits prior to changing the bid's state.")
                        return
                    }
                    
                    guard weakSelf.jobIsAuthorized() else {
                        weakSelf.showAlertWithOkayButton(title: "Job Not Authorized", message: "Job has yet been authorized.  Once authorized, the bid can be marked incomplete, allowing for another bid to be approved.")
                        return
                    }

                    let parameters: Parameters = ["state": BidState.incomplete.rawValue]
                    weakSelf.updateBidWith(propertyId: propertyId, jobId: jobId, bidId: bidId, parameters: parameters, dirtyUpdate: false, alertTitle: "Bid is Incomplete", alertMessage: nil)
                }
            case BidState.rejected.rawValue:
                cell.action1Button.setTitle("RE-OPEN BID", for: .normal)
                cell.action1Button.configuration?.baseBackgroundColor = GlobalColors.sectionHeaderPurple
                cell.action1Button.isHidden = false
                cell.action1Button.isEnabled = true

                cell.action2View.isHidden = true
                cell.action3View.isHidden = true
                
                cell.action1ButtonAction = { [weak self] in
                    guard let weakSelf = self else {
                        return
                    }
                    guard weakSelf.keyBidToUpdate == nil else {
                        weakSelf.showAlertWithOkayButton(title: "Unsaved Edit(s)", message: "Please Save or Cancel your edits prior to changing the bid's state.")
                        return
                    }
                    
                    guard !weakSelf.jobHasCompletedBid() else {
                        weakSelf.showAlertWithOkayButton(title: "Another Bid Completed", message: "A job can only have one completed bid.  Create a new job to manage new bids.")
                        return
                    }

                    let parameters: Parameters = ["state": BidState.open.rawValue]
                    weakSelf.updateBidWith(propertyId: propertyId, jobId: jobId, bidId: bidId, parameters: parameters, dirtyUpdate: false, alertTitle: "Bid Re-Opened", alertMessage: nil)
                }
            default:
                print("INVALID BID STATE FOR ACTION")
                cell.action1Button.isHidden = true
                cell.action2Button.isHidden = true
                cell.action3Button.isHidden = true
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
        
//        guard let rowType = BidEditVCRows(rawValue: indexPath.row) else {
//            return
//        }

//        guard rowType == BidEditVCRows.bids else {
//            return
//        }
//
//        var job: Job?
//        if let keyJobToEdit = keyJobToEdit {
//            job = keyJobToEdit.job
//        } else if let keyJobToCreate = keyJobToCreate {
//            job = keyJobToCreate.job
//        }
//        guard let job = job else {
//            return
//        }
//
//        switch job.state {
//        case JobState.open.rawValue:
//            showAlertWithOkayButton(title: "Job must be approved before managing bids.", message: nil)
//        default:
//            performSegue(withIdentifier: "showJobBids", sender: self)
//        }
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
        if segue.identifier == "showBidUploads" {
            if let vc = segue.destination as? JobEditUploadsVC {
                vc.areBidUploads = true
                vc.keyBidToEdit = keyBidToEdit
                vc.keyJobToEdit = keyJob
                vc.keyProperty = keyProperty
            }
        }
    }
    
    // MARK: Private Methods

    private
    
    func updateBidWith(propertyId: String, jobId: String, bidId: String, parameters: Parameters, dirtyUpdate: Bool, alertTitle: String, alertMessage: String?) {
        
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

            AF.request(updateBidURLString(propertyId: propertyId, jobId: jobId, bidId: bidId), method: .put, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
                
                DispatchQueue.main.async {
                    debugPrint(response)
                    
                    if let statusCode = response.response?.statusCode, statusCode >= 200 && statusCode < 300 {
                        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
                        let okayAction = UIAlertAction(title: "OK", style: .default) { action in
                            if dirtyUpdate {
                                self?.keyBidToUpdate = nil
                                self?.saveButton.isEnabled = false
                                self?.removeCancelButton()
                            }
                        }
                        alertController.addAction(okayAction)
                        self?.present(alertController, animated: true, completion: nil)
                    } else {
                       let errorMessage = firebaseAPIErrorMessages(data: response.data, error: response.error, statusCode: response.response?.statusCode)
                       let alertController = UIAlertController(title: "Error Updating Bid", message: errorMessage, preferredStyle: .alert)
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
        if keyBidToCreate != nil && keyBidToEdit == nil {
            stateView.backgroundColor = .white
            stateLabel.textColor = .black
            stateLabel.text = ""
            return
        }
        
        guard let bid = keyBidToEdit?.bid else {
            return
        }
        
        switch bid.state {
        case BidState.open.rawValue:
            stateView.backgroundColor = GlobalColors.sectionHeaderPurple
            stateLabel.textColor = .white
            stateLabel.text = "OPEN"
        case BidState.approved.rawValue:
            stateView.backgroundColor = GlobalColors.sectionHeaderBlue
            stateLabel.textColor = .white
            stateLabel.text = "APPROVED"
        case BidState.rejected.rawValue:
            stateView.backgroundColor = GlobalColors.sectionHeaderRed
            stateLabel.textColor = .white
            stateLabel.text = "REJECTED"
        case BidState.incomplete.rawValue:
            stateView.backgroundColor = GlobalColors.sectionHeaderOrange
            stateLabel.textColor = .white
            stateLabel.text = "INCOMPLETE"
        case BidState.complete.rawValue:
            stateView.backgroundColor = GlobalColors.veryLightBlue
            stateLabel.textColor = .white
            stateLabel.text = "COMPLETED"

        default:
            stateView.backgroundColor = .red
            stateLabel.textColor = .white
            stateLabel.text = "UNKNOWN STATE"
        }
        
    }
    
    func jobHasApprovedBid() -> Bool {
        let filteredKeyBids = keyBids.filter( { $0.bid.state ?? "" == BidState.approved.rawValue  } )
        return (filteredKeyBids.count > 0)
    }
    func jobHasCompletedBid() -> Bool {
        let filteredKeyBids = keyBids.filter( { $0.bid.state ?? "" == BidState.complete.rawValue  } )
        return (filteredKeyBids.count > 0)
    }
    func jobIsAuthorized() -> Bool {
        guard let job = keyJob?.job else {
            return false
        }
        guard let value = job.state, let state = JobState(rawValue: value) else {
            return false
        }
        
        switch state {
        case .open, .approved:
            return false
        case .authorized, .complete:
            return true
        }
        
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
        
        if let bidId = keyBidToEdit?.key, let jobId = keyJob?.key {
            bidListener = dbDocumentBidWith(documentId: bidId).addSnapshotListener({ [weak self] (documentSnapshot, error) in
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        return
                    }
                    
                    if let document = documentSnapshot, document.exists {
                        print("Bid Updated")
                        let updatedBid: KeyBid = (document.documentID, Mapper<Bid>().map(JSONObject: document.data())!)
                        weakSelf.keyBidToEdit = updatedBid
                        weakSelf.tableView.reloadData()
                        weakSelf.updateStateViews()
                    } else {
                        print("ERROR: Bid Not Found")
                    }
                }
            })
            
            bidsListener = dbQueryBidsWith(jobId: jobId).addSnapshotListener { [weak self] (querySnapshot, error) in
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
    
    func getBidId() -> String? {
        var bidId: String?
        if let keyBidToEdit = keyBidToEdit {
            bidId = keyBidToEdit.key
        } else if let keyBidToCreate = keyBidToCreate {
            bidId = keyBidToCreate.key
        }
        
        return bidId
    }
    
}


extension JobBidEditVC: TextFieldEditTVCellDelegate {
    
    func textFieldUpdated(text: String) {
        updateSaveCancelButtons()
        
        guard let bidId = getBidId() else {
            return
        }
        
        if keyBidToUpdate == nil {
            let newBidToUpdateJSON: [String: Any] = [
                "vendor" : text
            ]
            guard let newBidToUpdate = Mapper<Bid>().map(JSON: newBidToUpdateJSON) else {
                print("newBidToUpdate model failed to map")
                return
            }
            keyBidToUpdate = (key: bidId, bid: newBidToUpdate)
        } else {
            keyBidToUpdate!.bid.vendor = text
        }
    }
}

extension JobBidEditVC: TextViewEditTVCellDelegate {
    
    func textViewUpdated(text: String) {
        updateSaveCancelButtons()
        
        guard let bidId = getBidId() else {
            return
        }
        
        if keyBidToUpdate == nil {
            let newBidToUpdateJSON: [String: Any] = [
                "vendorDetails" : text
            ]
            guard let newBidToUpdate = Mapper<Bid>().map(JSON: newBidToUpdateJSON) else {
                print("newBidToUpdate model failed to map")
                return
            }
            keyBidToUpdate = (key: bidId, bid: newBidToUpdate)
        } else {
            keyBidToUpdate!.bid.vendorDetails = text
        }
    }
}

extension JobBidEditVC: BidScopeEditTVCellDelegate {
    
    func scopeUpdated(scope: BidScope) {
        updateSaveCancelButtons()
        
        guard let bidId = getBidId() else {
            return
        }
        
        if keyBidToUpdate == nil {
            let newBidToUpdateJSON: [String: Any] = [
                "scope" : scope.rawValue
            ]
            guard let newBidToUpdate = Mapper<Bid>().map(JSON: newBidToUpdateJSON) else {
                print("newBidToUpdate model failed to map")
                return
            }
            keyBidToUpdate = (key: bidId, bid: newBidToUpdate)
        } else {
            keyBidToUpdate!.bid.scope = scope.rawValue
        }
    }
}

extension JobBidEditVC: BidCostEditTVCellDelegate {
    
    func resetCost() {
        guard let bidId = getBidId() else {
            return
        }
        
        updateSaveCancelButtons()
        
        if keyBidToUpdate == nil {
            let newBidToUpdateJSON: [String: Any] = [
                "costMin" : NSNumber(value: 0),
                "costMax" : NSNumber(value: 0)
            ]
            guard let newBidToUpdate = Mapper<Bid>().map(JSON: newBidToUpdateJSON) else {
                print("newBidToUpdate model failed to map")
                return
            }
            keyBidToUpdate = (key: bidId, bid: newBidToUpdate)
        } else {
            keyBidToUpdate!.bid.costMin = NSNumber(value: 0)
            keyBidToUpdate!.bid.costMax = NSNumber(value: 0)
        }
    }
    
    func fixedCostUpdated(cost: NSNumber?) {
        guard let bidId = getBidId() else {
            return
        }
        
        updateSaveCancelButtons()
        
        if keyBidToUpdate == nil {
            if let cost = cost {
                let newBidToUpdateJSON: [String: Any] = [
                    "costMin" : cost,
                    "costMax" : cost
                ]
                guard let newBidToUpdate = Mapper<Bid>().map(JSON: newBidToUpdateJSON) else {
                    print("newBidToUpdate model failed to map")
                    return
                }
                keyBidToUpdate = (key: bidId, bid: newBidToUpdate)
            } else {
                let newBidToUpdateJSON: [String: Any] = [
                    "costMin" : NSNumber(value: 0),
                    "costMax" : NSNumber(value: 0)
                ]
                guard let newBidToUpdate = Mapper<Bid>().map(JSON: newBidToUpdateJSON) else {
                    print("newBidToUpdate model failed to map")
                    return
                }
                keyBidToUpdate = (key: bidId, bid: newBidToUpdate)
            }
        } else if let cost = cost {
            keyBidToUpdate!.bid.costMin = cost
            keyBidToUpdate!.bid.costMax = cost
        } else {
            keyBidToUpdate!.bid.costMin = NSNumber(value: 0)
            keyBidToUpdate!.bid.costMax = NSNumber(value: 0)
        }
    }
    
    func rangeCostMinUpdated(costMin: NSNumber?) {
        guard let bidId = getBidId() else {
            return
        }
        
        updateSaveCancelButtons()
        
        if keyBidToUpdate == nil {
            if let costMin = costMin {
                let newBidToUpdateJSON: [String: Any] = [
                    "costMin" : costMin
                ]
                guard let newBidToUpdate = Mapper<Bid>().map(JSON: newBidToUpdateJSON) else {
                    print("newBidToUpdate model failed to map")
                    return
                }
                keyBidToUpdate = (key: bidId, bid: newBidToUpdate)
            } else {
                let newBidToUpdateJSON: [String: Any] = [
                    "costMin" : NSNumber(value: 0)
                ]
                guard let newBidToUpdate = Mapper<Bid>().map(JSON: newBidToUpdateJSON) else {
                    print("newBidToUpdate model failed to map")
                    return
                }
                keyBidToUpdate = (key: bidId, bid: newBidToUpdate)
            }
        } else if let costMin = costMin {
            keyBidToUpdate!.bid.costMin = costMin
        } else {
            keyBidToUpdate!.bid.costMin = NSNumber(value: 0)
        }
    }
    
    func rangeCostMaxUpdated(costMax: NSNumber?) {
        guard let bidId = getBidId() else {
            return
        }
        
        updateSaveCancelButtons()
        
        if keyBidToUpdate == nil {
            if let costMax = costMax {
                let newBidToUpdateJSON: [String: Any] = [
                    "costMax" : costMax
                ]
                guard let newBidToUpdate = Mapper<Bid>().map(JSON: newBidToUpdateJSON) else {
                    print("newBidToUpdate model failed to map")
                    return
                }
                keyBidToUpdate = (key: bidId, bid: newBidToUpdate)
            } else {
                let newBidToUpdateJSON: [String: Any] = [
                    "costMax" : NSNumber(value: 0)
                ]
                guard let newBidToUpdate = Mapper<Bid>().map(JSON: newBidToUpdateJSON) else {
                    print("newBidToUpdate model failed to map")
                    return
                }
                keyBidToUpdate = (key: bidId, bid: newBidToUpdate)
            }
        } else if let costMax = costMax {
            keyBidToUpdate!.bid.costMax = costMax
        } else {
            keyBidToUpdate!.bid.costMax = NSNumber(value: 0)
        }
    }
}

extension JobBidEditVC: BidTimelineEditTVCellDelegate {
    
    func startAtUpdated(date: Date) {
        guard let bidId = getBidId() else {
            return
        }
        
        updateSaveCancelButtons()
        
        if keyBidToUpdate == nil {
            let newBidToUpdateJSON: [String: Any] = [
                "startAt" : NSNumber(value: date.timeIntervalSince1970)
            ]
            guard let newBidToUpdate = Mapper<Bid>().map(JSON: newBidToUpdateJSON) else {
                print("newBidToUpdate model failed to map")
                return
            }
            keyBidToUpdate = (key: bidId, bid: newBidToUpdate)
        } else {
            keyBidToUpdate!.bid.startAt = NSNumber(value: date.timeIntervalSince1970)
        }
    }
    
    func completeAtUpdated(date: Date) {
        guard let bidId = getBidId() else {
            return
        }
        
        updateSaveCancelButtons()
        
        if keyBidToUpdate == nil {
            let newBidToUpdateJSON: [String: Any] = [
                "completeAt" : NSNumber(value: date.timeIntervalSince1970)
            ]
            guard let newBidToUpdate = Mapper<Bid>().map(JSON: newBidToUpdateJSON) else {
                print("newBidToUpdate model failed to map")
                return
            }
            keyBidToUpdate = (key: bidId, bid: newBidToUpdate)
        } else {
            keyBidToUpdate!.bid.completeAt = NSNumber(value: date.timeIntervalSince1970)
        }
    }
}

extension JobBidEditVC: BidVendorSwitchesEditTVCellDelegate {
    
    func hasW9Updated(value: Bool) {
        guard let bidId = getBidId() else {
            return
        }
        
        updateSaveCancelButtons()
        
        if keyBidToUpdate == nil {
            let newBidToUpdateJSON: [String: Any] = [
                "vendorW9" : value
            ]
            guard let newBidToUpdate = Mapper<Bid>().map(JSON: newBidToUpdateJSON) else {
                print("newBidToUpdate model failed to map")
                return
            }
            keyBidToUpdate = (key: bidId, bid: newBidToUpdate)
        } else {
            keyBidToUpdate!.bid.vendorW9 = value
        }
    }
    
    func hasInsuranceUpdated(value: Bool) {
        guard let bidId = getBidId() else {
            return
        }
        
        updateSaveCancelButtons()
        
        if keyBidToUpdate == nil {
            let newBidToUpdateJSON: [String: Any] = [
                "vendorInsurance" : value
            ]
            guard let newBidToUpdate = Mapper<Bid>().map(JSON: newBidToUpdateJSON) else {
                print("newBidToUpdate model failed to map")
                return
            }
            keyBidToUpdate = (key: bidId, bid: newBidToUpdate)
        } else {
            keyBidToUpdate!.bid.vendorInsurance = value
        }
    }
    
    func hasLicenseUpdated(value: Bool) {
        guard let bidId = getBidId() else {
            return
        }
        
        updateSaveCancelButtons()
        
        if keyBidToUpdate == nil {
            let newBidToUpdateJSON: [String: Any] = [
                "vendorLicense" : value
            ]
            guard let newBidToUpdate = Mapper<Bid>().map(JSON: newBidToUpdateJSON) else {
                print("newBidToUpdate model failed to map")
                return
            }
            keyBidToUpdate = (key: bidId, bid: newBidToUpdate)
        } else {
            keyBidToUpdate!.bid.vendorLicense = value
        }
    }
}
