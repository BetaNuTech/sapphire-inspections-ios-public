//
//  DeficientItemVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 4/10/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import SwiftyJSON
import Alamofire
import FirebaseFirestore

enum DICellElement {
    case itemTitle
    case itemSection
    case itemPhotos
    case inspectorNotes
    case state
    case stateHistory
    case createdAt
    case currentDueDate
    case currentDeferredDate
    case dueDates
    case deferredDates
    case currentPlanToFix
    case plansToFix
    case currentResponsibilityGroup
    case responsibilityGroups
    case newProgressNote
    case latestProgressNote
    case progressNotes
    case currentReasonIncomplete
    case reasonsIncomplete
    case completedPhotos
    case completeNowReasons
    case followUpGoBackReject
    case followUpGoBackExtend
    case followUpClose
    case actionUpdate
    case actionComplete
    case actionCompleteNow
    case actionDefer
    case actionDeferredGoBack
    case actionDeferredDuplicate
    case actionTrelloViewCard
    case actionTrelloCreateCard
}

class DeficientItemVC: UIViewController, UITableViewDelegate, UITableViewDataSource, DeficientItemNotesVCDelegate, DeficientItemDatePickerVCDelegate, DeficientItemPickerVCDelegate, DeficientItemGalleryVCDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var navItem: UINavigationItem!
    @IBOutlet var cancelButton: UIBarButtonItem!
    @IBOutlet var saveButton: UIBarButtonItem!
    
    var keyProperty: KeyProperty?
    var keyDeficientItem: keyInspectionDeficientItem?

    // Open from URIs only
    var propertyKey: String?
    var deficientItemKey: String?

    enum DISection: String {
        case itemDetails = "ITEM DETAILS"
        case itemNotes = "ITEM NOTES"
        case state = "CURRENT STATE"
        case planToFix = "PLAN TO FIX"
        case responsibilityGroup = "RESPONSIBLITY GROUP"
        case dueDate = "DUE DATE"
        case deferredDate = "DEFERRED DATE"
        case progressNotes = "PROGRESS NOTE(S)"
        case reasonIncomplete = "REASON INCOMPLETE"
        case completedDetails = "COMPLETED DETAILS"
        case actions = "ACTION(S)"
        case trello = "TRELLO"
    }
    
    var deficientItemHasUpdates = false
    
    // For Viewing/Editing data on another screen
    var elementToView: DICellElement?
    var elementToEdit: DICellElement?
    var elementStringValue: String?
    var elementDateValue: Date?
    var elementJSONValue: JSON?
    var elementNewStringValue: String?
    var elementNewDateValue: Date?
    var elementNewDateDayValue: String?
    var elementNewJSONValue: JSON?
    var elementTitleForSegue: String?
    var elementWasUpdated = false

    typealias DISectionAndElements = (section: DISection, elements: [DICellElement])

    var sectionsAndElements: [DISectionAndElements] = []
    
    var deficientItemListener: ListenerRegistration?
    var propertyListener: ListenerRegistration?

    deinit {
        if let listener = deficientItemListener {
            listener.remove()
        }
        if let listener = propertyListener {
            listener.remove()
        }
    }

    // MARK: - View

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
        
        if elementWasUpdated {
            deficientItemHasUpdates = true
            processElementUpdate()
        } else {
            createLayout()
            tableView.reloadData()
        }
        
        updateNavButtons()
    }
    
    // MARK: - Nav Buttons

    func updateNavButtons() {
        if deficientItemHasUpdates {
            addCancelButton()
            // Now using table button to save
//            addSaveButton()
        } else {
            removeCancelButton()
            removeSaveButton()
        }
    }
    
    func addCancelButton() {
        guard var leftBarButtonItems = navItem?.leftBarButtonItems else {
            return
        }
        
        if !leftBarButtonItems.contains(cancelButton) {
            leftBarButtonItems.append(cancelButton)
            navItem?.leftBarButtonItems = leftBarButtonItems
        }
    }
    
    func removeCancelButton() {
        guard var leftBarButtonItems = navItem?.leftBarButtonItems else {
            return
        }
        
        if let index = leftBarButtonItems.index(of: cancelButton) {
            leftBarButtonItems.remove(at: index)
            navItem?.leftBarButtonItems = leftBarButtonItems
        }
    }
    
    func addSaveButton() {
        guard var rightBarButtonItems = navItem?.rightBarButtonItems else {
            return
        }
        
        if !rightBarButtonItems.contains(saveButton) {
            rightBarButtonItems.append(saveButton)
            navItem?.rightBarButtonItems = rightBarButtonItems
        }
    }
    
    func removeSaveButton() {
        guard var rightBarButtonItems = navItem?.rightBarButtonItems else {
            return
        }
        
        if let index = rightBarButtonItems.index(of: saveButton) {
            rightBarButtonItems.remove(at: index)
            navItem?.rightBarButtonItems = rightBarButtonItems
        }
    }
    
    @IBAction func cancelButtonTapped(_ sender: Any) {
        if deficientItemHasUpdates {
            // show confirmation alert
            alertForCanceling()
        }
    }
    
    @IBAction func saveButtonTapped(_ sender: Any) {
        saveUpdates(moveToState: nil)
    }
    
    func saveUpdates(moveToState: InspectionDeficientItemState?) {
        guard FIRConnection.connected() else {
            alertForSaveValidationError(errorMessage: "Cannot save offline, please reconnect to the internet.")
            return
        }
        
        guard let keyDeficientItem = keyDeficientItem else {
            print("keyDeficientItem Data is nil")
            return
        }
        
        if let currentState = InspectionDeficientItemState(rawValue: keyDeficientItem.item.state ?? "") {
            
            
            var newState: InspectionDeficientItemState?
            if moveToState != nil {
                newState = moveToState
            } else {
                switch currentState {
                case .requiresAction, .goBack, .requiresProgressUpdate:
                    newState = .pending
                case .overdue:
                    newState = .incomplete
                default:
                    newState = currentState  // Adding progress note or admin/corporate edit(s)
                }
            }
            
            //            guard newState != nil else {
            //                alertForSaveValidationError(errorMessage: "Unexpected Save request for state: \(currentState.rawValue)")
            //                return
            //            }
            
            guard let keyProperty = keyProperty else {
                alertForSaveValidationError(errorMessage: "keyProperty is nil")
                return
            }
            
            let (updatedDeficientItem, errorMessage) = InspectionDeficientItem.validateAddHistoryAndMoveToNewState(propertyKey: keyProperty.key, deficientItemKey: keyDeficientItem.key, deficientItem: keyDeficientItem.item, newState: newState!)
            if errorMessage != nil {
                alertForSaveValidationError(errorMessage: errorMessage!)
                return
            }
            
            // Save all updates, change states, if necessary
            // Enter history elements
            // Remove Save and Cancel buttons, remove hasUpdates status
            
            if let updatedDeficientItem = updatedDeficientItem {
                SVProgressHUD.show()
                let jsonDict = updatedDeficientItem.toJSON()
                
                dbDocumentDeficientItemWith(documentId: keyDeficientItem.key).setData(jsonDict, merge: true) { [weak self] (error) in
                    DispatchQueue.main.async {
                        SVProgressHUD.dismiss()
                        
                        if error != nil {
                            self?.alertForSaveValidationError(errorMessage: error!.localizedDescription)
                            return
                        }
                        
                        let keyUpdatedDeficientItem = (key: keyDeficientItem.key, item: updatedDeficientItem)
                        Notifications.sendPropertyDeficientItemStateChange(keyProperty: keyProperty, keyInspectionDeficientItem: keyUpdatedDeficientItem, prevState: currentState.rawValue)
                        
                        self?.deficientItemHasUpdates = false
                        self?.keyDeficientItem?.item = updatedDeficientItem
                        self?.updateNavButtons()
                        self?.createLayout()
                        self?.tableView.reloadData()
                    }
                }
            } else {
                alertForSaveValidationError(errorMessage: "Updated Deficient Item data is nil")
            }
            
        }
    }
    
//    func checkForValidationErrors() -> String? {
//        guard let keyDeficientItem = keyDeficientItem else {
//            return "keyDeficientItem Data is nil"
//        }
//
//        if let state = InspectionDeficientItemState(rawValue: keyDeficientItem.item.state ?? "") {
//            switch state {
//            case .requiresAction:
//                if keyDeficientItem.item.currentPlanToFix == nil {
//                    return "Plan to Fix is required."
//                }
//                if keyDeficientItem.item.currentResponsibilityGroup == nil {
//                    return "Responsibility Group needs to be set."
//                }
//                if keyDeficientItem.item.currentDueDate == nil {
//                    return "Due Date is required."
//                }
//            default:
//                print("checkForValidationErrors - state unsupported")
//            }
//        }
//
//        return nil
//    }
    
    // MARK: - FORM: Section & Cells
    func createLayout() {
        guard let deficientItem = keyDeficientItem?.item else {
            sectionsAndElements = []
            return
        }
        
        guard let state = InspectionDeficientItemState(rawValue: deficientItem.state ?? "") else {
            sectionsAndElements = []
            return
        }
        
        var newSectionsAndElements: [DISectionAndElements] = []
        
        var elements: [DICellElement] = [.createdAt, .itemTitle, .itemSection]
        if deficientItem.hasItemPhotoData {
            elements.append(.itemPhotos)
        }
        newSectionsAndElements.append((section: .itemDetails, elements: elements))

        if deficientItem.itemInspectorNotes != nil {
            elements = [.inspectorNotes]
            newSectionsAndElements.append((section: .itemNotes, elements: elements))
        }
        
        elements = [.state]
        if let dict = deficientItem.stateHistory {
            let json = JSON(dict)
            if json.dictionaryValue.keys.count > 0 {
                elements = [.state, .stateHistory]
            }
        }
        newSectionsAndElements.append((section: .state, elements: elements))

        if state != .deferred {
            elements = []
            if state != .closed {
                elements.append(.currentPlanToFix)
            }
            if let dict = deficientItem.plansToFix {
                let json = JSON(dict)
                if json.dictionaryValue.keys.count > 0 {
                    elements.append(.plansToFix)
                }
            }
            
            if elements.count > 0 {
                newSectionsAndElements.append((section: .planToFix, elements: elements))
            }
            
            elements = []
            if state != .closed {
                elements.append(.currentResponsibilityGroup)
            }
            if let dict = deficientItem.responsibilityGroups {
                let json = JSON(dict)
                if json.dictionaryValue.keys.count > 0 {
                    elements.append(.responsibilityGroups)
                }
            }
            
            if elements.count > 0 {
                newSectionsAndElements.append((section: .responsibilityGroup, elements: elements))
            }
            
            elements = []
            if state != .closed {
                elements.append(.currentDueDate)
            }
            if let dict = deficientItem.dueDates {
                let json = JSON(dict)
                if json.dictionaryValue.keys.count > 0 {
                    elements.append(.dueDates)
                }
            }
            
            if elements.count > 0 {
                newSectionsAndElements.append((section: .dueDate, elements: elements))
            }
        }

        // Deferred Dates
        elements = []
        if deficientItem.currentDeferredDate != nil {
            if state != .closed {
                elements.append(.currentDeferredDate)
            }

        }
        if let dict = deficientItem.deferredDates {
            let json = JSON(dict)
            if json.dictionaryValue.keys.count > 0 {
                elements.append(.deferredDates)
            }
        }
        if elements.count > 0 {
            newSectionsAndElements.append((section: .deferredDate, elements: elements))
        }

//        var userIsAdmin = false
//        var userIsCorporate = false
//        if let profile = currentUserProfile, !profile.isDisabled {
//            userIsAdmin = profile.admin
//            userIsCorporate = profile.corporate
//        }
        elements = []
        let enableNewProgressNote = (state == .pending || state == .requiresProgressUpdate) &&
            deficientItem.unsavedProgressNote == nil
        var showLatestProgressNote = deficientItem.unsavedProgressNote != nil
        var showProgressNotes = false
        if let dict = deficientItem.progressNotes, JSON(dict).dictionaryValue.keys.count > 0 {
            showProgressNotes = true
            showLatestProgressNote = true
        }

        if enableNewProgressNote {
            elements.append(.newProgressNote)
        }
        if showLatestProgressNote {
            elements.append(.latestProgressNote)
        }
        if showProgressNotes {
            elements.append(.progressNotes)
        }
        
        if elements.count > 0 {
            newSectionsAndElements.append((section: .progressNotes, elements: elements))
        }
        
        if state == .pending {
            elements = []
            if deficientItemHasUpdates {
                elements.append(.actionUpdate)
            }
            elements.append(.actionComplete)
            elements.append(.actionDefer)
            newSectionsAndElements.append((section: .actions, elements: elements))
        }
        if state == .requiresProgressUpdate {
            elements = []
            if deficientItemHasUpdates {
                elements.append(.actionUpdate)
                newSectionsAndElements.append((section: .actions, elements: elements))
            }
        }
        if state == .requiresAction {
            elements = []
            if deficientItemHasUpdates {
                elements.append(.actionUpdate)
            }
            
            var timeLimitForCompleteNow: TimeInterval = 72*60*60 // PMs
            if let corporate = currentUserProfile?.corporate, corporate {
                timeLimitForCompleteNow = 7*24*60*60 // Corporate
            }
            if let admin = currentUserProfile?.admin, admin {
                elements.append(.actionCompleteNow)
                elements.append(.actionDefer)
            } else if let createdAt = deficientItem.createdAt?.timeIntervalSince1970, Date().timeIntervalSince1970 - createdAt < timeLimitForCompleteNow {
                elements.append(.actionCompleteNow)
                elements.append(.actionDefer)
            } else {
                elements.append(.actionDefer)
            }
            newSectionsAndElements.append((section: .actions, elements: elements))
        }
        if state == .goBack {
            elements = []
            if deficientItemHasUpdates {
                elements.append(.actionUpdate)
            }
            elements.append(.actionDefer)
            newSectionsAndElements.append((section: .actions, elements: elements))
        }
        if state == .deferred {
            elements = [.actionDeferredGoBack, .actionDeferredDuplicate]
            newSectionsAndElements.append((section: .actions, elements: elements))
        }
        if state == .overdue || state == .incomplete {
            elements = [.currentReasonIncomplete]
            if let dict = deficientItem.reasonsIncomplete {
                let json = JSON(dict)
                if json.dictionaryValue.keys.count > 0 {
                    elements = [.currentReasonIncomplete, .reasonsIncomplete]
                }
            }
            newSectionsAndElements.append((section: .reasonIncomplete, elements: elements))
            if deficientItemHasUpdates {
                elements = [.actionUpdate]
                newSectionsAndElements.append((section: .actions, elements: elements))
            }
        }
        if state == .completed {
            elements = [.completedPhotos, .followUpGoBackReject, .followUpClose]
            newSectionsAndElements.append((section: .actions, elements: elements))
        }
        if state == .incomplete {
            elements = [.followUpGoBackExtend, .followUpClose]
            newSectionsAndElements.append((section: .actions, elements: elements))
        }
        if state == .closed {
            elements = []
            if let dict = deficientItem.reasonsIncomplete {
                let json = JSON(dict)
                if json.dictionaryValue.keys.count > 0 {
                    elements = [.reasonsIncomplete]
                    newSectionsAndElements.append((section: .reasonIncomplete, elements: elements))
                }
            }
            elements = []
            if let dict = deficientItem.completedPhotos {
                let json = JSON(dict)
                if json.dictionaryValue.keys.count > 0 {
                    elements.append(.completedPhotos)
                }
            }
            if let dict = deficientItem.completeNowReasons {
                let json = JSON(dict)
                if json.dictionaryValue.keys.count > 0 {
                    elements.append(.completeNowReasons)
                }
            }
            if elements.count > 0 {
                newSectionsAndElements.append((section: .completedDetails, elements: elements))
            }
        }
        
        // TRELLO - Card exists
        if deficientItem.trelloCardURL != nil {
            elements = [.actionTrelloViewCard]
            newSectionsAndElements.append((section: .trello, elements: elements))
        } else if state != .closed {
            elements = [.actionTrelloCreateCard]
            newSectionsAndElements.append((section: .trello, elements: elements))
        }

        sectionsAndElements = newSectionsAndElements
    }
    
    // MARK: - TableView
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionsAndElements.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sectionsAndElements[section].elements.count
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Dequeue with the reuse identifier
        let cell = self.tableView.dequeueReusableHeaderFooterView(withIdentifier: "CategorySectionHeader")
        
        let header = cell as! CategorySectionHeader
        header.titleLabel.text = sectionsAndElements[section].section.rawValue
        header.titleLabel.textColor = UIColor.white
        header.background.backgroundColor = UIColor.darkGray

        return cell
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let deficientItem = keyDeficientItem?.item else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "staticTextCell")!
            return cell
        }
        
        var userIsAdmin = false
        var userIsCorporate = false
        if let profile = currentUserProfile, !profile.isDisabled {
            userIsAdmin = profile.admin
            userIsCorporate = profile.corporate
        }
        let userIsAdminOrCorporate = userIsAdmin || userIsCorporate
        
        let element = sectionsAndElements[indexPath.section].elements[indexPath.row]
        switch element {
        case .itemTitle:
            let cell = tableView.dequeueReusableCell(withIdentifier: "titleCell") as! DeficientItemGenericTVCell
            cell.elementTextLabel.text = deficientItem.itemTitle
            cell.backgroundColor = UIColor.clear
            return cell
        case .itemSection:
            let cell = tableView.dequeueReusableCell(withIdentifier: "subtitleCell") as! DeficientItemGenericTVCell
            if let sectionSubtitle = deficientItem.sectionSubtitle {
                cell.elementTextLabel.text = "\(deficientItem.sectionTitle)\n\(sectionSubtitle)"
            } else {
                cell.elementTextLabel.text = "\(deficientItem.sectionTitle)"
            }
            cell.backgroundColor = UIColor.clear
            return cell
        case .itemPhotos:
            let cell = tableView.dequeueReusableCell(withIdentifier: "showHistoryCell") as! DeficientItemGenericTVCell
            cell.elementTextLabel.text = "View Photo(s)"
            cell.backgroundColor = UIColor.clear
            return cell
        case .inspectorNotes:
            let cell = tableView.dequeueReusableCell(withIdentifier: "staticTextCell") as! DeficientItemGenericTVCell
            cell.elementTextLabel.text = deficientItem.itemInspectorNotes ?? ""
            cell.backgroundColor = UIColor.clear
            return cell
        case .state:
            let cell = tableView.dequeueReusableCell(withIdentifier: "centeredBoldTextCell") as! DeficientItemGenericTVCell
            let state = InspectionDeficientItemState(rawValue: deficientItem.state ?? "")
            cell.elementTextLabel.text = InspectionDeficientItem.stateDescription(state: state)
            cell.backgroundColor = UIColor.clear
            return cell
        case .stateHistory:
            let cell = tableView.dequeueReusableCell(withIdentifier: "showHistoryCell") as! DeficientItemGenericTVCell
            cell.elementTextLabel.text = "Show State History"
            cell.backgroundColor = UIColor.clear
            return cell
        case .createdAt:
            let cell = tableView.dequeueReusableCell(withIdentifier: "timestampCell") as! DeficientItemGenericTVCell
            let formatter = DateFormatter()
            formatter.dateStyle = DateFormatter.Style.long
            formatter.timeStyle = .medium
            if let createdAt = deficientItem.createdAt {
                cell.elementTextLabel.text = "Deficient Date: \(formatter.string(from: createdAt))"
            } else {
                cell.elementTextLabel.text = "Deficient Date: ?"
            }
            cell.backgroundColor = UIColor.clear
            return cell
        case .currentDueDate:
            let cell = tableView.dequeueReusableCell(withIdentifier: "valueCell") as! DeficientItemGenericTVCell
            let formatter = DateFormatter()
            formatter.dateStyle = DateFormatter.Style.medium
            formatter.timeStyle = DateFormatter.Style.short
            if let currentDueDate = deficientItem.currentDueDate {
                cell.elementTextLabel.text = "\(formatter.string(from: currentDueDate))"
                if let currentDueDateDay = deficientItem.currentDueDateDay {
                    cell.elementTextLabel.text = "\(currentDueDateDay)"
                }
                cell.backgroundColor = UIColor.clear
            } else {
                cell.elementTextLabel.text = "NOT SET"
                cell.backgroundColor = GlobalColors.incompleteItemColor
            }
            return cell
        case .currentDeferredDate:
            let cell = tableView.dequeueReusableCell(withIdentifier: "valueCell") as! DeficientItemGenericTVCell
            let formatter = DateFormatter()
            formatter.dateStyle = DateFormatter.Style.medium
            formatter.timeStyle = DateFormatter.Style.short
            if let currentDeferredDate = deficientItem.currentDeferredDate {
                cell.elementTextLabel.text = "\(formatter.string(from: currentDeferredDate))"
                if let currentDeferredDateDay = deficientItem.currentDeferredDateDay {
                    cell.elementTextLabel.text = "\(currentDeferredDateDay)"
                }
                cell.backgroundColor = UIColor.clear
            } else {
                cell.elementTextLabel.text = "NOT SET"
                cell.backgroundColor = GlobalColors.incompleteItemColor
            }
            return cell
        case .dueDates:
            let cell = tableView.dequeueReusableCell(withIdentifier: "showHistoryCell") as! DeficientItemGenericTVCell
            cell.elementTextLabel.text = "Show Previous Due Dates"
            cell.backgroundColor = UIColor.clear
            return cell
        case .deferredDates:
            let cell = tableView.dequeueReusableCell(withIdentifier: "showHistoryCell") as! DeficientItemGenericTVCell
            cell.elementTextLabel.text = "Show Previous Deferred Dates"
            cell.backgroundColor = UIColor.clear
            return cell
        case .currentPlanToFix:
            let cell = tableView.dequeueReusableCell(withIdentifier: "staticTextCell") as! DeficientItemGenericTVCell
            if let currentPlanToFix = deficientItem.currentPlanToFix {
                cell.elementTextLabel.text = currentPlanToFix
                cell.backgroundColor = UIColor.clear
            } else {
                cell.elementTextLabel.text = "NOT SET"
                cell.backgroundColor = GlobalColors.incompleteItemColor
            }
            return cell
        case .plansToFix:
            let cell = tableView.dequeueReusableCell(withIdentifier: "showHistoryCell") as! DeficientItemGenericTVCell
            cell.elementTextLabel.text = "Show Previous Plans to Fix"
            cell.backgroundColor = UIColor.clear
            return cell
        case .currentResponsibilityGroup:
            let cell = tableView.dequeueReusableCell(withIdentifier: "valueCell") as! DeficientItemGenericTVCell
            if let currentResponsibilityGroup = deficientItem.currentResponsibilityGroup {
                let group = InspectionDeficientItemResponsibilityGroup(rawValue: currentResponsibilityGroup)
                cell.elementTextLabel.text = InspectionDeficientItem.groupResponibleDescription(group: group)
                cell.backgroundColor = UIColor.clear
            } else {
                cell.elementTextLabel.text = "NOT SET"
                cell.backgroundColor = GlobalColors.incompleteItemColor
            }
            return cell
        case .responsibilityGroups:
            let cell = tableView.dequeueReusableCell(withIdentifier: "showHistoryCell") as! DeficientItemGenericTVCell
            cell.elementTextLabel.text = "Show Previous Groups Responsible"
            cell.backgroundColor = UIColor.clear
            return cell
        case .newProgressNote:
            let cell = tableView.dequeueReusableCell(withIdentifier: "showHistoryCell") as! DeficientItemGenericTVCell
            cell.elementTextLabel.text = "NEW"
            let state = InspectionDeficientItemState(rawValue: deficientItem.state ?? "")

            if state == .requiresProgressUpdate {
                cell.backgroundColor = GlobalColors.incompleteItemColor
            } else {
                cell.backgroundColor = UIColor.clear
            }
            return cell
        case .latestProgressNote:
            let cell = tableView.dequeueReusableCell(withIdentifier: "staticTextCell") as! DeficientItemGenericTVCell
            if let note = deficientItem.unsavedProgressNote {
                cell.elementTextLabel.text = note
            } else if let dict = deficientItem.progressNotes {
                let json = JSON(dict).dictionaryValue
                var progressNotes:[JSON] = []
                for valueJSON in json.values {
                    progressNotes.append(valueJSON)
                }
                
                // Sort
                progressNotes.sort(by: { (first, second) -> Bool in
                    let firstCreatedAt = first["createdAt"].doubleValue
                    let secondCreatedAt = second["createdAt"].doubleValue
                    return firstCreatedAt > secondCreatedAt
                })
                
                if let latestProgressNote = progressNotes.first, let note = latestProgressNote["progressNote"].string {
                    cell.elementTextLabel.text = note
                } else {
                    cell.elementTextLabel.text = "<nil>"
                }
            } else {
                cell.elementTextLabel.text = "<nil>"
            }
            cell.backgroundColor = UIColor.clear
            return cell
        case .progressNotes:
            let cell = tableView.dequeueReusableCell(withIdentifier: "showHistoryCell") as! DeficientItemGenericTVCell
            cell.elementTextLabel.text = "Show All Progress Notes"
            cell.backgroundColor = UIColor.clear
            return cell
        case .currentReasonIncomplete:
            let cell = tableView.dequeueReusableCell(withIdentifier: "staticTextCell") as! DeficientItemGenericTVCell
            if let currentReasonIncomplete = deficientItem.currentReasonIncomplete {
                cell.elementTextLabel.text = currentReasonIncomplete
                cell.backgroundColor = UIColor.clear
            } else {
                cell.elementTextLabel.text = "NOT SET"
                cell.backgroundColor = GlobalColors.incompleteItemColor
            }
            return cell
        case .reasonsIncomplete:
            let cell = tableView.dequeueReusableCell(withIdentifier: "showHistoryCell") as! DeficientItemGenericTVCell
            cell.elementTextLabel.text = "Show Previous Reasons Incomplete"
            cell.backgroundColor = UIColor.clear
            return cell
        case .completedPhotos:
            let cell = tableView.dequeueReusableCell(withIdentifier: "showHistoryCell") as! DeficientItemGenericTVCell
            cell.elementTextLabel.text = "Show Completed Photo(s)"
            cell.backgroundColor = UIColor.clear
            return cell
        case .completeNowReasons:
            let cell = tableView.dequeueReusableCell(withIdentifier: "showHistoryCell") as! DeficientItemGenericTVCell
            cell.elementTextLabel.text = "Show Complete Now Reason(s)"
            cell.backgroundColor = UIColor.clear
            return cell
        case .actionUpdate:
            let cell = tableView.dequeueReusableCell(withIdentifier: "buttonCell") as! DeficientItemButtonTVCell
            cell.button.setTitle("SAVE", for: .normal)
            cell.button.backgroundColor = GlobalColors.itemCompletedGreen
            cell.buttonActionClosure = { [weak self] in
                self?.saveUpdates(moveToState: nil)
            }
            return cell
        case .actionComplete:
            let cell = tableView.dequeueReusableCell(withIdentifier: "buttonCell") as! DeficientItemButtonTVCell
            cell.button.setTitle("COMPLETED", for: .normal)
            cell.button.backgroundColor = GlobalColors.itemDueDatePendingBlue
            cell.buttonActionClosure = { [weak self] in
                DispatchQueue.main.async {
                    self?.elementToEdit = element
                    self?.elementToView = nil
                    self?.elementJSONValue = JSON(deficientItem.completedPhotos ?? [:])
                    self?.elementTitleForSegue = "Completed Photo(s)"
                    self?.performSegue(withIdentifier: "deficientItemToDeficientItemGallery", sender: self)
                }
            }
            return cell
        case .actionCompleteNow:
            let cell = tableView.dequeueReusableCell(withIdentifier: "buttonCell") as! DeficientItemButtonTVCell
            cell.button.setTitle("COMPLETE NOW", for: .normal)
            cell.button.backgroundColor = GlobalColors.itemDueDatePendingBlue
            cell.buttonActionClosure = { [weak self] in
                DispatchQueue.main.async {
                    self?.elementToEdit = element
                    self?.elementToView = nil
                    self?.elementStringValue = ""
                    self?.elementTitleForSegue = "Complete Now Reason"
                    self?.performSegue(withIdentifier: "deficientItemToTextView", sender: self)
                }
            }
            return cell
        case .actionDefer:
            let cell = tableView.dequeueReusableCell(withIdentifier: "buttonCell") as! DeficientItemButtonTVCell
            cell.button.setTitle("DEFER", for: .normal)
            cell.button.backgroundColor = UIColor.orange
            cell.buttonActionClosure = { [weak self] in
                DispatchQueue.main.async {
                    self?.elementToEdit = nil
                    self?.elementToView = nil
                    self?.elementDateValue = nil
                    if let state = InspectionDeficientItemState(rawValue: deficientItem.state ?? "") {
                        if state == .requiresAction || state == .pending || state == .goBack {
                            if userIsAdminOrCorporate {
                                self?.elementToEdit = element
                                self?.elementDateValue = nil
                                self?.elementTitleForSegue = "Deferred Date"
                                self?.performSegue(withIdentifier: "deficientItemToDatePicker", sender: self)
                            } else {
                                self?.alertForNonCorporateAction()
                            }
                        }
                    }
                }
            }
            return cell
        case .followUpGoBackReject:
            let cell = tableView.dequeueReusableCell(withIdentifier: "buttonCell") as! DeficientItemButtonTVCell
            cell.button.setTitle("GO BACK", for: .normal)
            cell.button.backgroundColor = GlobalColors.itemDueDateRed
            cell.buttonActionClosure = { [weak self] in
                if userIsAdminOrCorporate {
                    self?.saveUpdates(moveToState: .goBack)
                } else {
                    self?.alertForNonCorporateAction()
                }
            }
            return cell
        case .followUpGoBackExtend, .actionDeferredGoBack:
            let cell = tableView.dequeueReusableCell(withIdentifier: "buttonCell") as! DeficientItemButtonTVCell
            cell.button.setTitle("GO BACK", for: .normal)
            cell.button.backgroundColor = GlobalColors.itemDueDatePendingBlue
            cell.buttonActionClosure = { [weak self] in
                if userIsAdminOrCorporate {
                    self?.saveUpdates(moveToState: .goBack)
                } else {
                    self?.alertForNonCorporateAction()
                }
            }
            return cell
        case .followUpClose:
            let cell = tableView.dequeueReusableCell(withIdentifier: "buttonCell") as! DeficientItemButtonTVCell
            cell.button.setTitle("CLOSE", for: .normal)
            cell.button.backgroundColor = GlobalColors.itemCompletedGreen
            cell.buttonActionClosure = { [weak self] in
                if userIsAdminOrCorporate {
                    self?.saveUpdates(moveToState: .closed)
                } else {
                    self?.alertForNonCorporateAction()
                }
            }
            return cell
        case .actionDeferredDuplicate:
            let cell = tableView.dequeueReusableCell(withIdentifier: "buttonCell") as! DeficientItemButtonTVCell
            cell.button.setTitle("CLOSE (DUPLICATE)", for: .normal)
            cell.button.backgroundColor = GlobalColors.unselectedGrey
            cell.buttonActionClosure = { [weak self] in
                if userIsAdminOrCorporate {
                    self?.saveUpdates(moveToState: .closed)
                } else {
                    self?.alertForNonCorporateAction()
                }
            }
            return cell
        case .actionTrelloViewCard:
            let cell = tableView.dequeueReusableCell(withIdentifier: "buttonCell") as! DeficientItemButtonTVCell
            cell.button.setTitle("VIEW CARD", for: .normal)
//            cell.button.setTitle("OPEN CARD", for: .normal)
            cell.button.backgroundColor = GlobalColors.trelloBlue
            cell.buttonActionClosure = {
                guard let urlString = deficientItem.trelloCardURL, urlString != "" else {
                    print("ERROR: URL not set yet")
                    return
                }
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
            return cell
        case .actionTrelloCreateCard:
            let cell = tableView.dequeueReusableCell(withIdentifier: "buttonCell") as! DeficientItemButtonTVCell
            cell.button.setTitle("CREATE CARD", for: .normal)
            //            cell.button.setTitle("OPEN CARD", for: .normal)
            cell.button.backgroundColor = GlobalColors.trelloBlue
            cell.buttonActionClosure = { [weak self] in
                self?.createTrelloCard()
            }
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let deficientItem = keyDeficientItem?.item else {
            return
        }
        
        let element = sectionsAndElements[indexPath.section].elements[indexPath.row]
        switch element {
        case .itemPhotos:
            print("Open Photo(s) View")
            performSegue(withIdentifier: "deficientItemToGallery", sender: self)
        case .inspectorNotes:
            print("Open Notes View")
            performSegue(withIdentifier: "deficientItemToNotes", sender: self)
        case .stateHistory:
            print("Open state history table View")
            elementToEdit = nil
            elementToView = element
            elementJSONValue = JSON(deficientItem.stateHistory ?? [:])
            elementTitleForSegue = "State History"
            performSegue(withIdentifier: "deficientItemToHistory", sender: self)
        case .currentDueDate:
            elementToEdit = nil
            elementToView = nil
            elementDateValue = nil
            if let state = InspectionDeficientItemState(rawValue: deficientItem.state ?? "") {
                if state == .requiresAction || state == .goBack {
                    elementToEdit = element
                    elementDateValue = nil
                    elementTitleForSegue = "Due Date"
                    performSegue(withIdentifier: "deficientItemToDatePicker", sender: self)
                }
            }
            print("Allow editing, if not yet saved or nil.  Or if admin/corporate, allow new one be set.")
        case .dueDates:
            print("Open due dates history table View.")
            elementToEdit = nil
            elementToView = element
            elementJSONValue = JSON(deficientItem.dueDates ?? [:])
            elementTitleForSegue = "Due Dates - History"
            performSegue(withIdentifier: "deficientItemToHistory", sender: self)
        case .deferredDates:
            print("Open deferred dates history table View.")
            elementToEdit = nil
            elementToView = element
            elementJSONValue = JSON(deficientItem.deferredDates ?? [:])
            elementTitleForSegue = "Deferred Dates - History"
            performSegue(withIdentifier: "deficientItemToHistory", sender: self)
        case .currentPlanToFix:
            elementToEdit = nil
            elementToView = nil
            elementStringValue = ""
            if let state = InspectionDeficientItemState(rawValue: deficientItem.state ?? "") {
                if state == .requiresAction || state == .goBack {
                    elementToEdit = element
                    elementStringValue = deficientItem.currentPlanToFix
                    elementTitleForSegue = "Plan to Fix"
                    performSegue(withIdentifier: "deficientItemToTextView", sender: self)
                }
            }
            print("Allow editing, if not yet saved or nil.")
        case .plansToFix:
            print("Open plans to fix table View.")
            elementToEdit = nil
            elementToView = element
            elementJSONValue = JSON(deficientItem.plansToFix ?? [:])
            elementTitleForSegue = "Plans to Fix - History"
            performSegue(withIdentifier: "deficientItemToHistory", sender: self)
        case .currentResponsibilityGroup:
            elementToEdit = nil
            elementToView = nil
            elementStringValue = ""
            if let state = InspectionDeficientItemState(rawValue: deficientItem.state ?? "") {
                if state == .requiresAction || state == .goBack {
                    elementToEdit = element
                    elementStringValue = deficientItem.currentResponsibilityGroup
                    elementTitleForSegue = "Responsibility Group"
                    performSegue(withIdentifier: "deficientItemToPicker", sender: self)
                }
            }
            print("Allow editing, if not yet saved or nil. Or if admin/corporate, allow new one be set.")
        case .responsibilityGroups:
            print("Open responsibilityGroups table View.")
            elementToEdit = nil
            elementToView = element
            elementJSONValue = JSON(deficientItem.responsibilityGroups ?? [:])
            elementTitleForSegue = "Responsibility Groups - History"
            performSegue(withIdentifier: "deficientItemToHistory", sender: self)
        case .newProgressNote:
            print("Allow new progress note, opening view to enter it.")
            elementToEdit = element
            elementToView = nil
            elementStringValue = ""
            elementTitleForSegue = "NEW Progress Note"
            performSegue(withIdentifier: "deficientItemToTextView", sender: self)
        case .latestProgressNote:
            print("Allow editing, if not yet saved.")
            // Only open textview, if there is an unsaved progress note
            if deficientItem.unsavedProgressNote != nil {
                elementToEdit = element
                elementToView = nil
                elementStringValue = deficientItem.unsavedProgressNote
                elementTitleForSegue = "NEW Progress Note"
                performSegue(withIdentifier: "deficientItemToTextView", sender: self)
            }
        case .progressNotes:
            print("Open progress notes table View.")
            elementToEdit = nil
            elementToView = element
            elementJSONValue = JSON(deficientItem.progressNotes ?? [:])
            elementTitleForSegue = "Progress Noties - History"
            performSegue(withIdentifier: "deficientItemToHistory", sender: self)
        case .currentReasonIncomplete:
            print("Allow editing, if not yet saved or nil")
            elementToEdit = nil
            elementToView = nil
            elementStringValue = ""
            if let state = InspectionDeficientItemState(rawValue: deficientItem.state ?? "") {
                if state == .overdue {
                    elementToEdit = element
                    elementStringValue = deficientItem.currentReasonIncomplete
                    elementTitleForSegue = "OVERDUE - Reason Incomplete"
                    performSegue(withIdentifier: "deficientItemToTextView", sender: self)
                }
            }
        case .reasonsIncomplete:
            print("Open reasons incomplete table View.")
            elementToEdit = nil
            elementToView = element
            elementJSONValue = JSON(deficientItem.reasonsIncomplete ?? [:])
            elementTitleForSegue = "Reasons Incomplete - History"
            performSegue(withIdentifier: "deficientItemToHistory", sender: self)
        case .completedPhotos:
            print("Open completed photos view, sectioned by start date.")
            elementToEdit = nil
            elementToView = element
            elementJSONValue = JSON(deficientItem.completedPhotos ?? [:])
            elementTitleForSegue = "Completed Photo(s)"
            performSegue(withIdentifier: "deficientItemToDeficientItemGallery", sender: self)
        case .completeNowReasons:
            print("Open Complete Now Reasons table View.")
            elementToEdit = nil
            elementToView = element
            elementJSONValue = JSON(deficientItem.completeNowReasons ?? [:])
            elementTitleForSegue = "Complete Now Reason(s) - History"
            performSegue(withIdentifier: "deficientItemToHistory", sender: self)
        default:
            print("ignoring cell selection.")
        }
        
    }

    // MARK: - DeficientItemNotesVCDelegate
    
    func deficientItemTextUpdated(text: String, element: DICellElement) {
        switch element {
        case .currentPlanToFix:
            elementNewStringValue = text
            elementWasUpdated = true
        case .currentReasonIncomplete:
            elementNewStringValue = text
            elementWasUpdated = true
        case .latestProgressNote, .newProgressNote:
            elementNewStringValue = text
            elementWasUpdated = true
        case .actionCompleteNow:
            elementNewStringValue = text
            elementWasUpdated = true

        default:
            print("ERROR: deficientItemTextUpdated - unsupported element")
        }
        
        if elementNewStringValue == "" {
            elementNewStringValue = nil
            
            // Reset, if no other updates yet
            if !deficientItemHasUpdates {
                elementWasUpdated = false
            }
        }
    }
    
    // MARK: - DeficientItemDatePickerVCDelegate
    
    func deficientItemDateUpdated(date: Date, dateDay: String, element: DICellElement) {
        switch element {
        case .currentDueDate:
            elementNewDateValue = date
            elementNewDateDayValue = dateDay
            elementWasUpdated = true
        case .actionDefer:
            elementNewDateValue = date
            elementNewDateDayValue = dateDay
            elementWasUpdated = true
            
        default:
            print("ERROR: deficientItemTextUpdated - unsupported element")
        }
    }
    
    // MARK: - DeficientItemPickerVCDelegate
    
    func deficientItemPickerValueUpdated(value: String, element: DICellElement) {
        switch element {
        case .currentResponsibilityGroup:
            if value == "" {
                elementNewStringValue = nil
            } else {
                elementNewStringValue = value
            }
            elementWasUpdated = true
            
        default:
            print("ERROR: deficientItemPickerValueUpdated - unsupported element")
        }
    }
    
    // MARK: - DeficientItemGalleryVCDelegate

    func updatedPhotosData(photosData: JSON) {
        elementNewJSONValue = photosData
        elementWasUpdated = true
    }

    // MARK: - Process Element Update
    
    func processElementUpdate() {
        guard let element = elementToEdit else {
            print("ERROR: processElementUpdate - elementToEdit is nil")
            return
        }
        
        switch element {
        case .currentPlanToFix:
            keyDeficientItem?.item.currentPlanToFix = elementNewStringValue
        case .currentReasonIncomplete:
            keyDeficientItem?.item.currentReasonIncomplete = elementNewStringValue
        case .currentDueDate:
            if let date = elementNewDateValue {
                keyDeficientItem?.item.currentDueDate = date
            }
            if let dateDay = elementNewDateDayValue {
                keyDeficientItem?.item.currentDueDateDay = dateDay
            }
        case .actionDefer:
            if let date = elementNewDateValue {
                keyDeficientItem?.item.currentDeferredDate = date
                saveUpdates(moveToState: .deferred)
            }
            if let dateDay = elementNewDateDayValue {
                keyDeficientItem?.item.currentDeferredDateDay = dateDay
            }
        case .currentResponsibilityGroup:
            keyDeficientItem?.item.currentResponsibilityGroup = elementNewStringValue
        case .latestProgressNote, .newProgressNote:
            keyDeficientItem?.item.unsavedProgressNote = elementNewStringValue
        case .actionComplete:
            if let newJSON = elementNewJSONValue?.dictionaryObject {
                keyDeficientItem?.item.completedPhotos = newJSON as [String : AnyObject]
                saveUpdates(moveToState: .completed)
            }
        case .actionCompleteNow:
            keyDeficientItem?.item.currentCompleteNowReason = elementNewStringValue
            saveUpdates(moveToState: .closed)

        default:
            print("ERROR: deficientItemTextUpdated - unsuported element or nil")
        }
        
        createLayout()
        tableView.reloadData()
        
        elementToEdit = nil
        elementNewStringValue = nil
        elementWasUpdated = false
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "deficientItemToGallery" {
            if let vc = segue.destination as? GalleryVC {
                vc.readOnly = true
                if let item = Mapper<TemplateItem>().map(JSON: [:]) {
//                    item.photosData = keyDeficientItem?.item.itemPhotosData ?? [:]
                    vc.needToLoadItem = true
                    item.title = keyDeficientItem?.item.itemTitle
                    vc.keyItem = (key: keyDeficientItem?.item.item ?? "", item: item)
                    if let inspection = Mapper<Inspection>().map(JSON: [:]) {
                        vc.keyInspection = (key: keyDeficientItem?.item.inspection ?? "", inspection: inspection)
                    }
                }
            }
        } else if segue.identifier == "deficientItemToDeficientItemGallery" {
            if let vc = segue.destination as? DeficientItemGalleryVC {
                if elementToEdit == nil {
                    vc.readOnly = true
                } else {
                    vc.readOnly = false
                }
                vc.delegate = self
                if let element = elementToEdit, element == .actionComplete {
                    vc.photosData = JSON(keyDeficientItem?.item.completedPhotos ?? [:])
                }
                if let element = elementToView, element == .completedPhotos {
                    vc.photosData = JSON(keyDeficientItem?.item.completedPhotos ?? [:])
                }
                vc.titleText = elementTitleForSegue ?? ""
                vc.keyProperty = keyProperty
                vc.keyDeficientItem = keyDeficientItem
                vc.startDate = keyDeficientItem?.item.currentStartDate
            }
        } else if segue.identifier == "deficientItemToNotes" {
            if let vc = segue.destination as? ItemNotesVC {
                vc.readOnly = true
                if let item = Mapper<TemplateItem>().map(JSON: [:]) {
                    item.title = keyDeficientItem?.item.itemTitle
                    item.inspectorNotes = keyDeficientItem?.item.itemInspectorNotes
                    vc.item = item
                }
            }
        } else if segue.identifier == "deficientItemToTextView" {
            if let vc = segue.destination as? DeficientItemNotesVC {
                vc.delegate = self
                vc.headerText = elementTitleForSegue ?? ""
                vc.text = elementStringValue
                if let element = elementToEdit {
                    vc.readOnly = false
                    vc.element = element
                } else if let element = elementToView {
                    vc.readOnly = true
                    vc.element = element
                }
            }
        } else if segue.identifier == "deficientItemToDatePicker" {
            if let vc = segue.destination as? DeficientItemDatePickerVC {
                vc.delegate = self
                vc.headerText = elementTitleForSegue ?? ""
//                vc.date = elementDateValue
                if let element = elementToEdit {
                    vc.element = element
                    if element == .actionDefer {
                        vc.allowAnyFutureDate = true
                    }
                }
            }
        } else if segue.identifier == "deficientItemToPicker" {
            if let vc = segue.destination as? DeficientItemPickerVC {
                vc.delegate = self
                vc.headerText = elementTitleForSegue ?? ""
                if let element = elementToEdit {
                    vc.element = element
                    switch element {
                    case .currentResponsibilityGroup:
                        vc.pickerValues = ["",
                                           InspectionDeficientItemResponsibilityGroup.siteLevel_InHouse.rawValue,
                                           InspectionDeficientItemResponsibilityGroup.siteLevelManagesVendor.rawValue,
                                           InspectionDeficientItemResponsibilityGroup.corporate.rawValue,
                                           InspectionDeficientItemResponsibilityGroup.corporateManagesVendor.rawValue]
                        vc.pickerTitleValues = ["NOT SET",
                                                InspectionDeficientItem.groupResponibleDescription(group: .siteLevel_InHouse),
                                                InspectionDeficientItem.groupResponibleDescription(group: .siteLevelManagesVendor),
                                                InspectionDeficientItem.groupResponibleDescription(group: .corporate),
                                                InspectionDeficientItem.groupResponibleDescription(group: .corporateManagesVendor)]
                        if let currentGroup = InspectionDeficientItemResponsibilityGroup(rawValue: elementStringValue ?? "") {
                            switch currentGroup {
                            case .siteLevel_InHouse:
                                vc.currentValueIndex = 1
                            case .siteLevelManagesVendor:
                                vc.currentValueIndex = 2
                            case .corporate:
                                vc.currentValueIndex = 3
                            case .corporateManagesVendor:
                                vc.currentValueIndex = 4
                            }
                        }
                        
                    default:
                        print("ERROR: deficientItemToPicker segue - unsupported element")
                    }
                }
                
                
            }
        } else if segue.identifier == "deficientItemToHistory" {
            if let vc = segue.destination as? DeficientItemHistoryVC {
                vc.headerText = elementTitleForSegue ?? ""
                vc.historyJSON = elementJSONValue
                if let element = elementToView {
                    vc.element = element
                }
            }
        }
    }
 
    // MARK: Alerts
    
    func alertForCanceling() {
        let alertController = UIAlertController(title: "Warning!", message: "Changes exist, do you wish to ignore unsaved changes?", preferredStyle: .alert)
        let yesAction = UIAlertAction(title: NSLocalizedString("YES", comment: "Yes action"), style: .default, handler: { [weak self] (action) in
            self?.navigationController?.popViewController(animated: true)
        })
        let noAction = UIAlertAction(title: NSLocalizedString("NO", comment: "No action"), style: .cancel, handler: nil)
        alertController.addAction(yesAction)
        alertController.addAction(noAction)

        present(alertController, animated: true, completion: {})
    }
    
    func alertForSaveValidationError(errorMessage: String) {
        let alertController = UIAlertController(title: "Save Error", message: errorMessage, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: NSLocalizedString("Okay", comment: "Okay action"), style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: {})
    }
    
    func alertForNonCorporateAction() {
        let alertController = UIAlertController(title: "Permission Denied", message: "This action requires a corporate or admin user.", preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: NSLocalizedString("Okay", comment: "Okay action"), style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: {})
    }
    
    func alertForUnsavedUpdates() {
        let alertController = UIAlertController(title: "Unsaved Data", message: "Please UPDATE the Deficient Item first.", preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: NSLocalizedString("Okay", comment: "Okay action"), style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: {})
    }
    
    // MARK: Firebase observers
    
    fileprivate func setObservers() {
        guard let propertyKey = keyProperty?.key ?? propertyKey else {
            print("ERROR: missing propertyKey for observing DI")
            return
        }
        guard let deficientItemKey = keyDeficientItem?.key ?? deficientItemKey else {
            print("ERROR: missing deficientItemKey for observing DI")
            return
        }
        
        deficientItemListener = dbDocumentDeficientItemWith(documentId: deficientItemKey).addSnapshotListener({ [weak self] (documentSnapshot, error) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                if let document = documentSnapshot, document.exists {
                    let updatedKeyDeficientItem: keyInspectionDeficientItem = (document.documentID, Mapper<InspectionDeficientItem>().map(JSONObject: document.data())!)
                    weakSelf.keyDeficientItem = updatedKeyDeficientItem

                    if weakSelf.keyProperty == nil {
                        weakSelf.propertyListener = dbDocumentPropertyWith(documentId: propertyKey).addSnapshotListener({ (documentSnapshot, error) in
                            DispatchQueue.main.async {
                                guard let weakSelf = self else {
                                    return
                                }
                                
                                if let document = documentSnapshot, document.exists {
                                    let updatedProperty: (key: String, property: Property) = (document.documentID, Mapper<Property>().map(JSONObject: document.data())!)
                                    weakSelf.keyProperty = updatedProperty
                                    weakSelf.createLayout()
                                    weakSelf.tableView.reloadData()
                                } else {
                                    SVProgressHUD.showError(withStatus: "Property Not Found")
                                    weakSelf.keyDeficientItem = nil
                                    weakSelf.createLayout()
                                    weakSelf.tableView.reloadData()
                                }
                            }
                        })
                    } else {
                        weakSelf.createLayout()
                        weakSelf.tableView.reloadData()
                    }
                } else {
                    SVProgressHUD.showError(withStatus: "Deficient Item Not Found")
                }
            }
        })
    }

    // MARK: Trello
    
    fileprivate func createTrelloCard() {
        guard let keyProperty = keyProperty else {
            print("ERROR: keyProperty Data is nil")
            return
        }
        
        guard let keyDeficientItem = keyDeficientItem else {
            print("ERROR: keyDeficientItem Data is nil")
            return
        }
        
        guard !deficientItemHasUpdates else {
            alertForUnsavedUpdates()
            return
        }
        
        if let user = currentUser {
            user.getIDToken { [weak self] (token, error) in
                if let token = token {
                    let headers: HTTPHeaders = [
                        "Authorization": "FB-JWT \(token)",
                        "Content-Type": "application/json"
                    ]
                    
                    let parameters: Parameters = [:]
                    
                    presentHUDForConnection()
                    AF.request(createTrelloCardURLString(deficientItemId: keyDeficientItem.key), method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { [weak self] response in
                        debugPrint(response)
                        
                        if let statusCode = response.response?.statusCode, statusCode >= 200 && statusCode < 300 {
                            let alertController = UIAlertController(title: "Trello Card Created", message: nil, preferredStyle: .alert)
                            let okayAction = UIAlertAction(title: "OK", style: .default) { action in
                            }
                            alertController.addAction(okayAction)
                            self?.present(alertController, animated: true, completion: nil)
                            
                            dbDocumentDeficientItemWith(documentId: keyDeficientItem.key).getDocument(completion: { (documentSnapshot, error) in
                                print("Property Inspection DI fetched for notification")
                                if let document = documentSnapshot, document.exists {
                                    if let item = Mapper<InspectionDeficientItem>().map(JSONObject: document.data()) {
                                        let keyUpdatedDeficientItem = (key: document.documentID, item: item)
                                        Notifications.sendPropertyDeficientItemTrelloCardCreation(keyProperty: keyProperty, keyInspectionDeficientItem: keyUpdatedDeficientItem)
                                    }
                                }
                            })
                        } else {
                           let errorMessage = firebaseAPIErrorMessages(data: response.data, error: response.error, statusCode: response.response?.statusCode)
                           let alertController = UIAlertController(title: "Error Creating Trello Card", message: errorMessage, preferredStyle: .alert)
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
}
