//
//  BidsListVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 3/14/22.
//  Copyright © 2022 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import FirebaseFirestore

typealias BidsByState = (state: BidState, keyBids: [KeyBid])

class BidsListVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var navBar: UINavigationItem!

    // Inputs
    var keyProperty: KeyProperty?
    var keyJob: KeyJob?

    var keyBids: [KeyBid] = []
    var bidsByState: [BidsByState] = []
    var keyBidToEdit: (key: String, bid: Bid)?
    var userListener: ListenerRegistration?
    var bidsListener: ListenerRegistration?
        
    let currentBidsSort: BidsSort = .updatedAt // Default

    var dismissHUD = false

    deinit {
        if let listener = userListener {
            listener.remove()
        }
        if let listener = bidsListener {
            listener.remove()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Defaults
        addButton.isEnabled = false
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.estimatedRowHeight = 21.0;
        tableView.keyboardDismissMode = UIScrollView.KeyboardDismissMode.onDrag
        
        // Setup
        let nib = UINib(nibName: "BidSectionHeader", bundle: nil)
        tableView.register(nib, forHeaderFooterViewReuseIdentifier: "BidSectionHeader")
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0.0
        } else {
            // Fallback on earlier versions
        }
        tableView.sectionHeaderHeight = 30.0
        tableView.sectionFooterHeight = 0.0

        
        setObservers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func addButtonTapped(_ sender: Any) {
        keyBidToEdit = nil
        performSegue(withIdentifier: "showBidEdit", sender: self)
    }
    
    // MARK: UITableView DataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return bidsByState.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bidsByState[section].keyBids.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "bidCell") as? BidTVCell ?? BidTVCell()
        let bid = bidsByState[indexPath.section].keyBids[indexPath.row].bid
        
        cell.vendorLabel?.text = bid.vendor ?? "No Name"
        if let scope = bid.scope {
            switch scope {
            case BidScope.local.rawValue:
                cell.scopeLabel.attributedText = formatScopeLabel(scope: "Local")
            case BidScope.national.rawValue:
                cell.scopeLabel.attributedText = formatScopeLabel(scope: "Local")
            default:
                cell.scopeLabel.attributedText = formatScopeLabel(scope: "Unknown")
            }
        } else {
            cell.scopeLabel.attributedText = formatScopeLabel(scope: "?")
        }
        
        cell.additionalDataLabel.attributedText = formatAdditionalData(bid: bid)
        
        cell.costView.isHidden = false // default
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.maximumFractionDigits = 0
        if let costMin = bid.costMin, let costMax = bid.costMax, costMin.doubleValue != costMax.doubleValue {
            if costMin.isFraction || costMax.isFraction {
                currencyFormatter.maximumFractionDigits = 2
            }
            cell.costLabel?.text = "\(currencyFormatter.string(from: costMin) ?? "$?") - \(currencyFormatter.string(from: costMax) ?? "$?")"
        } else if let costMax = bid.costMax, costMax.doubleValue > 0 {
            if costMax.isFraction {
                currencyFormatter.maximumFractionDigits = 2
            }
            cell.costLabel?.text = "\(currencyFormatter.string(from: costMax) ?? "$?")"
        } else {
            cell.costView.isHidden = true
        }

        return cell
    }
    
//    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
//        switch jobsByStateAfterFilter()[section].state {
//        case .complete:
//            return "COMPLETED"
//        default:
//            return jobsByStateAfterFilter()[section].state.rawValue.uppercased()
//        }
//    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Dequeue with the reuse identifier
        let cell = self.tableView.dequeueReusableHeaderFooterView(withIdentifier: "BidSectionHeader")
        let header = cell as! BidSectionHeader
        
        switch bidsByState[section].state {
        case .complete:
            header.titleLabel.text = "COMPLETED"
            header.background.backgroundColor = GlobalColors.veryLightBlue
        case .approved:
            header.titleLabel.text = bidsByState[section].state.rawValue.uppercased()
            header.background.backgroundColor = GlobalColors.veryLightBlue
        case .open:
            header.titleLabel.text = bidsByState[section].state.rawValue.uppercased()
            header.background.backgroundColor = GlobalColors.sectionHeaderPurple
        case .rejected:
            header.titleLabel.text = bidsByState[section].state.rawValue.uppercased()
            header.background.backgroundColor = GlobalColors.sectionHeaderBrightRed
        case .incomplete:
            header.titleLabel.text = bidsByState[section].state.rawValue.uppercased()
            header.background.backgroundColor = GlobalColors.sectionHeaderOrange
        }
        
        header.titleLabel.textColor = UIColor.white

        return cell
    }
    
//    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
//        let delete = UITableViewRowAction(style: .normal, title: "Delete") { [unowned self] action, index in
//            if indexPath.row < self.bidsByState[indexPath.section].keyBids.count {
//                let keyBid = self.bidsByState[indexPath.section].keyBids[indexPath.row]
//                self.alertForDeleting(keyBid)
//            }
//
//        }
//        delete.backgroundColor = UIColor.red
//
//        return [delete]
//    }
//
//    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
//        if let profile = currentUserProfile, !profile.isDisabled {
//            return profile.admin || profile.corporate
//        }
//
//        return false
//    }
    
//    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
//        // This method is for showing slide-to-actions
//    }
    
//    func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
//        return 61.0
//    }
//
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    // MARK: UITableView Delegates
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if let profile = currentUserProfile, !profile.isDisabled {
            let keyBid = bidsByState[indexPath.section].keyBids[indexPath.row]
            keyBidToEdit = keyBid
            performSegue(withIdentifier: "showBidEdit", sender: self)
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showBidEdit" {
            if let vc = segue.destination as? JobBidEditVC {
                vc.keyJob = keyJob
                vc.keyProperty = keyProperty
                if let keyBidToEdit = keyBidToEdit {
                    vc.keyBidToEdit = keyBidToEdit
                } else {
                    let newKey = dbCollectionJobs().document().documentID
                    vc.keyBidToCreate = (key: newKey, bid: Bid(JSONString: "{}")!)
                }

                keyBidToEdit = nil  // Reset
            }
        }
    }
    
    // MARK: Private Methods
    
    private
    
    func sortBids() {
        keyBids = sortKeyBids(keyBids, bidsSort: currentBidsSort)

        var newBidsByState: [BidsByState] = []
        var state = BidState.complete
        var keyBidsForState: [KeyBid] = keyBids.filter({ $0.bid.state == state.rawValue })
        var newKeyBidsForState = BidsByState(state: state, keyBids: keyBidsForState)
        if keyBidsForState.count > 0 {
            newBidsByState.append(newKeyBidsForState)
        }

        state = BidState.approved
        keyBidsForState = keyBids.filter({ $0.bid.state == state.rawValue })
        newKeyBidsForState = BidsByState(state: state, keyBids: keyBidsForState)
        if newBidsByState.count == 0 {  // If none completed, show approved (always)
            newBidsByState.append(newKeyBidsForState)
        }

        state = BidState.open
        keyBidsForState = keyBids.filter({ $0.bid.state == state.rawValue })
        newKeyBidsForState = BidsByState(state: state, keyBids: keyBidsForState)
        newBidsByState.append(newKeyBidsForState)

        state = BidState.rejected
        keyBidsForState = keyBids.filter({ $0.bid.state == state.rawValue })
        newKeyBidsForState = BidsByState(state: state, keyBids: keyBidsForState)
        newBidsByState.append(newKeyBidsForState)

        state = BidState.incomplete
        keyBidsForState = keyBids.filter({ $0.bid.state == state.rawValue })
        newKeyBidsForState = BidsByState(state: state, keyBids: keyBidsForState)
        newBidsByState.append(newKeyBidsForState)

        bidsByState = newBidsByState
    }
    
    func jobHasCompletedBid() -> Bool {
        let filteredKeyBids = keyBids.filter( { $0.bid.state ?? "" == BidState.complete.rawValue  } )
        return (filteredKeyBids.count > 0)
    }
    
    func updateUI() {
        if jobHasCompletedBid() {
            addButton.isEnabled = false
        } else {
            addButton.isEnabled = true
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
                        
                            weakSelf.addButton.isEnabled = profile.admin || profile.corporate || property || team
                        } else {
                            weakSelf.addButton.isEnabled = false
                        }
                    }
                }
            })
        }
        
        presentHUDForConnection()
        
        guard let keyJob = keyJob else {
            return
        }

                
        dbQueryBidsWith(jobId: keyJob.key).getDocuments { [weak self] (querySnapshot, error) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                // Only ran once (setup)
                if let error = error {
                    dismissHUDForConnection()
                    print("Error getting Bids: \(error)")
                    return
                } else if querySnapshot!.documents.count == 0 {
                    print("Bids count: 0")
                    dismissHUDForConnection()
                } else {
                    print("Bids count: \(querySnapshot!.documents.count)")
                    weakSelf.dismissHUD = true
                }
        
                weakSelf.bidsListener = dbQueryBidsWith(jobId: keyJob.key).addSnapshotListener { (querySnapshot, error) in
                    DispatchQueue.main.async {
                        guard let weakSelf = self else {
                            return
                        }
                        
                        if weakSelf.dismissHUD {
                            dismissHUDForConnection()
                            weakSelf.dismissHUD = false
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
                            weakSelf.updateUI()
                            weakSelf.tableView.reloadData()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: Alerts
    
    func alertForDeleting(_ keyBid: KeyBid) {
        let alertController = UIAlertController(title: "Are you sure you want to delete this bid?", message: nil, preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel action"), style: .cancel, handler: { (action) in
            print("Cancel Action")
        })
        let deleteAction = UIAlertAction(title: NSLocalizedString("DELETE", comment: "Delete Action"), style: .destructive, handler: { [weak self] (action) in
            SVProgressHUD.show()
            dbDocumentBidWith(documentId: keyBid.key).delete { (error) in
                DispatchQueue.main.async {
                    if error != nil {
                        self?.showMessagePrompt(error!.localizedDescription)
                    } else {
                        Notifications.sendBidDeletion(bid: keyBid.bid)
                    }
                    
                    SVProgressHUD.dismiss()
                }
            }
        })
        alertController.addAction(cancelAction)
        alertController.addAction(deleteAction)
        
        present(alertController, animated: true, completion: {})
    }
    
    func formatScopeLabel(scope: String) -> NSAttributedString {

        let bold: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 13), NSAttributedString.Key.foregroundColor: UIColor.darkGray]
        let regular: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13), NSAttributedString.Key.foregroundColor: UIColor.darkGray]

        let string = NSMutableAttributedString(string: "", attributes: regular)

        string.append(NSAttributedString(string: "Scope:", attributes: bold))
        string.append(NSAttributedString(string: " \(scope)", attributes: regular))
        
        return string
    }
    
    func formatAdditionalData(bid: Bid) -> NSAttributedString {
        let bold: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 13), NSAttributedString.Key.foregroundColor: UIColor.darkGray]
        let boldGreen: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 13), NSAttributedString.Key.foregroundColor: GlobalColors.itemCompletedGreen]
        let regular: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13), NSAttributedString.Key.foregroundColor: UIColor.darkGray]
        let regularSmall: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 11), NSAttributedString.Key.foregroundColor: UIColor.darkGray]

        let string = NSMutableAttributedString(string: "", attributes: regular)

        let formatter = DateFormatter()
        formatter.dateStyle = DateFormatter.Style.short
        formatter.timeStyle = .none
        
        if let startAt = bid.startAt, let completeAt = bid.completeAt {
            let startAtDate = Date(timeIntervalSince1970: startAt.doubleValue)
            let completeAtDate = Date(timeIntervalSince1970: completeAt.doubleValue)
            string.append(NSAttributedString(string: "Timeline: ", attributes: bold))
            string.append(NSAttributedString(string: "\(formatter.string(from: startAtDate)) - \(formatter.string(from: completeAtDate))", attributes: regular))
        } else if let startAt = bid.startAt {
            let startAtDate = Date(timeIntervalSince1970: startAt.doubleValue)
            string.append(NSAttributedString(string: "Timeline: ", attributes: bold))
            string.append(NSAttributedString(string: "\(formatter.string(from: startAtDate)) - ?", attributes: regular))
        } else if let completeAt = bid.completeAt {
            let completeAtDate = Date(timeIntervalSince1970: completeAt.doubleValue)
            string.append(NSAttributedString(string: "Timeline: ", attributes: bold))
            string.append(NSAttributedString(string: "? - \(formatter.string(from: completeAtDate))", attributes: regular))
        }
        
        let vendorW9 = bid.vendorW9 ?? false
        let vendorInsurance = bid.vendorInsurance ?? false
        let vendorLicense = bid.vendorLicense ?? false

        if vendorW9 || vendorInsurance || vendorLicense {
            let newString = NSMutableAttributedString(string: "\n\n", attributes: regularSmall)
            if vendorW9 {
                newString.append(NSAttributedString(string: "✓ ", attributes: boldGreen))
                newString.append(NSAttributedString(string: "W9 Approved", attributes: regularSmall))
            }
            if vendorInsurance {
                if vendorW9 {
                    newString.append(NSAttributedString(string: "   ", attributes: regularSmall))
                }
                newString.append(NSAttributedString(string: "✓ ", attributes: boldGreen))
                newString.append(NSAttributedString(string: "Insurance Approved", attributes: regularSmall))
            }
            if vendorLicense {
                if vendorW9 || vendorInsurance {
                    newString.append(NSAttributedString(string: "   ", attributes: regularSmall))
                }
                newString.append(NSAttributedString(string: "✓ ", attributes: boldGreen))
                newString.append(NSAttributedString(string: "License Approved", attributes: regularSmall))
            }
            string.append(newString)
        }

        return string
    }
    
}
