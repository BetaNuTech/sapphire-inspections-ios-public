//
//  DeficientItemsVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 4/1/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import FirebaseFirestore

typealias keyInspectionDeficientItem = (key: String, item: InspectionDeficientItem)

enum DeficientItemsSort: String {
    case lastUpdated = "lastUpdated"
    case currentDueOrDeferredDate = "currentDueOrDeferredDate"
    case grade = "grade"
    case createdAt = "createdAt"
    case responsibilityGroup = "responsibilityGroup"
}

class DeficientItemsVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    enum DeficientItemsSectionName: String {
        case complete = "Completed - Follow Up Required"
        case incomplete = "Incomplete - Follow Up Required"
        case overdue = "Past Due Date - Action(s) Required"
        case new = "NEW - Action(s) Required"
        case goBack = "Go Back - Action(s) Required"
        case pendingWithActions = "Pending - Action(s) Required"
        case deferred = "Deferred"
        case pending = "Pending"
        case closed = "Closed"
    }

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var sortLabel: UILabel!
    
    var adminCorporateUser = false
    
    // Open from URIs only
    var propertyKey: String?
    
    var keyProperty: (key: String, property: Property)?
    
    var deficientItems: [keyInspectionDeficientItem] = []
    var sectionsWithDeficientItems: [(section: DeficientItemsSectionName, deficientItems: [keyInspectionDeficientItem])] = []
    var userListener: ListenerRegistration?

    var deficientItemsForPropertyListener: ListenerRegistration?

    var filteredDeficientItems: [keyInspectionDeficientItem] = []
    var filterString = ""
    
    var dismissHUD = false
    
    var selectedKeyDeficientItem: keyInspectionDeficientItem?
    
    var currentSort = DeficientItemsSort.lastUpdated

    deinit {
        if let listener = userListener {
            listener.remove()
        }
        
        if let listener = deficientItemsForPropertyListener {
            listener.remove()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Defaults
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.estimatedRowHeight = 100.0;
        
        // UITable Setup
        let nib = UINib(nibName: "CategorySectionHeader", bundle: nil)
        tableView.register(nib, forHeaderFooterViewReuseIdentifier: "CategorySectionHeader")
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0.0
        } else {
            // Fallback on earlier versions
        }
        tableView.sectionHeaderHeight = 30.0
        
        setObservers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateDeficientSectionsWithItems()
        updateSortLabel()
    }
    
    // MARK: Actions

    @IBAction func sortButtonTapped(_ sender: UIBarButtonItem) {
        // Change sorting
        switch currentSort {
        case .responsibilityGroup:
            currentSort = .currentDueOrDeferredDate
        case .currentDueOrDeferredDate:
            currentSort = .grade
        case .grade:
            currentSort = .createdAt
        case .createdAt:
            currentSort = .lastUpdated
        case .lastUpdated:
            currentSort = .responsibilityGroup
        }
        
        // Update sort label
        updateSortLabel()

        // Reload Data
        updateDeficientSectionsWithItems()
    }
    
    func updateSortLabel() {
        switch currentSort {
        case .lastUpdated:
            sortLabel.text = "Sorted by Last Update"
        case .currentDueOrDeferredDate:
            sortLabel.text = "Sorted by Due/Deferred Date"
        case .grade:
            sortLabel.text = "Sorted by Grade"
        case .createdAt:
            sortLabel.text = "Sorted by Deficient Date"
        case .responsibilityGroup:
            sortLabel.text = "Sorted by Responsibility Group"
        }
    }
    
    // MARK: UISearchBarDelegate
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        filterString = searchText
        updateDeficientSectionsWithItems()
    }
    
    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        return true
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func filterDeficientItems() {
        if filterString != "" {
            filteredDeficientItems = deficientItems.filter({  $0.item.itemTitle.lowercased().contains(filterString.lowercased()) ||
                $0.item.sectionTitle.lowercased().contains(filterString.lowercased()) ||
                ($0.item.sectionSubtitle ?? "").lowercased().contains(filterString.lowercased())
            })
        } else {
            filteredDeficientItems = deficientItems
        }
    }
    
    func deficientItemsAfterFilter() -> [keyInspectionDeficientItem] {
        
        var deficientItemsAfterFilter = deficientItems
        
        if filterString != "" {
            filterDeficientItems()
            deficientItemsAfterFilter = filteredDeficientItems
        }
        
        let highDate = Date(timeIntervalSinceNow: 60*60*24*365)  // 1 year out from current date.
        let lowDate = Date(timeIntervalSince1970: 0)  // 0 in Unixtime

        // Apply sorting
        switch currentSort {
        case .lastUpdated:
            print("sorted by lastUpdated")
            deficientItemsAfterFilter.sort(by: { $0.item.updatedAt ?? lowDate > $1.item.updatedAt ?? lowDate })
        case .currentDueOrDeferredDate:
            print("sorted by currentDueDate OR currentDeferredDate")
            deficientItemsAfterFilter.sort { (keyInspectionDeficientItemA, keyInspectionDeficientItemB) -> Bool in
                
                var dateA = keyInspectionDeficientItemA.item.currentDueDate ?? highDate
                if let state = keyInspectionDeficientItemA.item.state, state == InspectionDeficientItemState.deferred.rawValue {
                    dateA = keyInspectionDeficientItemA.item.currentDeferredDate ?? highDate
                }
                var dateB = keyInspectionDeficientItemB.item.currentDueDate ?? highDate
                if let state = keyInspectionDeficientItemB.item.state, state == InspectionDeficientItemState.deferred.rawValue {
                    dateB = keyInspectionDeficientItemB.item.currentDeferredDate ?? highDate
                }
                
                return dateA <= dateB
            }
        case .grade:
            print("sorted by grade")
            deficientItemsAfterFilter.sort(by: { $0.item.itemScore <= $1.item.itemScore })
        case .createdAt:
            print("sorted by createdAt")
            deficientItemsAfterFilter.sort(by: { $0.item.createdAt ?? highDate <= $1.item.createdAt ?? highDate })
        case .responsibilityGroup:
            print("sorted by responsibilityGroup")
            deficientItemsAfterFilter.sort(by: { $0.item.currentResponsibilityGroup ?? "" <= $1.item.currentResponsibilityGroup ?? "" })
        }
        
        return deficientItemsAfterFilter
    }
    
    func updateDeficientSectionsWithItems() {
        let deficientItems = deficientItemsAfterFilter()
        
        // Collate into sections
        var newSections: [(section: DeficientItemsSectionName, deficientItems: [keyInspectionDeficientItem])] = []
        
//        if adminCorporateUser {
            // STATE: complete
            var filteredDeficientItems = deficientItems.filter { $0.item.state == InspectionDeficientItemState.completed.rawValue }
            if filteredDeficientItems.count > 0 {
//                filteredDeficientItems.sort { (first, second) -> Bool in
//                    let firstCreatedAt = first.item.createdAt ?? Date(timeIntervalSince1970: 0)
//                    let secondCreatedAt = second.item.createdAt ?? Date(timeIntervalSince1970: 0)
//
//                    return firstCreatedAt.timeIntervalSince1970 < secondCreatedAt.timeIntervalSince1970
//                }
                
                newSections.append( (section: .complete, deficientItems: filteredDeficientItems) )
            }
            
            // STATE: incomplete
            filteredDeficientItems = deficientItems.filter { $0.item.state == InspectionDeficientItemState.incomplete.rawValue }
            if filteredDeficientItems.count > 0 {
//                filteredDeficientItems.sort { (first, second) -> Bool in
//                    let firstCreatedAt = first.item.createdAt ?? Date(timeIntervalSince1970: 0)
//                    let secondCreatedAt = second.item.createdAt ?? Date(timeIntervalSince1970: 0)
//
//                    return firstCreatedAt.timeIntervalSince1970 < secondCreatedAt.timeIntervalSince1970
//                }
                
                newSections.append( (section: .incomplete, deficientItems: filteredDeficientItems) )
            }
//        }
        
        // STATE: overdue
        filteredDeficientItems = deficientItems.filter { $0.item.state == InspectionDeficientItemState.overdue.rawValue }
        if filteredDeficientItems.count > 0 {
//            filteredDeficientItems.sort { (first, second) -> Bool in
//                let firstCreatedAt = first.item.createdAt ?? Date(timeIntervalSince1970: 0)
//                let secondCreatedAt = second.item.createdAt ?? Date(timeIntervalSince1970: 0)
//
//                return firstCreatedAt.timeIntervalSince1970 < secondCreatedAt.timeIntervalSince1970
//            }
            
            newSections.append( (section: .overdue, deficientItems: filteredDeficientItems) )
        }
        
        // STATE: requires-action
        filteredDeficientItems = deficientItems.filter { $0.item.state == InspectionDeficientItemState.requiresAction.rawValue }
        if filteredDeficientItems.count > 0 {
//            filteredDeficientItems.sort { (first, second) -> Bool in
//                let firstCreatedAt = first.item.createdAt ?? Date(timeIntervalSince1970: 0)
//                let secondCreatedAt = second.item.createdAt ?? Date(timeIntervalSince1970: 0)
//
//                return firstCreatedAt.timeIntervalSince1970 < secondCreatedAt.timeIntervalSince1970
//            }
            
            newSections.append( (section: .new, deficientItems: filteredDeficientItems) )
        }
        
        // STATE: go-back
        filteredDeficientItems = deficientItems.filter { $0.item.state == InspectionDeficientItemState.goBack.rawValue }
        if filteredDeficientItems.count > 0 {
//            filteredDeficientItems.sort { (first, second) -> Bool in
//                let firstCreatedAt = first.item.createdAt ?? Date(timeIntervalSince1970: 0)
//                let secondCreatedAt = second.item.createdAt ?? Date(timeIntervalSince1970: 0)
//
//                return firstCreatedAt.timeIntervalSince1970 < secondCreatedAt.timeIntervalSince1970
//            }
            
            newSections.append( (section: .goBack, deficientItems: filteredDeficientItems) )
        }
        
        // STATE: requires-progress-update
        filteredDeficientItems = deficientItems.filter { $0.item.state == InspectionDeficientItemState.requiresProgressUpdate.rawValue }
        if filteredDeficientItems.count > 0 {
//            filteredDeficientItems.sort { (first, second) -> Bool in
//                let firstDueDate = first.item.currentDueDate ?? Date(timeIntervalSince1970: 0)
//                let secondDueDate = second.item.currentDueDate ?? Date(timeIntervalSince1970: 0)
//
//                return firstDueDate.timeIntervalSince1970 < secondDueDate.timeIntervalSince1970
//            }
            
            newSections.append( (section: .pendingWithActions, deficientItems: filteredDeficientItems) )
        }
        
        // STATE: deferred
        filteredDeficientItems = deficientItems.filter { $0.item.state == InspectionDeficientItemState.deferred.rawValue }
        if filteredDeficientItems.count > 0 {
            //            filteredDeficientItems.sort { (first, second) -> Bool in
            //                let firstDueDate = first.item.currentDueDate ?? Date(timeIntervalSince1970: 0)
            //                let secondDueDate = second.item.currentDueDate ?? Date(timeIntervalSince1970: 0)
            //
            //                return firstDueDate.timeIntervalSince1970 < secondDueDate.timeIntervalSince1970
            //            }
            
            newSections.append( (section: .deferred, deficientItems: filteredDeficientItems) )
        }
        
        // STATE: pending
        filteredDeficientItems = deficientItems.filter { $0.item.state == InspectionDeficientItemState.pending.rawValue }
        if filteredDeficientItems.count > 0 {
//            filteredDeficientItems.sort { (first, second) -> Bool in
//                let firstDueDate = first.item.currentDueDate ?? Date(timeIntervalSince1970: 0)
//                let secondDueDate = second.item.currentDueDate ?? Date(timeIntervalSince1970: 0)
//
//                return firstDueDate.timeIntervalSince1970 < secondDueDate.timeIntervalSince1970
//            }
            
            newSections.append( (section: .pending, deficientItems: filteredDeficientItems) )
        }
        
        // STATE: closed
        filteredDeficientItems = deficientItems.filter { $0.item.state == InspectionDeficientItemState.closed.rawValue }
        if filteredDeficientItems.count > 0 {
//            filteredDeficientItems.sort { (first, second) -> Bool in
//                let firstDueDate = first.item.updatedAt ?? Date(timeIntervalSince1970: 0)
//                let secondDueDate = second.item.updatedAt ?? Date(timeIntervalSince1970: 0)
//
//                return firstDueDate.timeIntervalSince1970 > secondDueDate.timeIntervalSince1970
//            }
            
            newSections.append( (section: .closed, deficientItems: filteredDeficientItems) )
        }
        
        sectionsWithDeficientItems = newSections
        tableView.reloadData()
    }
    
    // MARK: - TableView
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionsWithDeficientItems.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionWithDeficientItems = sectionsWithDeficientItems[section]
        return sectionWithDeficientItems.deficientItems.count
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sectionWithDeficientItems = sectionsWithDeficientItems[section]

        // Dequeue with the reuse identifier
        let cell = self.tableView.dequeueReusableHeaderFooterView(withIdentifier: "CategorySectionHeader")
        let header = cell as! CategorySectionHeader
        header.titleLabel.textColor = UIColor.white
        
        header.titleLabel.text = sectionWithDeficientItems.section.rawValue
        
        switch sectionWithDeficientItems.section {
        case .complete, .incomplete:
            header.background.backgroundColor = GlobalColors.sectionHeaderPurple
        case .overdue, .new, .goBack, .pendingWithActions:
            header.background.backgroundColor = GlobalColors.sectionHeaderRed
        case .deferred:
            header.background.backgroundColor = UIColor.orange
        case .pending:
            header.background.backgroundColor = UIColor.darkGray
        case .closed:
            header.background.backgroundColor = UIColor.lightGray
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "deficientItemCell")! as! DeficientItemTVCell
        
        let sectionWithDeficientItems = sectionsWithDeficientItems[indexPath.section]
        let deficientItem = sectionWithDeficientItems.deficientItems[indexPath.row].item
        
        if sectionWithDeficientItems.section == .closed {
            cell.contentView.alpha = 0.5
        } else {
            cell.contentView.alpha = 1.0
        }
        
        cell.itemTItleLabel.text = deficientItem.itemTitle
        cell.responsibilityGroupLabel.text = " Not Set "
        cell.responsibilityGroupLabel.backgroundColor = UIColor.darkGray
        if let group = deficientItem.currentResponsibilityGroup {
            if let enumGroup = InspectionDeficientItemResponsibilityGroup(rawValue: group) {
                switch enumGroup {
                case .siteLevel_InHouse:
                    cell.responsibilityGroupLabel.text = " Site Level In-House "
                    cell.responsibilityGroupLabel.backgroundColor = .black
                case .siteLevelManagesVendor:
                    cell.responsibilityGroupLabel.text = " Site Level Manages Vendor "
                    cell.responsibilityGroupLabel.backgroundColor = .black
                case .corporate:
                    cell.responsibilityGroupLabel.text = " Corporate "
                    cell.responsibilityGroupLabel.backgroundColor = GlobalColors.itemDueDatePendingBlue
                case .corporateManagesVendor:
                    cell.responsibilityGroupLabel.text = " Corporate Manages Vendor "
                    cell.responsibilityGroupLabel.backgroundColor = GlobalColors.itemDueDatePendingBlue
                }
            }
        }
        cell.dueDateLabel.backgroundColor = GlobalColors.itemDueDateRed

        if deficientItem.state == InspectionDeficientItemState.deferred.rawValue {
            cell.dueDateLabel.text = " Not Set "
            if let currentDeferredDate = deficientItem.currentDeferredDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd/yyyy"
//                formatter.dateStyle = DateFormatter.Style.medium
//                formatter.timeStyle = .none
                cell.dueDateLabel.text = " \(formatter.string(from: currentDeferredDate)) "
                if currentDeferredDate.timeIntervalSince1970 > Date().timeIntervalSince1970 {
                    cell.dueDateLabel.backgroundColor = GlobalColors.itemDueDatePendingBlue
                } else {
                    cell.dueDateLabel.backgroundColor = GlobalColors.itemDueDateRed
                }
            }
            // Override with Day string
            if let currentDeferredDateDay = deficientItem.currentDeferredDateDay {
                cell.dueDateLabel.text = " \(currentDeferredDateDay) "
            }
        } else {
            cell.dueDateLabel.text = " Due: Not Set "
            if let currentDueDate = deficientItem.currentDueDate {
                let formatter = DateFormatter()
//                formatter.dateStyle = DateFormatter.Style.medium
//                formatter.timeStyle = .none
                formatter.dateFormat = "MM/dd/yyyy"
                cell.dueDateLabel.text = " Due: \(formatter.string(from: currentDueDate)) "
                if currentDueDate.timeIntervalSince1970 > Date().timeIntervalSince1970 {
                    cell.dueDateLabel.backgroundColor = GlobalColors.itemDueDatePendingBlue
                } else {
                    cell.dueDateLabel.backgroundColor = GlobalColors.itemDueDateRed
                }
            }
            // Override with Day string
            if let currentDueDateDay = deficientItem.currentDueDateDay {
                cell.dueDateLabel.text = " Due: \(currentDueDateDay) "
            }
        }

        if sectionWithDeficientItems.section == .closed {
            cell.dueDateLabel.backgroundColor = UIColor.darkGray
            if deficientItem.isDuplicate {
                cell.dueDateLabel.text = " DUPLICATE "
            }
        }
        
        cell.sectionTitleLabel.text = deficientItem.sectionTitle
        if let sectionSubtitle = deficientItem.sectionSubtitle, sectionSubtitle != "" {
            cell.sectionTitleLabel.text = "\(deficientItem.sectionTitle)\n\(sectionSubtitle)"
        }
        
        if let mainInputTypeEnum = TemplateItemActions(rawValue: deficientItem.itemMainInputType.lowercased()) {
            
            switch mainInputTypeEnum {
            case .TwoActions_checkmarkX:
                switch deficientItem.itemMainInputSelection {
                case 1:
                    cell.deficientInputImageView.image = UIImage(named: twoActions_checkmarkX_iconNames.iconName1)
                default:
                    cell.deficientInputImageView.image = nil
                }

            case .TwoActions_thumbs:
                switch deficientItem.itemMainInputSelection {
                case 1:
                    cell.deficientInputImageView.image = UIImage(named: twoActions_thumbs_iconNames.iconName1)
                default:
                    cell.deficientInputImageView.image = nil
                }
                
            case .ThreeActions_checkmarkExclamationX:
                switch deficientItem.itemMainInputSelection {
                case 1:
                    cell.deficientInputImageView.image = UIImage(named: threeActions_checkmarkExclamationX_iconNames.iconName1)
                case 2:
                    cell.deficientInputImageView.image = UIImage(named: threeActions_checkmarkExclamationX_iconNames.iconName2)
                default:
                    cell.deficientInputImageView.image = nil
                }

            case .ThreeActions_ABC:
                switch deficientItem.itemMainInputSelection {
                case 1:
                    cell.deficientInputImageView.image = UIImage(named: threeActions_ABC_iconNames.iconName1)
                case 2:
                    cell.deficientInputImageView.image = UIImage(named: threeActions_ABC_iconNames.iconName2)
                default:
                    cell.deficientInputImageView.image = nil
                }

            case .FiveActions_oneToFive:
                switch deficientItem.itemMainInputSelection {
                case 0:
                    cell.deficientInputImageView.image = UIImage(named: fiveActions_oneToFive_iconNames.iconName0)
                case 1:
                    cell.deficientInputImageView.image = UIImage(named: fiveActions_oneToFive_iconNames.iconName1)
                case 2:
                    cell.deficientInputImageView.image = UIImage(named: fiveActions_oneToFive_iconNames.iconName2)
                case 3:
                    cell.deficientInputImageView.image = UIImage(named: fiveActions_oneToFive_iconNames.iconName3)
                default:
                    cell.deficientInputImageView.image = nil
                }
                
            case .OneAction_notes:
                cell.deficientInputImageView.image = nil
            }
        } else {
            cell.deficientInputImageView.image = nil // default
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sectionWithDeficientItems = sectionsWithDeficientItems[indexPath.section]
        let keyDeficientItem = sectionWithDeficientItems.deficientItems[indexPath.row]
        if let deficientItemCopy = Mapper<InspectionDeficientItem>().map(JSON: keyDeficientItem.item.toJSON()) {
            selectedKeyDeficientItem = (key: keyDeficientItem.key, item: deficientItemCopy)
            performSegue(withIdentifier: "openDeficientItem", sender: self)
        }
        
//        let deficientItemKey = keyDeficientItem.key
//        SVProgressHUD.show()
//        dbDocumentDeficientItemWith(documentId: deficientItemKey).delete { error in
//            DispatchQueue.main.async {
//                if let error = error {
//                    SVProgressHUD.showError(withStatus: error.localizedDescription)
//                } else {
//                    SVProgressHUD.dismiss()
//                }
//            }
//        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {

        let sectionWithDeficientItems = sectionsWithDeficientItems[indexPath.section]
        let deficientItemKey = sectionWithDeficientItems.deficientItems[indexPath.row].key
        
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (_, _, completion) in
            guard let weakSelf = self else {
                completion(false)
                return
            }
            
            weakSelf.alertForDeleting(deficientItemKey)
            completion(true)
        }
        
        delete.backgroundColor = UIColor.red
        
        return UISwipeActionsConfiguration(actions: [delete])
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if let profile = currentUserProfile, !profile.isDisabled {
            return profile.admin
        }
        
        return false
    }
    
    // MARK: Alerts
    
    func alertForDeleting(_ deficientItemKey: String) {
        let alertController = UIAlertController(title: "Are you sure you want to delete this deficient item?", message: nil, preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel action"), style: .cancel, handler: { (action) in
            print("Cancel Action")
        })
        alertController.addAction(cancelAction)

        let deleteAction = UIAlertAction(title: NSLocalizedString("DELETE", comment: "Delete Action"), style: .destructive, handler: { (action) in
            DispatchQueue.main.async {
                SVProgressHUD.show()
                dbDocumentDeficientItemWith(documentId: deficientItemKey).delete { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            SVProgressHUD.showError(withStatus: error.localizedDescription)
                        } else {
                            SVProgressHUD.dismiss()
                        }
                    }
                }
            }
        })
        alertController.addAction(deleteAction)
        
        present(alertController, animated: true, completion: {})
    }
    
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "openDeficientItem" {
            if let vc = segue.destination as? DeficientItemVC, let selectedKeyDeficientItem = selectedKeyDeficientItem {
                vc.keyDeficientItem = selectedKeyDeficientItem
                if let keyProperty = keyProperty {
                    vc.keyProperty = keyProperty
                } else {
                    vc.propertyKey = propertyKey
                }

                self.selectedKeyDeficientItem = nil
            }
        }
    }
 
    
    func setObservers() {
        if let user = currentUser {
            userListener = dbDocumentUserWith(userId: user.uid).addSnapshotListener({ [weak self] (documentSnapshot, error) in
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        return
                    }
                    
                    weakSelf.adminCorporateUser = false
                    
                    print("Current User Profile Updated, observed by DeficientItemsVC")
                    if let document = documentSnapshot, document.exists {
                        if let profile = Mapper<UserProfile>().map(JSONObject: document.data()), !profile.isDisabled {
                            let admin = profile.admin
                            let corporate = profile.corporate
                            
                            weakSelf.adminCorporateUser = admin || corporate
                        }
                    }
                }
            })
        }
        
        
        guard let propertyId = keyProperty?.key ?? propertyKey else {
            print("ERROR: No set keyProperty to start observing")
            return
        }
        
        presentHUDForConnection()
        
        dbQueryDeficiencesWith(propertyId: propertyId).getDocuments { [weak self] (querySnapshot, error) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                if let error = error {
                    dismissHUDForConnection()
                    print("Error getting Deficiencies: \(error)")
                    return
                } else if querySnapshot!.documents.count == 0 {
                    dismissHUDForConnection()
                } else {
                    print("Deficiecies count: \(querySnapshot!.documents.count)")
                    weakSelf.dismissHUD = true
                }
                
                weakSelf.deficientItemsForPropertyListener = dbQueryDeficiencesWith(propertyId: propertyId).addSnapshotListener { (querySnapshot, error) in
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
                                
                                let newDeficientItem: keyInspectionDeficientItem = (diff.document.documentID, Mapper<InspectionDeficientItem>().map(JSONObject: diff.document.data())!)

                                print(newDeficientItem.item.state ?? "UNKNOWN")
                                
                                weakSelf.deficientItems.append(newDeficientItem)
                                weakSelf.updateDeficientSectionsWithItems()
                                
                                print("Adding deficient item: \(newDeficientItem.key)")
                            }
                            if (diff.type == .modified) {
                                let changedDeficientItem: keyInspectionDeficientItem = (diff.document.documentID, Mapper<InspectionDeficientItem>().map(JSONObject: diff.document.data())!)
                                
                                if let index = weakSelf.deficientItems.index( where: { $0.key == diff.document.documentID} ) {
                                    weakSelf.deficientItems.remove(at: index)
                                    weakSelf.deficientItems.insert(changedDeficientItem, at: index)
                                    //let indexPathToUpdate = NSIndexPath(forRow: index, inSection: 0)
                                    //self.tableView.reloadRowsAtIndexPaths([indexPathToUpdate], withRowAnimation: .Automatic)
                                    weakSelf.updateDeficientSectionsWithItems()
                                }
                            }
                            if (diff.type == .removed) {
                                if let index = weakSelf.deficientItems.index( where: { $0.key == diff.document.documentID} ) {
                                    weakSelf.deficientItems.remove(at: index)
                                    weakSelf.updateDeficientSectionsWithItems()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
