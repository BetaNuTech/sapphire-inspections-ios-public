//
//  InspectionVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 8/5/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import SideMenuController
import TPPDF
import AWSS3
import FirebaseFirestore
import Alamofire
import SwiftyJSON

var showInspectionIncompletes = false

class InspectionVC: UIViewController, UITableViewDataSource, UITableViewDelegate, InspectionItemTVCellDelegate, InspectionItemTextInputTVCellDelegate, ItemNotesVCDelegate, GalleryVCDelegate, SignatureVCDelegate {
    
    @IBOutlet weak var navItem: UINavigationItem!
    @IBOutlet var saveButton: UIBarButtonItem!
    @IBOutlet var editButton: UIBarButtonItem!
    @IBOutlet var playButton: UIBarButtonItem!
    @IBOutlet var pauseButton: UIBarButtonItem!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var tableTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var infoBannerLabel: UILabel!
    
    // For migration only
    var migrateMode = false
    
    // Input
    var readOnly = true
    var adminCorporateUser = false
    
    var adminEditMode = false
    
    var propertyListener: ListenerRegistration?
    var inspectionListener: ListenerRegistration?

    // Input
    var keyProperty: (key: String, property: Property)?
    var keyTemplate: (key: String, template: Template)?
    var keyInspection: (key: String, inspection: Inspection)?
    
    // Input, for URI open only
    var propertyKey: String?
    var inspectionKey: String?
    
    var keySectionsWithKeyItems: KeySectionsWithKeyItems = []
    
    var itemForMainInputNotesToEdit: TemplateItem?
    var itemForInspectorNotesToEdit: TemplateItem?
    var keyItemForPhotosToEdit: (key: String, item: TemplateItem)?
    
    var collapsedSections: [String] = [] // Section IDs
    
    var isLoading = false
    var hasChanges = false
//    var isSaveRequired = false
    var hasSavedOffline = false
    
    var askedToPausedUploading = false
    
    // Info Banner
    var infoBannerVisible = false
    var inspectionReportStatusLast = ""
    
    var waitingOnInspectionReportCompletion = false
    
    @IBOutlet weak var shareButton: UIBarButtonItem!
    
    class func isItemCompleted(item: TemplateItem) -> Bool {
        let type = item.templateItemType()
        if item.isItemNA {
            return true
        } else if type == .textInput {
            let title = item.title ?? ""
            if item.textInputValue != "" ||
                title.lowercased().hasPrefix("if no") ||   // Optional text entry
                title.lowercased().hasPrefix("if yes") {  // Optional text entry
                return true
            }
        } else if item.mainInputSelected {
            return !item.requiredNoteAndPhotoIncomplete
        } else if type == .signature {
            return item.signatureTimestampKey != ""
        }
        
        return false
    }
    
    class func updateTableViewCellForItemCompleteness(cell: UITableViewCell, item: TemplateItem) {
        if !showInspectionIncompletes || InspectionVC.isItemCompleted(item: item) {
            cell.backgroundColor = UIColor.white
        } else {
            cell.backgroundColor = GlobalColors.incompleteItemColor
        }
    }
    
    deinit {
        deinitialize()
    }
    
    func deinitialize() {
        keyProperty = nil
        keyInspection = nil
        keyTemplate = nil
        
        if let listener = propertyListener {
            listener.remove()
        }
        if let listener = inspectionListener {
            listener.remove()
        }
        
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        showInspectionIncompletes = false
        
        isLoading = true

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(InspectionVC.keyboardWillShow(_:)),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(InspectionVC.keyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(InspectionVC.autoSaveInspection(_:)),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(InspectionVC.updateUI(_:)),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        

        
        // Defaults
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 84.0
        tableView.sectionFooterHeight = 0.0
        tableView.isEditing = false
        var nib = UINib(nibName: "InspectionSectionHeaderView", bundle: nil)
        tableView.register(nib, forHeaderFooterViewReuseIdentifier: "InspectionSectionHeaderView")
        nib = UINib(nibName: "InspectionMultiSectionHeaderView", bundle: nil)
        tableView.register(nib, forHeaderFooterViewReuseIdentifier: "InspectionMultiSectionHeaderView")
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0.0
        } else {
            // Fallback on earlier versions
        }
        //tableView.estimatedSectionHeaderHeight = 27  // Having this causes a Apple bug to appear on reloadRows

        
        if !migrateMode {
            removeSaveButton() // Now re-appears if hasChanges, and !readOnly
        }
        
        updateOnlineButton()
        
        updateButtons(askToPause: false)
        
        // Is Inspection generating a report?
        // 1 NEW (Not saved)
        // - NA
        // 2 NEW (Saved)
        // - (Start) Monitoring for Report Generation
        // - Block user if present
        // 3 Existing
        // - (Start) Monitoring for Report Generation
        // - Block user if present
        
        // Report Generation Options (when completed)
        // 1 - Block user from saving
        // 2 - Show banner that shows report being generated.
        // 3 - "NEW Report available" clickable
        
        // Another user opens and saves inspection at same time?
        // - Right now, the inspection is reloaded automatically, unless a new inspection (overwrites any other saves this way)
        
        // New inspection, with template data, create inspection key and data from template
        if let keyTemplate = keyTemplate, let keyProperty = keyProperty, keyInspection == nil {
            SVProgressHUD.show()
            Inspection.newKeyAndInspectionFromTemplate(keyTemplate, propertyKey: keyProperty.key, completion: { [weak self] (key, inspection) in
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        SVProgressHUD.dismiss()
                        return
                    }
                    weakSelf.keyInspection = (key, inspection)
                    Template.keySectionsWithKeyItems(keyTemplate.template, completion: { (keySectionWithKeyItems) in
                        weakSelf.keySectionsWithKeyItems = keySectionWithKeyItems
                        weakSelf.tableView.reloadData()
                        SVProgressHUD.dismiss()
                        weakSelf.isLoading = false
                        weakSelf.updateButtons(askToPause: true)
                    })
                }
            })
        // Inspection data exists, add listener to inspection and load inspection
        } else if let key = keyInspection?.key {
            SVProgressHUD.show()
            showInspectionIncompletes = true
            
            // Load Inspection
            inspectionListener = dbDocumentInspectionWith(documentId: key).addSnapshotListener({ [weak self] (documentSnapshot, error) in
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        return
                    }
                    
                    if let document = documentSnapshot, document.exists {
                        weakSelf.keyInspection = (key, Mapper<Inspection>().map(JSONObject: document.data())!)
                        weakSelf.loadInspection()
                    } else {
                        SVProgressHUD.showError(withStatus: "Inspection Not Found")
                        weakSelf.isLoading = false
                    }
                }
            })
        // If only the inspection key and property key (loaded from link), load/listen-to inspection and property
        } else if let inspectionKey = inspectionKey, let propertyKey = propertyKey {
            SVProgressHUD.show()
            showInspectionIncompletes = true
            
            // Load Inspection
            inspectionListener = dbDocumentInspectionWith(documentId: inspectionKey).addSnapshotListener({ [weak self] (documentSnapshot, error) in
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        return
                    }
                    
                    if let document = documentSnapshot, document.exists {
                        print("Inspection loaded")
                        let keyInspection = (key: inspectionKey, inspection: Mapper<Inspection>().map(JSONObject: document.data())!)

                        if let property = keyInspection.inspection.property, property == propertyKey, weakSelf.keyProperty == nil {
                            weakSelf.propertyListener = dbDocumentPropertyWith(documentId: propertyKey).addSnapshotListener({ (documentSnapshot, error) in
                                DispatchQueue.main.async {
                                    guard let weakSelf = self else {
                                        return
                                    }
                                    
                                    if let document = documentSnapshot, document.exists {
                                        print("Property loaded")
                                        let updatedProperty: (key: String, property: Property) = (document.documentID, Mapper<Property>().map(JSONObject: document.data())!)
                                        weakSelf.keyProperty = updatedProperty
                                        
                                        // If inspection not loaded yet, load inspection
                                        if weakSelf.keyInspection == nil {
                                            weakSelf.keyInspection = keyInspection
                                            weakSelf.loadInspection()
                                        }
                                    } else {
                                        SVProgressHUD.showError(withStatus: "Property Not Found")
                                        weakSelf.isLoading = false
                                    }
                                }
                            })
                        // If Property already loaded, update and load inspection
                        } else if weakSelf.keyProperty != nil {
                            weakSelf.keyInspection = keyInspection
                            weakSelf.loadInspection()
                        } else {
                            SVProgressHUD.showError(withStatus: "Property Invalid from URI")
                            weakSelf.isLoading = false
                        }
                    } else {
                        SVProgressHUD.showError(withStatus: "Inspection Not Found")
                        weakSelf.isLoading = false
                    }
                }
            })
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        print("inspectionVC - viewWillAppear")
        
        // Update UI
        tableView.reloadData()
        updateInfoBanner()
                
        SideMenuController.preferences.interaction.swipingEnabled = false
        
        if hasChanges {
            if updateKeyInspection(showHUD: true, dismiss: false) {
                print("inspectionVC - inspection saved")
            }
        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        print("inspectionVC - viewWillDisappear")

//        if !readOnly && !isLoading {
//            updateKeyInspection(dismiss: false)
//        }
    }
    
    func updateButtons(askToPause: Bool) {
        if readOnly {
            if !adminCorporateUser {
                removeEditButton()
            } else {
                addEditButton()
            }
        } else {
            removeEditButton()
        }
        
        if askToPause && !readOnly && !askedToPausedUploading {
            alertAskToPausedUploading()
            askedToPausedUploading = true
        }
    }
    
    // Load Inspection
    func loadInspection() {
        guard let keyInspection = keyInspection else {
            print("ERROR: Missing inspection data")
            SVProgressHUD.dismiss()
            return
        }
        
        // Update user permissions
        if let currentUser = currentUser {
            if keyInspection.inspection.inspector == currentUser.uid && !keyInspection.inspection.inspectionCompleted {
                readOnly = false
            } else if let profile = currentUserProfile, !profile.isDisabled {
                adminCorporateUser = profile.admin || profile.corporate
            }
        }
        
        updateButtons(askToPause: true)
        
        // Check PDF Report generation status
        updateInfoBanner()
        
        if let templateDict = keyInspection.inspection.template, let template = Template(JSON: templateDict) {
            keyTemplate = (key: "", template: template)
            
            Template.keySectionsWithKeyItems(keyTemplate!.template, completion: { [weak self] (keySectionWithKeyItems) in
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        SVProgressHUD.dismiss()
                        return
                    }
                    
                    weakSelf.keySectionsWithKeyItems = keySectionWithKeyItems
                    weakSelf.tableView.reloadData()
                    SVProgressHUD.dismiss()
                    weakSelf.isLoading = false
                }
            })
        }
    }
    
    func updateInfoBanner() {
        guard let keyInspection = keyInspection else {
            return
        }
        // Check PDF Report generation status
        if let status = keyInspection.inspection.inspectionReportStatus {
            var pdfNeedsRegen = false
            if let inspectionReportUpdateLastDate = keyInspection.inspection.inspectionReportUpdateLastDate, let updatedLastDate = keyInspection.inspection.updatedLastDate {
                pdfNeedsRegen = updatedLastDate.timeIntervalSince1970 > inspectionReportUpdateLastDate.timeIntervalSince1970
            }
            switch (inspectionReportStatusLast, status) {
                case (_, "queued"):
                    inspectionReportStatusLast = status
                    showInfoBanner(text: "PDF Report is being generated", flash: true)
                case (_, "generating"):
                    inspectionReportStatusLast = status
                    showInfoBanner(text: "PDF Report is being generated", flash: true)
                case ("", "completed_success"):
                    inspectionReportStatusLast = status
                    if pdfNeedsRegen {
                        showInfoBanner(text: "PDF Report is out-of-date", flash: false)
                    } else {
                        showInfoBanner(text: "PDF Report is available", flash: false)
                    }
                case ("generating", "completed_success"):
                    inspectionReportStatusLast = status
                    showInfoBanner(text: "NEW PDF Report is ready", flash: false)
                case ("generating", "completed_failure"):
                    inspectionReportStatusLast = status
                    showInfoBanner(text: "PDF Report generation failed", flash: false)
                case (_, "completed_success"):
                    if pdfNeedsRegen {
                        showInfoBanner(text: "PDF Report is out-of-date", flash: false)
                    }
                    inspectionReportStatusLast = status
                default:
                    inspectionReportStatusLast = status
            }
        }
    }
    
    // MARK: Buttons
    
    func addSaveButton() {
        guard var leftBarButtonItems = navItem?.leftBarButtonItems else {
            return
        }
        
        if !leftBarButtonItems.contains(saveButton) {
            leftBarButtonItems.append(saveButton)
            navItem?.leftBarButtonItems = leftBarButtonItems
        }
    }
    
    func removeSaveButton() {
        guard var leftBarButtonItems = navItem?.leftBarButtonItems else {
            return
        }
        
        if let index = leftBarButtonItems.index(of: saveButton) {
            leftBarButtonItems.remove(at: index)
            navItem?.leftBarButtonItems = leftBarButtonItems
        }
    }
    
    func addEditButton() {
        guard var rightBarButtonItems = navItem?.rightBarButtonItems else {
            return
        }
        
        if !rightBarButtonItems.contains(editButton) {
            rightBarButtonItems.append(editButton)
            navItem?.rightBarButtonItems = rightBarButtonItems
        }
    }
    
    func removeEditButton() {
        guard var rightBarButtonItems = navItem?.rightBarButtonItems else {
            return
        }
        
        if let index = rightBarButtonItems.index(of: editButton) {
            rightBarButtonItems.remove(at: index)
            navItem?.rightBarButtonItems = rightBarButtonItems
        }
    }
    
    func addPlayButton() {
        guard var rightBarButtonItems = navItem?.rightBarButtonItems else {
            return
        }
        
        if !rightBarButtonItems.contains(playButton) {
            rightBarButtonItems.append(playButton)
            navItem?.rightBarButtonItems = rightBarButtonItems
        }
    }
    
    func removePlayButton() {
        guard var rightBarButtonItems = navItem?.rightBarButtonItems else {
            return
        }
        
        if let index = rightBarButtonItems.index(of: playButton) {
            rightBarButtonItems.remove(at: index)
            navItem?.rightBarButtonItems = rightBarButtonItems
        }
    }
    
    func addPauseButton() {
        guard var rightBarButtonItems = navItem?.rightBarButtonItems else {
            return
        }
        
        if !rightBarButtonItems.contains(pauseButton) {
            rightBarButtonItems.append(pauseButton)
            navItem?.rightBarButtonItems = rightBarButtonItems
        }
    }
    
    func removePauseButton() {
        guard var rightBarButtonItems = navItem?.rightBarButtonItems else {
            return
        }
        
        if let index = rightBarButtonItems.index(of: pauseButton) {
            rightBarButtonItems.remove(at: index)
            navItem?.rightBarButtonItems = rightBarButtonItems
        }
    }
    
    func updateOnlineButton() {
        if !pauseUploadingPhotos {
            removePlayButton()
            addPauseButton()
        } else {
            addPlayButton()
            removePauseButton()
        }
        
        if readOnly {
            removePlayButton()
            removePauseButton()
        }
    }

    
    // MARK: Button Actions
    
    @IBAction func saveButtonTapped(_ sender: Any) {
        if (!isLoading && !readOnly) || migrateMode {
            if updateKeyInspection(showHUD: true, dismiss: false) {
                print("inspectionVC - inspection saved")
            }
        } else if readOnly {  // We shouldn't be showing the save button, in this case, but a fail safe
            if let nav = self.navigationController {
                nav.popViewController(animated: true)
                deinitialize()
            }
        }
    }

    @IBAction func editButtonTapped(_ sender: Any) {
        removeEditButton()
        addPlayButton()
        readOnly = false
        adminEditMode = true
        tableView.reloadData()
    }
    
    @IBAction func onlineButtonTapped(_ sender: UIBarButtonItem) {
        // Inspection must be saved before unpausing photos
        if pauseUploadingPhotos && hasChanges {
            let alertController = UIAlertController(title: "Save Recommended", message: "Please save inspection before unpausing photo uploads.", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default) { action in
            }
            alertController.addAction(okAction)
            self.present(alertController, animated: true) {}
            return
        }
        
        pauseUploadingPhotos = !pauseUploadingPhotos
        
        if !pauseUploadingPhotos && FIRConnection.connected() {
            LocalInspectionImages.singleton.startSyncing()
            LocalDeficientImages.singleton.startSyncing()
        }
        
        updateOnlineButton()
        
        if pauseUploadingPhotos {
            alertForPausedUploading()
        }
    }
    
    
//    @IBAction func saveButtonTapped(sender: AnyObject) {
//        updateKeyInspection()
//    }
    
    // MARK: UITableView DataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return keySectionsWithKeyItems.count
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if keySectionsWithKeyItems[section].section.sectionType == TemplateSectionType.multi.rawValue && !readOnly {
            // Dequeue with the reuse identifier
            if let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "InspectionMultiSectionHeaderView") as? InspectionSectionHeaderView {
                header.sectionLabel.text = keySectionsWithKeyItems[section].section.title
                let sectionCanBeRemoved = keySectionsWithKeyItems[section].section.addedMultiSection
                
                header.addButton.isEnabled = !readOnly
                
                // Enabled/Disable Remove Button
                header.removeButton.isEnabled = sectionCanBeRemoved && !readOnly
                header.removeButton.alpha = sectionCanBeRemoved ? 1.0 : 0.0
                
                // Set target for buttons
                header.sectionIndex = section
                header.addButton.addTarget(self, action: #selector(InspectionVC.hitSectionAdd(button:)), for: .touchUpInside)
                header.removeButton.addTarget(self, action: #selector(InspectionVC.hitSectionRemove(button:)), for: .touchUpInside)
                header.collapseButton.addTarget(self, action: #selector(InspectionVC.hitSectionCollapse(button:)), for: .touchUpInside)
                
                header.singleMultiTypeImageView.image = UIImage(named: "multi_white")
                
                let sectionId = keySectionsWithKeyItems[section].key
                if collapsedSections.contains(sectionId) {
                    header.singleMultiTypeImageView.image = UIImage(named: "up_arrow")
                    
                }
                
                return header
            }
        } else {
            // Dequeue with the reuse identifier
            if let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "InspectionSectionHeaderView") as? InspectionSectionHeaderView {
                header.sectionLabel.text = keySectionsWithKeyItems[section].section.title
                
                if keySectionsWithKeyItems[section].section.sectionType == TemplateSectionType.multi.rawValue {
                    header.singleMultiTypeImageView.image = UIImage(named: "multi_white")
                } else {
                    header.singleMultiTypeImageView.image = UIImage(named: "single_white")
                }
                
                header.sectionIndex = section
                header.collapseButton.addTarget(self, action: #selector(InspectionVC.hitSectionCollapse(button:)), for: .touchUpInside)
                
                let sectionId = keySectionsWithKeyItems[section].key
                if collapsedSections.contains(sectionId) {
                    header.singleMultiTypeImageView.image = UIImage(named: "up_arrow")
                }
                
                return header
            }
        }
        
        return nil
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if keySectionsWithKeyItems[section].section.sectionType == TemplateSectionType.multi.rawValue && !readOnly {
            if let sectionLabel = keySectionsWithKeyItems[section].section.title, let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "InspectionMultiSectionHeaderView") as? InspectionSectionHeaderView {
                let labelHeight = sectionLabel.heightWithConstrainedWidth(width: tableView.frame.size.width - InspectionSectionHeaderView.leftMargin - InspectionSectionHeaderView.rightMargin, font: header.sectionLabel.font)
                return max(InspectionSectionHeaderView.topMargin + labelHeight + InspectionSectionHeaderView.bottomMargin, InspectionSectionHeaderView.minHeight) + InspectionSectionHeaderView.heightMarginForButtons
            }
            return InspectionSectionHeaderView.minHeight + InspectionSectionHeaderView.heightMarginForButtons
        } else {
            if let sectionLabel = keySectionsWithKeyItems[section].section.title, let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "InspectionSectionHeaderView") as? InspectionSectionHeaderView {
                let labelHeight = sectionLabel.heightWithConstrainedWidth(width: tableView.frame.size.width - InspectionSectionHeaderView.leftMargin - InspectionSectionHeaderView.rightMargin, font: header.sectionLabel.font)
                return max(InspectionSectionHeaderView.topMargin + labelHeight + InspectionSectionHeaderView.bottomMargin, InspectionSectionHeaderView.minHeight)
            }
            return InspectionSectionHeaderView.minHeight
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionId = keySectionsWithKeyItems[section].key
        if collapsedSections.contains(sectionId) {
            return 0
        }
    
        return keySectionsWithKeyItems[section].keyItems.count
    }
    
//    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
//        return keySectionsWithKeyItems[section].section.title
//    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        print("cellForRowAt: section = \(indexPath.section), row = \(indexPath.row)")
        let keyItem = keySectionsWithKeyItems[(indexPath as NSIndexPath).section].keyItems[(indexPath as NSIndexPath).row]
        let item = keyItem.item
        
        let type = item.templateItemType()
        switch type {
        case .main:
            let cell = tableView.dequeueReusableCell(withIdentifier: "inspectionItemCell") as! InspectionItemTVCell
            cell.item = item
            cell.delegate = self
            cell.itemName.text = item.title ?? ""
            
            if let mainInputType = item.mainInputType, let mainInputTypeEnum = TemplateItemActions(rawValue: mainInputType.lowercased()) {
                item.mainInputType = mainInputTypeEnum.rawValue // update value
            } else {
                item.mainInputType = defaultTemplateItemActions.rawValue // update value
            }
            
            cell.readOnly = readOnly
            
            if let keyTemplate = keyTemplate, keyTemplate.template.requireDeficientItemNoteAndPhoto {
                cell.requireDeficientItemNoteAndPhoto = true
            } else {
                cell.requireDeficientItemNoteAndPhoto = false
            }
            
            cell.configureIcons()
            cell.configureUIForMainInputSelection()
            cell.configureButtons()
            
            cell.viewNA.isHidden = !item.isItemNA
            
            InspectionVC.updateTableViewCellForItemCompleteness(cell: cell, item: item)
            
            return cell
        case .textInput:
            let cell = tableView.dequeueReusableCell(withIdentifier: "inspectionItemTextInputCell") as! InspectionItemTextInputTVCell
            cell.delegate = self
            cell.item = item
            cell.itemName.text = item.title ?? ""
            cell.itemTextInputField.text = item.textInputValue
            cell.itemTextInputField.delegate = cell
            
            cell.itemTextInputField.isUserInteractionEnabled = !readOnly
            
            cell.viewNA.isHidden = !item.isItemNA
            
            InspectionVC.updateTableViewCellForItemCompleteness(cell: cell, item: item)
            
            return cell
        case .signature:
            let cell = tableView.dequeueReusableCell(withIdentifier: "inspectionItemSignatureCell") as! InspectionItemSignatureTVCell
            cell.item = item
            
            let keyItem = keySectionsWithKeyItems[(indexPath as NSIndexPath).section].keyItems[(indexPath as NSIndexPath).row]
            cell.signatureTapAction = { [weak self] in
                print("signature tapped")
                self?.keyItemForPhotosToEdit = keyItem
                self?.performSegue(withIdentifier: "openSignature", sender: nil)
            }
            
            if item.signatureTimestampKey != "" {
                if item.signatureDownloadURL == "" {
                    if let localImage = LocalInspectionImages.localInspectionItemImage(inspectionKey: keyInspection!.key, itemKey: keyItem.key, key: item.signatureTimestampKey) {
                        print("Loaded offline photo with key=\(item.signatureTimestampKey)")
                        cell.signatureImageView.image = UIImage(data: localImage.imageData!)
                    } else {
                        cell.signatureImageView.image = nil
                    }
                } else {
                    let signatureURL = URL(string: item.signatureDownloadURL)
                    let downloader = SDWebImageDownloader.shared
                    downloader.downloadImage(with: signatureURL, options: .highPriority, progress: { (receivedSize, expectedSize, targetURL) in
                    }, completed: { (image, data, error, finished) in
                        if let image = image , finished {
                            if let cellItem = cell.item, cellItem.signatureTimestampKey == item.signatureTimestampKey {
                                cell.signatureImageView.image = image
                            }
                        }
                    })
                }
            } else {
                cell.signatureImageView.image = nil
            }
            
            cell.viewNA.isHidden = !item.isItemNA
            
            InspectionVC.updateTableViewCellForItemCompleteness(cell: cell, item: item)
            
            return cell
        case .unsupported:
            let cell = UITableViewCell()
            cell.textLabel?.text = "Unsupported (Update App)"
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        print("editActionsForRowAt: section = \(indexPath.section), row = \(indexPath.row)")
        let item = keySectionsWithKeyItems[indexPath.section].keyItems[indexPath.row].item
        let title = item.isItemNA ? "ADD" : "NA"
        let toggleNAAction = UITableViewRowAction(style: .normal, title: title) { [weak self] action, index in
            if let item = self?.keySectionsWithKeyItems[indexPath.section].keyItems[indexPath.row].item {
                item.isItemNA = !item.isItemNA
                if item.isItemNA {
                    self?.recordAction(item: item, action: "set item to NA")
                } else {
                    self?.recordAction(item: item, action: "added item back from being set NA")
                }
                self?.tableView.reloadRows(at: [indexPath], with: .automatic)
            }
        }
        toggleNAAction.backgroundColor = GlobalColors.blue
        
        return [toggleNAAction]
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !readOnly
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    }
    
    // MARK: - InspectionItemTVCell Delegate
    
    func inspectionItemTVCellUpdated(cell: InspectionItemTVCell, action: String) {
        guard let item = cell.item else {
            print("ERROR: item is nil for inspectionItemTVCellUpdated")
            return
        }
        
        recordAction(item: item, action: action)
        
//        if let indexPath = tableView.indexPath(for: inspectionItemTVCell) {
//            tableView.reloadRows(at: [indexPath], with: .automatic)
//        }
    }
    
    func inspectionItemTVCellOpenMainInputNotes(_ inspectionItemTVCell: InspectionItemTVCell) {
        if let indexPath = tableView.indexPath(for: inspectionItemTVCell) {
            let item = keySectionsWithKeyItems[(indexPath as NSIndexPath).section].keyItems[(indexPath as NSIndexPath).row].item
            itemForMainInputNotesToEdit = item
            performSegue(withIdentifier: "openMainInputNotes", sender: nil)
        }
    }

    func inspectionItemTVCellOpenInspectorNotes(_ inspectionItemTVCell: InspectionItemTVCell) {
        if let indexPath = tableView.indexPath(for: inspectionItemTVCell) {
            let item = keySectionsWithKeyItems[(indexPath as NSIndexPath).section].keyItems[(indexPath as NSIndexPath).row].item
            itemForInspectorNotesToEdit = item
            performSegue(withIdentifier: "openMainInputNotes", sender: nil)
        }
    }
    
    func inspectionItemTVCellOpenGallery(_ inspectionItemTVCell: InspectionItemTVCell) {
        if let indexPath = tableView.indexPath(for: inspectionItemTVCell) {
            let keyItem = keySectionsWithKeyItems[(indexPath as NSIndexPath).section].keyItems[(indexPath as NSIndexPath).row]
            keyItemForPhotosToEdit = keyItem
            performSegue(withIdentifier: "gallery", sender: nil)
        }
    }
    
    // MARK: - InspectionItemTextInputTVCell Delegate

    func inspectionItemTextInputTVCellUpdated(cell: InspectionItemTextInputTVCell, action: String) {
        guard let item = cell.item else {
            print("ERROR: item is nil for InspectionItemTextInputTVCell")
            return
        }
        
        recordAction(item: item, action: action)

        //        if let indexPath = tableView.indexPath(for: inspectionItemTVCell) {
        //            tableView.reloadRows(at: [indexPath], with: .automatic)
        //        }
    }
    
    // MARK: - ItemNotesVC Delegate

    func itemNotesUpdated(item: TemplateItem, action: String) {
        recordAction(item: item, action: action)
        
        if let keyTemplate = keyTemplate, keyTemplate.template.requireDeficientItemNoteAndPhoto {
            item.updateRequiredNoteAndPhotoIncomplete(isRequired: true)
        }
    }
    
    // MARK: - GalleryVC Delegate
    
    func galleryUpdated(item: TemplateItem, action: String, binaryUpdate: Bool) {
        recordAction(item: item, action: action)
        
        if let keyTemplate = keyTemplate, keyTemplate.template.requireDeficientItemNoteAndPhoto {
            item.updateRequiredNoteAndPhotoIncomplete(isRequired: true)
        }
        
//        if binaryUpdate {
//            isSaveRequired = true
//        }
    }
    
    // MARK: - SignatureVC Delegate
    
    func signatureUpdated(item: TemplateItem, action: String, binaryUpdate: Bool) {
        recordAction(item: item, action: action)
        
//        if binaryUpdate {
//            isSaveRequired = true
//        }
    }
    
    // MARK: - UITableView Delegates
    
//    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
//        let templateItem = keySectionsWithKeyItems[indexPath.section].keyItems[indexPath.row].item
//        // TODO: do something with this
//    }
//    
//    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
//        return (indexPath.row < keySectionsWithKeyItems[indexPath.section].keyItems.count)
//    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
     
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let backItem = UIBarButtonItem()
        backItem.title = ""
        navigationItem.backBarButtonItem = backItem // This will show in the next view controller being pushed
        
        if segue.identifier == "openMainInputNotes" {
            if let vc = segue.destination as? ItemNotesVC {
                vc.readOnly = readOnly
                if itemForMainInputNotesToEdit != nil {
                    vc.item = itemForMainInputNotesToEdit
                    vc.mainInput = true
                } else {
                    vc.item = itemForInspectorNotesToEdit
                    vc.mainInput = false
                }
                vc.delegate = self
                
                itemForMainInputNotesToEdit = nil
                itemForInspectorNotesToEdit = nil
            }
        } else if segue.identifier == "gallery" {
            if let vc = segue.destination as? GalleryVC {
                vc.keyItem = keyItemForPhotosToEdit
                vc.keyInspection = keyInspection
                vc.readOnly = readOnly
                vc.delegate = self
                
                keyItemForPhotosToEdit = nil
            }
        } else if segue.identifier == "openSignature" {
            if let vc = segue.destination as? SignatureVC {
                vc.keyItem = keyItemForPhotosToEdit
                vc.keyInspection = keyInspection
                vc.readOnly = readOnly
                vc.delegate = self
                
                keyItemForPhotosToEdit = nil
            }
        }
    }
    
    func updateKeyInspection(showHUD: Bool = false, dismiss: Bool = false, ignoreCompleteStatusOnSave: Bool = false) -> Bool {
        guard let keyTemplate = keyTemplate, let keyInspection = keyInspection else {
            print("ERROR: missing keyTemplate and/or keyInspection")
            return false
        }
        
        guard waitingOnInspectionReportCompletion == false else {
            return false
        }
        
        if (showHUD || dismiss) && FIRConnection.connected() {
            SVProgressHUD.show(withStatus: "Saving")
        }

        removeSaveButton()
        hasChanges = false

        var updatedSections: [String: AnyObject] = [:]
        var updatedItems: [String: AnyObject] = [:]
        var completedItems = 0
        var totalPossiblePoints = 0
        var totalCompletedPoints = 0
        var deficienciesExist = false
        for keySectionWithItems in keySectionsWithKeyItems  {
            updatedSections[keySectionWithItems.key] = keySectionWithItems.section.toJSON() as AnyObject?
            for keyItem in keySectionWithItems.keyItems {
                let syncedImages = LocalInspectionImages.localInspectionItemImagesSynced(inspectionKey: keyInspection.key, itemKey: keyItem.key)
                for syncedImage in syncedImages {
                    if syncedImage.isSignature {
                        keyItem.item.signatureDownloadURL = syncedImage.downloadURL
                    } else {
                        let photoData: [String : AnyObject] = ["downloadURL" : syncedImage.downloadURL as AnyObject, "caption" : syncedImage.caption as AnyObject]
                        keyItem.item.photosData[syncedImage.key] = photoData as AnyObject
                    }
                }
                let syncedImagesDeleted = LocalInspectionImages.localInspectionItemImagesDeletedSynced(inspectionKey: keyInspection.key, itemKey: keyItem.key)
                for syncedImageDeleted in syncedImagesDeleted {
                    keyItem.item.photosData.removeValue(forKey: syncedImageDeleted.key)
                }
                
                updatedItems[keyItem.key] = keyItem.item.toJSON() as AnyObject?
                
                if InspectionVC.isItemCompleted(item: keyItem.item) {
                    completedItems += 1
                }
                
                let type = keyItem.item.templateItemType()
                
                if keyItem.item.mainInputSelected && type == .main && !keyItem.item.isItemNA {
                    if let mainInputSelection = keyItem.item.mainInputSelection {
                        switch mainInputSelection {
                        case 0:
                            totalCompletedPoints += keyItem.item.mainInputZeroValue ?? 0
                        case 1:
                            totalCompletedPoints += keyItem.item.mainInputOneValue ?? 0
                        case 2:
                            totalCompletedPoints += keyItem.item.mainInputTwoValue ?? 0
                        case 3:
                            totalCompletedPoints += keyItem.item.mainInputThreeValue ?? 0
                        case 4:
                            totalCompletedPoints += keyItem.item.mainInputFourValue ?? 0
                        default:
                            print("UNEXPECTED: Main Input outside range")
                        }
                    }

                    var highestValue = max(keyItem.item.mainInputZeroValue ?? 0, keyItem.item.mainInputOneValue ?? 0)
                    highestValue = max(highestValue, keyItem.item.mainInputTwoValue ?? 0)
                    highestValue = max(highestValue, keyItem.item.mainInputThreeValue ?? 0)
                    highestValue = max(highestValue, keyItem.item.mainInputFourValue ?? 0)
                    totalPossiblePoints += highestValue
                    
                    if let deficient = keyItem.item.deficient , deficient {
                        deficienciesExist = true
                    }
                }
            }
        }
        
        LocalInspectionImages.removeSyncedImages()

        keyTemplate.template.sections = updatedSections
        keyTemplate.template.items = updatedItems
        keyInspection.inspection.templateId = keyTemplate.key
        keyInspection.inspection.template = keyTemplate.template.toJSON() as [String : AnyObject]?
        
        // Update inspection details
        keyInspection.inspection.totalItems = updatedItems.values.count
        keyInspection.inspection.itemsCompleted = completedItems
        
        var sendCompletedNotification = false
        if keyInspection.inspection.totalItems == keyInspection.inspection.itemsCompleted {
            if !keyInspection.inspection.inspectionCompleted {
                sendCompletedNotification = true
                let property_code = keyProperty?.property.code ?? "unknown"
                let template_name = keyTemplate.template.name ?? "unknown"
                Analytics.logEvent("inspection_completed", parameters: ["property_code": property_code, "template_name": template_name])
            }
            keyInspection.inspection.inspectionCompleted = true
        } else {
            keyInspection.inspection.inspectionCompleted = false
        }
        
        if totalPossiblePoints > 0 && keyInspection.inspection.inspectionCompleted {
            keyInspection.inspection.score = (Double(totalCompletedPoints) / Double(totalPossiblePoints)) * 100.0
            if keyInspection.inspection.completionDate == nil {
                keyInspection.inspection.completionDate = Date() // On first completed update, set completion date
            }
        } else {
            keyInspection.inspection.score = 0
        }
        keyInspection.inspection.deficienciesExist = deficienciesExist
        
        if !migrateMode {
            keyInspection.inspection.updatedLastDate = Date()
            keyInspection.inspection.updatedAt = Date()
        } else {
            keyInspection.inspection.migrationDate = Date()
        }
        
        if let template = keyInspection.inspection.template, let name = template["name"] as? String {
            keyInspection.inspection.templateName = name
        }
        
        let json = keyInspection.inspection.toJSON()
        print("json = \(json)")
        
        let propertyName = self.keyProperty?.property.name ?? "Property"
        let isConnected = FIRConnection.connected()  // Capture connectivity status here, before closure
        dbDocumentInspectionWith(documentId: keyInspection.key).setData(json, merge: true) { [weak self] (error) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                if (showHUD || dismiss) && isConnected {
                    if error != nil {
                        SVProgressHUD.dismiss()
                        weakSelf.showMessagePrompt("Error occurred when saving inspection details")
                    } else {
                        print("Inspection \(keyInspection.key) saved for Property: \(weakSelf.keyProperty?.key ?? "")")
                        SVProgressHUD.dismiss()
                        //SVProgressHUD.showSuccess(withStatus: "Inspection for \(propertyName) Saved & Uploaded")
                        if let nav = weakSelf.navigationController, dismiss {
                            nav.popViewController(animated: true)
                            self?.deinitialize()
                        }
                        if sendCompletedNotification {
                            if let keyProperty = self?.keyProperty {
                                Notifications.sendPropertyInspectionCompleted(keyProperty: keyProperty, keyInspection: keyInspection)
                            }
                        }
                    }
                } else if dismiss {
                    if error != nil {
                        SVProgressHUD.dismiss()
                        weakSelf.showMessagePrompt("Error occurred when saving inspection details")
                    } else {
                        print("Inspection \(keyInspection.key) saved for Property: \(weakSelf.keyProperty?.key ?? "")")
                        SVProgressHUD.showSuccess(withStatus: "Saved Inspection for \(propertyName) Uploaded")
                        if let keyProperty = self?.keyProperty {
                            Notifications.sendPropertyInspectionCompleted(keyProperty: keyProperty, keyInspection: keyInspection)
                        }
                    }
                }
                
                if weakSelf.inspectionListener == nil {
                    weakSelf.inspectionListener = dbDocumentInspectionWith(documentId: keyInspection.key).addSnapshotListener({ [weak self] (documentSnapshot, error) in
                        DispatchQueue.main.async {
                            guard let weakSelf = self else {
                                return
                            }
                            
                            if let document = documentSnapshot, document.exists {
                                weakSelf.keyInspection = (keyInspection.key, Mapper<Inspection>().map(JSONObject: document.data())!)
                                weakSelf.loadInspection()
                            } else {
                                SVProgressHUD.showError(withStatus: "Inspection Not Found")
                            }
                        }
                    })
                }
            }
        }
        
        if (showHUD || dismiss) && !isConnected {
            if !hasSavedOffline {
                SVProgressHUD.showInfo(withStatus: "Saved locally. Please reconnect online to auto upload saved data.")
                hasSavedOffline = true
            } else {
                SVProgressHUD.showInfo(withStatus: "Saved locally.")
            }
            if let nav = navigationController, dismiss {
                nav.popViewController(animated: true)
                deinitialize()
            }
        } else {
            hasSavedOffline = false
            
            // Ask user to generate PDF
            if !dismiss && keyInspection.inspection.inspectionCompleted && !ignoreCompleteStatusOnSave {
                alertForPDFReport()
            }
        }
        
        if keyInspection.inspection.inspectionCompleted {
            readOnly = true
            adminEditMode = false
        }
        
        return true
    }
    
    // MARK: Actions
    
    @objc func hitSectionAdd(button: UIButton) {
        if let header = button.superview as? InspectionSectionHeaderView {
            print("hitSectionAdd for \(header.sectionIndex)")
            // (key: String, section: TemplateSection, keyItems: [ (key: String, item: TemplateItem)
            if let newSection = Mapper<TemplateSection>().map(JSONObject: keySectionsWithKeyItems[header.sectionIndex].section.toJSON()) {
                let newSectionKey = dbCollectionTemplates().document().documentID
                newSection.addedMultiSection = true
                var newKeyItems : [ (key: String, item: TemplateItem) ] = []
                for keyItem in keySectionsWithKeyItems[header.sectionIndex].keyItems {
                    if let newItem = Mapper<TemplateItem>().map(JSONObject: keyItem.item.toJSON()) {
                        newItem.sectionId = newSectionKey
                        newItem.clearUserInputData()
                        let newItemKey = dbCollectionTemplates().document().documentID
                        newKeyItems.append( (newItemKey, newItem) )
                    }
                }
                let newKeySectionWithKeyItems: KeySectionWithKeyItems = (newSectionKey, newSection, newKeyItems)
                keySectionsWithKeyItems.insert(newKeySectionWithKeyItems, at: header.sectionIndex + 1)
                
                // Update indices
                var index = 0
                for keySectionWithKeyItems in keySectionsWithKeyItems {
                    keySectionWithKeyItems.section.index = index
                    index += 1
                }
                
                tableView.reloadData()
                weak var tv = tableView
                delay(0.3, closure: {
                    let indexPath = IndexPath(row: 0, section: header.sectionIndex+1)
                    tv?.scrollToRow(at: indexPath, at: .top, animated: true)
                })
            }
            
        }
    }
    
    @objc func hitSectionRemove(button: UIButton) {
        if let header = button.superview as? InspectionSectionHeaderView {
            print("hitSectionRemove for \(header.sectionIndex)")
            keySectionsWithKeyItems.remove(at: header.sectionIndex)
            
            // Update indices
            var index = 0
            for keySectionWithKeyItems in keySectionsWithKeyItems {
                keySectionWithKeyItems.section.index = index
                index += 1
            }
            
            tableView.reloadData()
        }
    }
    
    @objc func hitSectionCollapse(button: UIButton) {
        if let header = button.superview as? InspectionSectionHeaderView {
            print("hitSectionCollapse for \(header.sectionIndex)")
            let sectionId = keySectionsWithKeyItems[header.sectionIndex].key
            if let index = collapsedSections.index(of: sectionId) {
                collapsedSections.remove(at: index)
            } else {
                collapsedSections.append(sectionId)
            }
            
            tableView.reloadData()
        }
    }
    
    @IBAction func infoBannerViewTapped(_ sender: Any) {
        if let status = keyInspection?.inspection.inspectionReportStatus, status == "completed_success" {
            processShareButton(ignoreCompleteStatusOnSave: true)
        }
    }
    
    
    @IBAction func shareButtonTapped(_ sender: Any) {
        processShareButton(ignoreCompleteStatusOnSave: true)
    }
    
    func processShareButton(ignoreCompleteStatusOnSave: Bool) {
        if isLoading {
            return
        }
        
        guard let keyInspection = keyInspection else {
            print("ERROR: missing data, could not create PDF")
            return
        }
        
        guard waitingOnInspectionReportCompletion == false else {
            print("ERROR: Alreadying generating a PDF")
            return
        }
        
        var pdfNeedsRegen = false
        if let inspectionReportUpdateLastDate = keyInspection.inspection.inspectionReportUpdateLastDate, let updatedLastDate = keyInspection.inspection.updatedLastDate {
            pdfNeedsRegen = updatedLastDate.timeIntervalSince1970 > inspectionReportUpdateLastDate.timeIntervalSince1970
        }

        if !readOnly {
            print("Edit mode - Force Save and New PDF")
            // Force save, but later check for completeness
            if !updateKeyInspection(showHUD: false, dismiss: false, ignoreCompleteStatusOnSave: ignoreCompleteStatusOnSave) {
                let alertController = UIAlertController(title: "Save failed, please try again", message: nil, preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default) { action in
                }
                alertController.addAction(okAction)
                self.present(alertController, animated: true) {}
                return
            }
        } else if keyInspection.inspection.inspectionReportUpdateLastDate == nil || pdfNeedsRegen {
            // PDF has not been generated by backend, or is now outdated (ignoring client-side PDF, if exists)
            print("inspectionReportUpdateLastDate not set - New PDF required")
        }
        else if let inspectionReportURL = keyInspection.inspection.inspectionReportURL {
            print("PDF exists already - Open PDF")

            let filename = inspectionReportURL.components(separatedBy: "/").last ?? "Unknown PDF Filename"
            let downloadURL = URL(string: inspectionReportURL)!
            showActionSheetForPDF(fileName: filename, downloadURL: downloadURL)
            return            
        }

        guard keyInspection.inspection.inspectionCompleted else {
            alertForIncompleteInspection()
            return
        }
        
        guard FIRConnection.connected() else {
            let alertController = UIAlertController(title: "Connection Required", message: "Please reconnect to the internet to generate, upload, and share/view the Sparkle Report.", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default) { action in
            }
            alertController.addAction(okAction)
            self.present(alertController, animated: true) {}
            return
        }
        
        // Check to see if all images have uploaded first
        guard LocalInspectionImages.localImagesNotDeletedNotSynced().count == 0 else {
            if pauseUploadingPhotos {
                let alertController = UIAlertController(title: "Offline Photos Not Synced", message: "Generating a report requires all photos to be uploaded first. Would you like to unpause photo uploads now?", preferredStyle: .alert)
                let okAction = UIAlertAction(title: "Yes, upload photos now.", style: .default) { [weak self] action in
                    pauseUploadingPhotos = false
                    LocalInspectionImages.singleton.startSyncing()
                    LocalDeficientImages.singleton.startSyncing()
                    self?.updateOnlineButton()
                }
                alertController.addAction(okAction)
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
                alertController.addAction(cancelAction)
                self.present(alertController, animated: true) {}
            } else {
                let alertController = UIAlertController(title: "Offline Photos Not Synced", message: "Generating a report requires all photos to be uploaded. Please wait until they are uploaded first.", preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default) { action in
                }
                alertController.addAction(okAction)
                self.present(alertController, animated: true) {}
            }
            return
        }
        
        // API Call
        if let user = currentUser {
            waitingOnInspectionReportCompletion = true

            user.getIDToken { [weak self] (token, error) in
                DispatchQueue.main.async {
                    if let token = token {
                        let headers: HTTPHeaders = [
                            "Authorization": "FB-JWT \(token)",
                            "Content-Type": "application/json"
                        ]
                        
                        SVProgressHUD.showInfo(withStatus: "Generating PDF")
                    
                        AF.request(inspectionsURLString + "/\(keyInspection.key)/report-pdf", method: .patch, parameters: nil, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
                            debugPrint(response)
                            
                            DispatchQueue.main.async {
                                SVProgressHUD.dismiss()
                                
                                self?.waitingOnInspectionReportCompletion = false

                                if let statusCode = response.response?.statusCode, statusCode >= 200 && statusCode < 300 {
                                    if let data = response.data  {
                                        let json = JSON(data)
    //                                    let inspectionReportStatus = json["data"]["attributes"]["inspectionReportStatus"].string ?? "Missing Status"
                                        let inspectionReportURL = json["data"]["attributes"]["inspectionReportURL"].string
                                        let inspectionReportFilename = inspectionReportURL?.components(separatedBy: "/").last
    //                                    let inspectionReportUpdateLastDate = json["data"]["attributes"]["inspectionReportURL"].double
                                        let alertController = UIAlertController(title: "Report PDF Creation", message: "Request submitted successfully.  Please wait until completed.", preferredStyle: .alert)
                                        let okayAction = UIAlertAction(title: "OK", style: .default) { [weak self] action in
                                            if let inspectionReportURL = inspectionReportURL, let fileName = inspectionReportFilename {
                                                let downloadURL = URL(string: inspectionReportURL)!
                                                self?.showActionSheetForPDF(fileName: fileName, downloadURL: downloadURL)
                                                return
                                            } 
                                        }
                                        alertController.addAction(okayAction)
                                        self?.present(alertController, animated: true, completion: nil)
                                    }
                                

                                } else {
                                   let errorMessage = firebaseAPIErrorMessages(data: response.data, error: response.error, statusCode: response.response?.statusCode)
                                   let alertController = UIAlertController(title: "Error Creating Report PDF", message: errorMessage, preferredStyle: .alert)
                                   let okayAction = UIAlertAction(title: "OK", style: .default)
                                   alertController.addAction(okayAction)
                                   self?.present(alertController, animated: true, completion: nil)
                                }
                            }
                        }
                    } else {
                        self?.waitingOnInspectionReportCompletion = false
                        print("ERROR: user token is nil")
                    }
                }
            }
        } else {
            print("ERROR: currentUser is nil")
        }
        
        
        
        
        
//        SVProgressHUD.show(withStatus: "Generating PDF")
//        print("Generating PDF")
//        // weak var weakSelf = self
//        InspectionReportPDF.createPDF(keyInspection: keyInspection, keyProperty: keyProperty, keySectionsWithKeyItems: keySectionsWithKeyItems, forDate: creationDate, completion: { [weak self] (fileName, url, success, errorMessage) in
//
//            // If error occurs
//            let errorAlertController = UIAlertController(title: "Sparkle Report Error", message: errorMessage, preferredStyle: .alert)
//            let okAction = UIAlertAction(title: "OK", style: .default) { action in
//            }
//            errorAlertController.addAction(okAction)
//            //
//
//            if !success {
//                SVProgressHUD.dismiss()
//                self?.present(errorAlertController, animated: true) {}
//                return
//            }
//
//            var pdfData: Data!
//            do {
//                try pdfData = Data(contentsOf: url)
//            } catch {
//                print("Unable to read pdf url")
//                SVProgressHUD.dismiss()
//                self?.present(errorAlertController, animated: true) {}
//                return
//            }
//
//            SVProgressHUD.show(withStatus: "Uploading PDF")
//            print("Uploading PDF")
//
//            let expression = AWSS3TransferUtilityUploadExpression()
//            expression.progressBlock = {(task, progress) in DispatchQueue.main.async(execute: {
//                // Do something e.g. Update a progress bar.
//            })
//            }
//
//            let fileKey = "reports/\(keyInspection.key)/\(fileName).pdf"
//            let fileDisplayName = fileName.replacingOccurrences(of: "_", with: " ")
//            let downloadURLString = "\(AWSS3URL)/\(fileKey)"
//
//            let completionHandler = { (task: AWSS3TransferUtilityUploadTask, error: Error?) -> Swift.Void in
//                DispatchQueue.main.async(execute: {
//                    SVProgressHUD.dismiss()
//
//                    if let error = error {
//                        print("Error occurred uploading PDF: \(error.localizedDescription)")
//                        self?.present(errorAlertController, animated: true) {}
//                    } else {
//                        if let keyProperty = self?.keyProperty, let keyInspection = self?.keyInspection {
//                            var isFirstReport = false
//                            if keyInspection.inspection.inspectionReportURL == nil {
//                                isFirstReport = true
//                            }
//                            keyInspection.inspection.inspectionReportURL = downloadURLString
//                            keyInspection.inspection.inspectionReportFilename = fileDisplayName
//                            Notifications.sendPropertyInspectionReportCreated(keyProperty: keyProperty, keyInspection: keyInspection, isFirstReport: isFirstReport)
//
//                            self?.updateKeyInspection(showHUD: false, dismiss: false, ignoreCompleteStatusOnSave: true)
//                        }
//
//                        if let downloadURL = URL(string: downloadURLString) {
//                            self?.showActionSheetForPDF(fileName: fileDisplayName, downloadURL: downloadURL)
//                        }
//                    }
//                })
//            }
//
//            let  transferUtility = AWSS3TransferUtility.default()
//
//            transferUtility.uploadData(pdfData,
//                                       bucket: AWSS3Bucket,
//                                       key: fileKey,
//                                       contentType: "application/pdf",
//                                       expression: expression,
//                                       completionHandler: completionHandler).continueWith { (task) -> Any? in
//
//                    if let error = task.error {
//                        DispatchQueue.main.async(execute: {
//                            SVProgressHUD.dismiss()
//                            print("Error occurred uploading PDF: \(error.localizedDescription)")
//                            self?.present(errorAlertController, animated: true) {}
//                        })
//                    }
//
//                    if let _ = task.result {
//                        // Do something with uploadTask.
//                    }
//
//                    return nil
//            }
            
//                
//                let pdfRef = storageInspectionReportsRef.child(keyInspection.key).child("\(fileName).pdf")
//                
//                // Upload the file using the property key as the image name
//                SVProgressHUD.show(withStatus: "Uploading PDF")
//                print("Uploading PDF")
//                let pdfMetadata = FIRStorageMetadata()
//                pdfMetadata.cacheControl = "public,max-age=300"
//                pdfMetadata.contentType = "application/pdf"
//                pdfRef.put(pdfData!, metadata: pdfMetadata) { [weak self] metadata, error in
//                    SVProgressHUD.dismiss()
//                    
//                    if (error != nil) {
//                        print("Error occurred uploading PDF")
//                        self?.present(errorAlertController, animated: true) {}
//                    } else {
//                        // Metadata contains file metadata such as size, content-type, and download URL.
//                        guard let downloadURL = URL(string: metadata!.downloadURL()!.absoluteString) else {
//                            print("ERROR: Download URL not available for PDF")
//                            self?.present(errorAlertController, animated: true) {}
//                            return
//                        }
//
//                        self?.keyInspection?.inspection.inspectionReportURL = metadata!.downloadURL()!.absoluteString
//                        self?.keyInspection?.inspection.inspectionReportFilename = fileName
//                        self?.updateKeyInspection(showHUD: false, dismiss: false)
//                        
//                        self?.showActionSheetForPDF(fileName: fileName, downloadURL: downloadURL)
//                    }
//                }
//        })
    
        
        
//            let vc = UIActivityViewController(activityItems: [url], applicationActivities: [])
//            present(vc, animated: true) {
//                // do nothing
//            }
    }
    
    fileprivate func showActionSheetForPDF(fileName: String, downloadURL: URL) {
        let alertController = UIAlertController(title: "Completed Report", message: "Choose the option below for the PDF of the report.", preferredStyle: .actionSheet)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { action in
            // ...
        }
        alertController.addAction(cancelAction)
        
        
        let viewAction = UIAlertAction(title: "View", style: .default) { [weak self] action in
            self?.openPDFViewer(fileName: fileName, url: downloadURL)
        }
        alertController.addAction(viewAction)
        
        let shareAction = UIAlertAction(title: "Share", style: .default) { [weak self] action in
            guard let weakSelf = self else {
                return
            }
            let activityViewController = UIActivityViewController(activityItems: [fileName, downloadURL], applicationActivities: nil)
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                if let presentation = activityViewController.popoverPresentationController {
                    presentation.sourceView = weakSelf.view
                    presentation.barButtonItem = weakSelf.shareButton
                }
            }
            
            weakSelf.present(activityViewController, animated: true) {
                // ...
            }
            
        }
        alertController.addAction(shareAction)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            if let presentation = alertController.popoverPresentationController {
                presentation.sourceView = view
                presentation.barButtonItem = shareButton
            }
        }
        print("Presenting Action Sheet")
        present(alertController, animated: true) {
            // ...
        }
    }
    
    fileprivate func openPDFViewer(fileName: String, url: URL) {
        let storyboard = UIStoryboard(name: "PDFPreviewVC", bundle: nil)
        let vc = storyboard.instantiateInitialViewController() as! PDFPreviewVC
        vc.setupWithURL(fileName: fileName, url: url)
        present(vc, animated: true, completion: nil)
    }
    
    fileprivate func recordAction(item: TemplateItem, action: String) {
        if !readOnly && !hasChanges {
            hasChanges = true
            addSaveButton()
        }
        
        if !adminEditMode {
            return
        }
        
        let adminEdits = item.sortedAdminEdits()
        if let lastEdit = adminEdits.last, lastEdit.action == action {
            return // Repeat of last edit
        }
        
        var userName: String?
        if let currentUserProfile = currentUserProfile {
            if let firstName = currentUserProfile.firstName {
                userName = firstName
                if let lastName = currentUserProfile.lastName {
                    userName = "\(firstName) \(lastName)"
                }
            } else if let lastName = currentUserProfile.lastName {
                userName = lastName
            }
        }
        
        if let adminEdit = AdminEdit(JSONString: "{}"), let currentUser = currentUser {
            adminEdit.editDate = Date()
            adminEdit.action = action
            adminEdit.adminUserId = currentUser.uid
            adminEdit.adminName = currentUser.displayName ?? userName ?? "No Name"
            let newKey = dbCollectionInspections().document().documentID
            item.add(adminEdit: adminEdit, forKey: newKey)
            print("Added AdminEdit, with action \"\(action)\"")
        }
    }
    
    fileprivate func showInfoBanner(text: String, flash: Bool) {
        // Already showing? Animate Table down, if not
        if !infoBannerVisible {
            UIView.animate(withDuration: 0.33) { [weak self] in
                self?.tableTopConstraint.constant = 44.0
            } completion: { [weak self] (success) in
                if success {
                    DispatchQueue.main.async { [weak self] in
                        self?.infoBannerVisible = true
                    }
                }
            }
        }
        // Update text
        infoBannerLabel.text = text
        
        // Set or Reset flashing
        if flash {
            infoBannerLabel.alpha = 1
            infoBannerLabel.layer.removeAllAnimations()
            UIView.animate(withDuration: 1.5, delay: 0.5, options: [.repeat, .autoreverse]) { [weak self] in
                self?.infoBannerLabel.alpha = 0
            }
        } else {
            infoBannerLabel.alpha = 1
            infoBannerLabel.layer.removeAllAnimations()
        }
        
    }
    
    fileprivate func hideInfoBanner() {
        // Stop Flashing
        infoBannerLabel.layer.removeAllAnimations()

        // hide by animate table back over top
        if infoBannerVisible {
            UIView.animate(withDuration: 0.33) { [weak self] in
                self?.tableTopConstraint.constant = 0.0
            } completion: { [weak self] (success) in
                if success {
                    DispatchQueue.main.async { [weak self] in
                        self?.infoBannerVisible = false
                    }
                }
            }
        }
    }
    
    
    
    // MARK: Keyboard
    
    @objc func keyboardWillShow(_ note: Notification) {
        let keyboardData = keyboardInfoFromNotification(note)
        let offsetHeight = keyboardData.endFrame.size.height
        tableView.layoutIfNeeded()
        weak var constraint = bottomConstraint
        weak var tv = tableView
        UIView.animate(withDuration: keyboardData.animationDuration,
                       delay: 0,
                       options: keyboardData.animationCurve,
                       animations: {
                        constraint?.constant = offsetHeight
                        tv?.layoutIfNeeded()
        },
                       completion: nil)
    }
    
    @objc func keyboardWillHide(_ note: Notification) {
        let keyboardData = keyboardInfoFromNotification(note)
        tableView.layoutIfNeeded()
        weak var constraint = bottomConstraint
        weak var tv = tableView
        UIView.animate(withDuration: keyboardData.animationDuration,
                       delay: 0,
                       options: keyboardData.animationCurve,
                       animations: {
                        constraint?.constant = 0
                        tv?.layoutIfNeeded()
        }, completion: nil)
    }
    
    // MARK: Alerts
    
    func alertForPDFReport() {
        let alertController = UIAlertController(title: "Inspection Complete", message: "Would you like to generate a Report PDF?", preferredStyle: .alert)
        let yesAction = UIAlertAction(title: NSLocalizedString("YES", comment: "Okay action"), style: .default, handler: { [weak self] (action) in
            print("Okay Action")
            guard let weakSelf = self else {
                return
            }
            weakSelf.processShareButton(ignoreCompleteStatusOnSave: true)
        })
        let noAction = UIAlertAction(title: NSLocalizedString("NO", comment: "No action"), style: .cancel, handler: { (action) in
            print("NO Action")
        })
        alertController.addAction(yesAction)
        alertController.addAction(noAction)

        present(alertController, animated: true, completion: {})
        
        showInspectionIncompletes = true
        tableView.reloadData()
    }
    
    func alertForIncompleteInspection() {
        let alertController = UIAlertController(title: "Incomplete", message: "Reports are only available after completion", preferredStyle: .alert)
        let okayAction = UIAlertAction(title: NSLocalizedString("OK", comment: "Okay action"), style: .default, handler: { (action) in
            print("Okay Action")
        })
        alertController.addAction(okayAction)
        
        present(alertController, animated: true, completion: {})
        
        showInspectionIncompletes = true
        tableView.reloadData()
    }
    
    func alertForPausedUploading() {
        let alertController = UIAlertController(title: "Photo Uploading - Paused", message: "All photos will now be saved offline, to save time, battery, and data (if cellular).", preferredStyle: .alert)
        let okayAction = UIAlertAction(title: NSLocalizedString("OK", comment: "Okay action"), style: .default, handler: { (action) in
            print("Okay Action")
        })
        alertController.addAction(okayAction)
        
        present(alertController, animated: true, completion: {})
    }
    
    func alertAskToPausedUploading() {
        let alertController = UIAlertController(title: "Pause Photo Uploads?", message: "If enabled, all photos will be saved offline, to save time, battery, and data (if cellular).  To re-enable uploading, tap the pause button, or save & exit inspection.", preferredStyle: .alert)
        let yesAction = UIAlertAction(title: NSLocalizedString("YES", comment: "YES, pause photo uploads."), style: .default, handler: { [weak self] (action) in
            
            pauseUploadingPhotos = true
            self?.updateOnlineButton()
        })
        let noAction = UIAlertAction(title: NSLocalizedString("NO", comment: "NO, do not pause photo uploads."), style: .cancel, handler: { (action) in
            print("NO Action")
        })
        alertController.addAction(noAction)
        alertController.addAction(yesAction)

        present(alertController, animated: true, completion: {})
    }
    
    // MARK: Application Life Cycle Updates

    @objc func autoSaveInspection(_ note: Notification) {
        print("InspectionVC: autoSaveInspection called")
        
        if !readOnly && hasChanges {
            let _ = updateKeyInspection(showHUD: false, dismiss: false, ignoreCompleteStatusOnSave: true)
            print("InspectionVC: inspection saved")
        }
    }
    
    @objc func updateUI(_ note: Notification) {
        print("InspectionVC: updateUI called")
        tableView.reloadData()
        
        updateInfoBanner()
    }
    
}



// MARK: - InspectionItemTVCell


protocol InspectionItemTVCellDelegate: class {
    func inspectionItemTVCellUpdated(cell: InspectionItemTVCell, action: String)
    func inspectionItemTVCellOpenMainInputNotes(_ inspectionItemTVCell: InspectionItemTVCell)
    func inspectionItemTVCellOpenInspectorNotes(_ inspectionItemTVCell: InspectionItemTVCell)
    func inspectionItemTVCellOpenGallery(_ inspectionItemTVCell: InspectionItemTVCell)
}

class InspectionItemTVCell: UITableViewCell {
    var item: TemplateItem?
    weak var delegate: InspectionItemTVCellDelegate?
    var readOnly = true
    var requireDeficientItemNoteAndPhoto = false
    
    @IBOutlet weak var itemName: UILabel!
    
    // Icon Images
    @IBOutlet weak var actionIconZeroImageView: UIImageView!
    @IBOutlet weak var actionIconOneImageView: UIImageView!
    @IBOutlet weak var actionIconTwoImageView: UIImageView!
    @IBOutlet weak var actionIconThreeImageView: UIImageView!
    @IBOutlet weak var actionIconFourImageView: UIImageView!
    @IBOutlet weak var notesImageView: UIImageView!
    @IBOutlet weak var cameraImageView: UIImageView!

    // Buttons
    @IBOutlet weak var actionZeroButton: UIButton!
    @IBOutlet weak var actionOneButton: UIButton!
    @IBOutlet weak var actionTwoButton: UIButton!
    @IBOutlet weak var actionThreeButton: UIButton!
    @IBOutlet weak var actionFourButton: UIButton!
    @IBOutlet weak var notesButton: UIButton!
    @IBOutlet weak var photosButton: UIButton!

    @IBOutlet weak var viewNA: UIView!
    
    // MARK: - Actions
    @IBAction func actionZero(_ sender: AnyObject) {
        print("actionZero")
        if let item = item, let mainInputType = item.mainInputType, let mainInputTypeEnum = TemplateItemActions(rawValue: mainInputType.lowercased()) {

            switch mainInputTypeEnum {
            case .TwoActions_checkmarkX, .TwoActions_thumbs, .ThreeActions_checkmarkExclamationX, .ThreeActions_ABC, .FiveActions_oneToFive:
                // update item data
                if let mainInputSelection = item.mainInputSelection , mainInputSelection == 0 {
                    // Toggle selected, if same selection
                    item.mainInputSelected = !item.mainInputSelected
                } else {
                    item.mainInputSelected = true
                    item.mainInputSelection = 0
                }
                
                updateUIForZeroSelection(item, mainInputTypeEnum: mainInputTypeEnum, isFromAction: true)
                // Update note and photo buttons, if required and isDeficientItem
                configureButtons()
                InspectionVC.updateTableViewCellForItemCompleteness(cell: self, item: item)

            case .OneAction_notes:
                print("Open Notes")
                if let delegate = delegate {
                    delegate.inspectionItemTVCellOpenMainInputNotes(self)
                }
            }
        }
    }
    @IBAction func actionOne(_ sender: AnyObject) {
        print("actionOne")
        if let item = item, let mainInputType = item.mainInputType, let mainInputTypeEnum = TemplateItemActions(rawValue: mainInputType.lowercased()) {
            // update item data
            if let mainInputSelection = item.mainInputSelection , mainInputSelection == 1 {
                // Toggle selected, if same selection
                item.mainInputSelected = !item.mainInputSelected
            } else {
                item.mainInputSelected = true
                item.mainInputSelection = 1
            }
            
            updateUIForOneSelection(item, mainInputTypeEnum: mainInputTypeEnum, isFromAction: true)
            // Update note and photo buttons, if required and isDeficientItem
            configureButtons()
            InspectionVC.updateTableViewCellForItemCompleteness(cell: self, item: item)
        }
    }
    @IBAction func actionTwo(_ sender: AnyObject) {
        print("actionTwo")
        if let item = item, let mainInputType = item.mainInputType, let mainInputTypeEnum = TemplateItemActions(rawValue: mainInputType.lowercased()) {
            // update item data
            if let mainInputSelection = item.mainInputSelection , mainInputSelection == 2 {
                // Toggle selected, if same selection
                item.mainInputSelected = !item.mainInputSelected
            } else {
                item.mainInputSelected = true
                item.mainInputSelection = 2
            }

            updateUIForTwoSelection(item, mainInputTypeEnum: mainInputTypeEnum, isFromAction: true)
            // Update note and photo buttons, if required and isDeficientItem
            configureButtons()
            InspectionVC.updateTableViewCellForItemCompleteness(cell: self, item: item)
        }
    }
    @IBAction func actionThree(_ sender: AnyObject) {
        print("actionThree")
        if let item = item, let mainInputType = item.mainInputType, let mainInputTypeEnum = TemplateItemActions(rawValue: mainInputType.lowercased()) {
            // update item data
            if let mainInputSelection = item.mainInputSelection , mainInputSelection == 3 {
                // Toggle selected, if same selection
                item.mainInputSelected = !item.mainInputSelected
            } else {
                item.mainInputSelected = true
                item.mainInputSelection = 3
            }
            
            updateUIForThreeSelection(item, mainInputTypeEnum: mainInputTypeEnum, isFromAction: true)
            // Update note and photo buttons, if required and isDeficientItem
            configureButtons()
            InspectionVC.updateTableViewCellForItemCompleteness(cell: self, item: item)
        }
    }
    @IBAction func actionFour(_ sender: AnyObject) {
        print("actionFour")
        if let item = item, let mainInputType = item.mainInputType, let mainInputTypeEnum = TemplateItemActions(rawValue: mainInputType.lowercased()) {
            // update item data
            if let mainInputSelection = item.mainInputSelection , mainInputSelection == 4 {
                // Toggle selected, if same selection
                item.mainInputSelected = !item.mainInputSelected
            } else {
                item.mainInputSelected = true
                item.mainInputSelection = 4
            }

            updateUIForFourSelection(item, mainInputTypeEnum: mainInputTypeEnum, isFromAction: true)
            // Update note and photo buttons, if required and isDeficientItem
            configureButtons()
            InspectionVC.updateTableViewCellForItemCompleteness(cell: self, item: item)
        }
    }
    
    @IBAction func noteButtonTapped(_ sender: AnyObject) {
        print("actionNotes")
        if let _ = item {
            if let delegate = delegate {
                delegate.inspectionItemTVCellOpenInspectorNotes(self)
            }
        }
    }
    
    @IBAction func cameraButtonTapped(_ sender: AnyObject) {
        print("actionPhotos")
        if let _ = item {
            if let delegate = delegate {
                delegate.inspectionItemTVCellOpenGallery(self)
            }
        }
    }
    
    // MARK: - Setup
    
    func configureIcons() {
        if let item = item, let mainInputType = item.mainInputType, let mainInputTypeEnum = TemplateItemActions(rawValue: mainInputType.lowercased()) {
            var imageZero: UIImage?
            var imageOne: UIImage?
            var imageTwo: UIImage?
            var imageThree: UIImage?
            var imageFour: UIImage?
            
            // Default Tint
            actionIconZeroImageView.tintColor = GlobalColors.unselectedGrey
            actionIconOneImageView.tintColor = GlobalColors.unselectedGrey
            actionIconTwoImageView.tintColor = GlobalColors.unselectedGrey
            actionIconThreeImageView.tintColor = GlobalColors.unselectedGrey
            actionIconFourImageView.tintColor = GlobalColors.unselectedGrey

            switch mainInputTypeEnum {
            case .TwoActions_checkmarkX:
                imageZero  = twoActions_checkmarkX_iconNames.iconName0 != "" ? UIImage(named: twoActions_checkmarkX_iconNames.iconName0) : nil
                imageOne   = twoActions_checkmarkX_iconNames.iconName1 != "" ? UIImage(named: twoActions_checkmarkX_iconNames.iconName1) : nil
                imageTwo   = twoActions_checkmarkX_iconNames.iconName2 != "" ? UIImage(named: twoActions_checkmarkX_iconNames.iconName2) : nil
                imageThree = twoActions_checkmarkX_iconNames.iconName3 != "" ? UIImage(named: twoActions_checkmarkX_iconNames.iconName3) : nil
                imageFour  = twoActions_checkmarkX_iconNames.iconName4 != "" ? UIImage(named: twoActions_checkmarkX_iconNames.iconName4) : nil
            case .TwoActions_thumbs:
                imageZero  = twoActions_thumbs_iconNames.iconName0 != "" ? UIImage(named: twoActions_thumbs_iconNames.iconName0) : nil
                imageOne   = twoActions_thumbs_iconNames.iconName1 != "" ? UIImage(named: twoActions_thumbs_iconNames.iconName1) : nil
                imageTwo   = twoActions_thumbs_iconNames.iconName2 != "" ? UIImage(named: twoActions_thumbs_iconNames.iconName2) : nil
                imageThree = twoActions_thumbs_iconNames.iconName3 != "" ? UIImage(named: twoActions_thumbs_iconNames.iconName3) : nil
                imageFour  = twoActions_thumbs_iconNames.iconName4 != "" ? UIImage(named: twoActions_thumbs_iconNames.iconName4) : nil
            case .ThreeActions_checkmarkExclamationX:
                imageZero  = threeActions_checkmarkExclamationX_iconNames.iconName0 != "" ? UIImage(named: threeActions_checkmarkExclamationX_iconNames.iconName0) : nil
                imageOne   = threeActions_checkmarkExclamationX_iconNames.iconName1 != "" ? UIImage(named: threeActions_checkmarkExclamationX_iconNames.iconName1) : nil
                imageTwo   = threeActions_checkmarkExclamationX_iconNames.iconName2 != "" ? UIImage(named: threeActions_checkmarkExclamationX_iconNames.iconName2) : nil
                imageThree = threeActions_checkmarkExclamationX_iconNames.iconName3 != "" ? UIImage(named: threeActions_checkmarkExclamationX_iconNames.iconName3) : nil
                imageFour  = threeActions_checkmarkExclamationX_iconNames.iconName4 != "" ? UIImage(named: threeActions_checkmarkExclamationX_iconNames.iconName4) : nil
            case .ThreeActions_ABC:
                imageZero  = threeActions_ABC_iconNames.iconName0 != "" ? UIImage(named: threeActions_ABC_iconNames.iconName0) : nil
                imageOne   = threeActions_ABC_iconNames.iconName1 != "" ? UIImage(named: threeActions_ABC_iconNames.iconName1) : nil
                imageTwo   = threeActions_ABC_iconNames.iconName2 != "" ? UIImage(named: threeActions_ABC_iconNames.iconName2) : nil
                imageThree = threeActions_ABC_iconNames.iconName3 != "" ? UIImage(named: threeActions_ABC_iconNames.iconName3) : nil
                imageFour  = threeActions_ABC_iconNames.iconName4 != "" ? UIImage(named: threeActions_ABC_iconNames.iconName4) : nil
            case .FiveActions_oneToFive:
                imageZero  = fiveActions_oneToFive_iconNames.iconName0 != "" ? UIImage(named: fiveActions_oneToFive_iconNames.iconName0) : nil
                imageOne   = fiveActions_oneToFive_iconNames.iconName1 != "" ? UIImage(named: fiveActions_oneToFive_iconNames.iconName1) : nil
                imageTwo   = fiveActions_oneToFive_iconNames.iconName2 != "" ? UIImage(named: fiveActions_oneToFive_iconNames.iconName2) : nil
                imageThree = fiveActions_oneToFive_iconNames.iconName3 != "" ? UIImage(named: fiveActions_oneToFive_iconNames.iconName3) : nil
                imageFour  = fiveActions_oneToFive_iconNames.iconName4 != "" ? UIImage(named: fiveActions_oneToFive_iconNames.iconName4) : nil
            case .OneAction_notes:
                imageZero  = oneAction_notes_iconNames.iconName0 != "" ? UIImage(named: oneAction_notes_iconNames.iconName0) : nil
                imageOne   = oneAction_notes_iconNames.iconName1 != "" ? UIImage(named: oneAction_notes_iconNames.iconName1) : nil
                imageTwo   = oneAction_notes_iconNames.iconName2 != "" ? UIImage(named: oneAction_notes_iconNames.iconName2) : nil
                imageThree = oneAction_notes_iconNames.iconName3 != "" ? UIImage(named: oneAction_notes_iconNames.iconName3) : nil
                imageFour  = oneAction_notes_iconNames.iconName4 != "" ? UIImage(named: oneAction_notes_iconNames.iconName4) : nil
            }
            
            actionIconZeroImageView.image  = imageZero?.withRenderingMode(.alwaysTemplate)
            actionIconOneImageView.image   = imageOne?.withRenderingMode(.alwaysTemplate)
            actionIconTwoImageView.image   = imageTwo?.withRenderingMode(.alwaysTemplate)
            actionIconThreeImageView.image = imageThree?.withRenderingMode(.alwaysTemplate)
            actionIconFourImageView.image  = imageFour?.withRenderingMode(.alwaysTemplate)
        }
    }
    
    func configureButtons() {
        if readOnly {
            actionZeroButton.isEnabled = false
            actionOneButton.isEnabled = false
            actionTwoButton.isEnabled = false
            actionThreeButton.isEnabled = false
            actionFourButton.isEnabled = false
        } else {
            actionZeroButton.isEnabled  = actionIconZeroImageView.image != nil
            actionOneButton.isEnabled   = actionIconOneImageView.image != nil
            actionTwoButton.isEnabled   = actionIconTwoImageView.image != nil
            actionThreeButton.isEnabled = actionIconThreeImageView.image != nil
            actionFourButton.isEnabled  = actionIconFourImageView.image != nil            
        }
        
        if let item = item {
            
            let enableNotes = item.notes ?? true
            item.notes = enableNotes
            notesImageView.image = UIImage(named: "message")?.withRenderingMode(.alwaysTemplate)
            notesImageView.alpha = enableNotes ? 1.0 : 0.05
            
            let enableCamera = item.photos ?? true
            item.photos = enableCamera
            cameraImageView.image = UIImage(named: "camera")?.withRenderingMode(.alwaysTemplate)
            cameraImageView.alpha = enableCamera ? 1.0 : 0.05
            
            notesButton.isEnabled = item.notes ?? false
            photosButton.isEnabled = item.photos ?? false
            
            notesImageView.layer.removeAllAnimations()
            if let inspectorNotes = item.inspectorNotes , inspectorNotes != "" {
                notesImageView.tintColor = GlobalColors.selectedBlue
                notesImageView.alpha = 1.0
                notesButton.isEnabled = true
            } else if enableNotes && requireDeficientItemNoteAndPhoto && item.isDeficientItem && !item.isItemNA {
                notesImageView.alpha = 1.0
                notesImageView.tintColor = GlobalColors.selectedRed
//                notesButton.isEnabled = true
                UIView.animate(withDuration: 0.5, delay: 0, options: [.repeat,.autoreverse], animations: { [weak self] in
                    self?.notesImageView.alpha = 0.0
                }, completion: nil)
            } else {
                notesImageView.tintColor = GlobalColors.selectedBlack
            }
            
            cameraImageView.layer.removeAllAnimations()
            if item.photosData.values.count > 0 {
                cameraImageView.tintColor = GlobalColors.selectedBlue
                cameraImageView.alpha = 1.0
                photosButton.isEnabled = true
            } else if enableCamera && requireDeficientItemNoteAndPhoto && item.isDeficientItem && !item.isItemNA {
                cameraImageView.alpha = 1.0
                cameraImageView.tintColor = GlobalColors.selectedRed
//                photosButton.isEnabled = true
                UIView.animate(withDuration: 0.5, delay: 0, options: [.repeat,.autoreverse], animations: { [weak self] in
                    self?.cameraImageView.alpha = 0.0
                    }, completion: nil)
            } else {
                cameraImageView.tintColor = GlobalColors.selectedBlack
            }
            
            item.updateRequiredNoteAndPhotoIncomplete(isRequired: requireDeficientItemNoteAndPhoto)
        }
    }

    func configureUIForMainInputSelection() {
        if let item = item, let mainInputType = item.mainInputType, let mainInputTypeEnum = TemplateItemActions(rawValue: mainInputType.lowercased()) {
            // For Main Input Notes Only, check if there are notes
            if mainInputTypeEnum == .OneAction_notes {
                if let mainInputNotes = item.mainInputNotes , mainInputNotes != "" {
                    item.mainInputSelected = true
                    item.mainInputSelection = 0
                    actionZeroButton.isEnabled = true // force enabled, to always view
                } else {
                    item.mainInputSelected = false
                    return
                }
            }
            
            // HACK - to make sure it saves values.
            //if item.mainInputSelection != nil && item.mainInputSelected == false {
            //    item.mainInputSelected = true
            //}
            
            if let mainInputSelection = item.mainInputSelection , item.mainInputSelected {
                switch mainInputSelection {
                case 0:
                    updateUIForZeroSelection(item, mainInputTypeEnum: mainInputTypeEnum, isFromAction: false)
                case 1:
                    updateUIForOneSelection(item, mainInputTypeEnum: mainInputTypeEnum, isFromAction: false)
                case 2:
                    updateUIForTwoSelection(item, mainInputTypeEnum: mainInputTypeEnum, isFromAction: false)
                case 3:
                    updateUIForThreeSelection(item, mainInputTypeEnum: mainInputTypeEnum, isFromAction: false)
                case 4:
                    updateUIForFourSelection(item, mainInputTypeEnum: mainInputTypeEnum, isFromAction: false)
                    
                default:
                    return
                }
            }
        }
    }
    
    func updateUIForZeroSelection(_ item: TemplateItem, mainInputTypeEnum: TemplateItemActions, isFromAction: Bool) {

        
        if !item.mainInputSelected {
            actionIconZeroImageView.tintColor = GlobalColors.unselectedGrey
            actionIconOneImageView.tintColor = GlobalColors.unselectedGrey
            actionIconTwoImageView.tintColor = GlobalColors.unselectedGrey
            actionIconThreeImageView.tintColor = GlobalColors.unselectedGrey
            actionIconFourImageView.tintColor = GlobalColors.unselectedGrey
            item.deficient = false
            item.isDeficientItem = false
            if isFromAction { delegate?.inspectionItemTVCellUpdated(cell: self, action: "unselected main input") }
        } else {
            switch mainInputTypeEnum {
            case .TwoActions_checkmarkX:
                actionIconZeroImageView.tintColor = GlobalColors.selectedBlue
                actionIconOneImageView.tintColor = GlobalColors.unselectedGrey
                item.deficient = false
                item.isDeficientItem = false
                if isFromAction { delegate?.inspectionItemTVCellUpdated(cell: self, action: "selected checkmark") }
            case .TwoActions_thumbs:
                actionIconZeroImageView.tintColor = GlobalColors.selectedBlue
                actionIconOneImageView.tintColor = GlobalColors.unselectedGrey
                item.deficient = false
                item.isDeficientItem = false
                if isFromAction { delegate?.inspectionItemTVCellUpdated(cell: self, action: "selected thumbsup") }
            case .ThreeActions_checkmarkExclamationX:
                actionIconZeroImageView.tintColor = GlobalColors.selectedBlue
                actionIconOneImageView.tintColor = GlobalColors.unselectedGrey
                actionIconTwoImageView.tintColor = GlobalColors.unselectedGrey
                item.deficient = false
                item.isDeficientItem = false
                if isFromAction { delegate?.inspectionItemTVCellUpdated(cell: self, action: "selected checkmark") }
            case .ThreeActions_ABC:
                actionIconZeroImageView.tintColor = GlobalColors.selectedBlue
                actionIconOneImageView.tintColor = GlobalColors.unselectedGrey
                actionIconTwoImageView.tintColor = GlobalColors.unselectedGrey
                item.deficient = false
                item.isDeficientItem = false
                if isFromAction { delegate?.inspectionItemTVCellUpdated(cell: self, action: "selected A") }
            case .FiveActions_oneToFive:
                actionIconZeroImageView.tintColor = GlobalColors.selectedRed
                actionIconOneImageView.tintColor = GlobalColors.unselectedGrey
                actionIconTwoImageView.tintColor = GlobalColors.unselectedGrey
                actionIconThreeImageView.tintColor = GlobalColors.unselectedGrey
                actionIconFourImageView.tintColor = GlobalColors.unselectedGrey
                item.deficient = true
                item.isDeficientItem = true
                if isFromAction { delegate?.inspectionItemTVCellUpdated(cell: self, action: "selected 1") }
            case .OneAction_notes:
                actionIconZeroImageView.tintColor = GlobalColors.selectedBlue
            }
        }
    }
    
    func updateUIForOneSelection(_ item: TemplateItem, mainInputTypeEnum: TemplateItemActions, isFromAction: Bool) {
        if !item.mainInputSelected {
            actionIconZeroImageView.tintColor = GlobalColors.unselectedGrey
            actionIconOneImageView.tintColor = GlobalColors.unselectedGrey
            actionIconTwoImageView.tintColor = GlobalColors.unselectedGrey
            actionIconThreeImageView.tintColor = GlobalColors.unselectedGrey
            actionIconFourImageView.tintColor = GlobalColors.unselectedGrey
            item.deficient = false
            item.isDeficientItem = false
            if isFromAction { delegate?.inspectionItemTVCellUpdated(cell: self, action: "unselected main input") }
        } else {
            switch mainInputTypeEnum {
            case .TwoActions_checkmarkX:
                actionIconZeroImageView.tintColor = GlobalColors.unselectedGrey
                actionIconOneImageView.tintColor = GlobalColors.selectedRed
                item.deficient = true
                item.isDeficientItem = true
                if isFromAction { delegate?.inspectionItemTVCellUpdated(cell: self, action: "selected X") }
            case .TwoActions_thumbs:
                actionIconZeroImageView.tintColor = GlobalColors.unselectedGrey
                actionIconOneImageView.tintColor = GlobalColors.selectedRed
                item.deficient = true
                item.isDeficientItem = true
                if isFromAction { delegate?.inspectionItemTVCellUpdated(cell: self, action: "selected thumbsdown") }
            case .ThreeActions_checkmarkExclamationX:
                actionIconZeroImageView.tintColor = GlobalColors.unselectedGrey
                actionIconOneImageView.tintColor = GlobalColors.selectedBlack
                actionIconTwoImageView.tintColor = GlobalColors.unselectedGrey
                item.deficient = false
                item.isDeficientItem = true
                if isFromAction { delegate?.inspectionItemTVCellUpdated(cell: self, action: "selected exclamation") }
            case .ThreeActions_ABC:
                actionIconZeroImageView.tintColor = GlobalColors.unselectedGrey
                actionIconOneImageView.tintColor = GlobalColors.selectedBlack
                actionIconTwoImageView.tintColor = GlobalColors.unselectedGrey
                item.deficient = false
                item.isDeficientItem = true
                if isFromAction { delegate?.inspectionItemTVCellUpdated(cell: self, action: "selected B") }
            case .FiveActions_oneToFive:
                actionIconZeroImageView.tintColor = GlobalColors.selectedRed
                actionIconOneImageView.tintColor = GlobalColors.selectedRed
                actionIconTwoImageView.tintColor = GlobalColors.unselectedGrey
                actionIconThreeImageView.tintColor = GlobalColors.unselectedGrey
                actionIconFourImageView.tintColor = GlobalColors.unselectedGrey
                item.deficient = true
                item.isDeficientItem = true
                if isFromAction { delegate?.inspectionItemTVCellUpdated(cell: self, action: "selected 2") }
            case .OneAction_notes:
                print("UNEXPECTED: There is no configuration for notes selection, One")
            }
        }
    }
    
    func updateUIForTwoSelection(_ item: TemplateItem, mainInputTypeEnum: TemplateItemActions, isFromAction: Bool) {
        if !item.mainInputSelected {
            actionIconZeroImageView.tintColor = GlobalColors.unselectedGrey
            actionIconOneImageView.tintColor = GlobalColors.unselectedGrey
            actionIconTwoImageView.tintColor = GlobalColors.unselectedGrey
            actionIconThreeImageView.tintColor = GlobalColors.unselectedGrey
            actionIconFourImageView.tintColor = GlobalColors.unselectedGrey
            item.deficient = false
            item.isDeficientItem = false
            if isFromAction { delegate?.inspectionItemTVCellUpdated(cell: self, action: "unselected main input") }
        } else {
            switch mainInputTypeEnum {
            case .TwoActions_checkmarkX, .TwoActions_thumbs:
                print("UNEXPECTED: There is no configuration for TwoActions selection, Two")
            case .ThreeActions_checkmarkExclamationX:
                actionIconZeroImageView.tintColor = GlobalColors.unselectedGrey
                actionIconOneImageView.tintColor = GlobalColors.unselectedGrey
                actionIconTwoImageView.tintColor = GlobalColors.selectedRed
                item.deficient = true
                item.isDeficientItem = true
                if isFromAction { delegate?.inspectionItemTVCellUpdated(cell: self, action: "selected X") }
            case .ThreeActions_ABC:
                actionIconZeroImageView.tintColor = GlobalColors.unselectedGrey
                actionIconOneImageView.tintColor = GlobalColors.unselectedGrey
                actionIconTwoImageView.tintColor = GlobalColors.selectedRed
                item.deficient = true
                item.isDeficientItem = true
                if isFromAction { delegate?.inspectionItemTVCellUpdated(cell: self, action: "selected C") }
            case .FiveActions_oneToFive:
                actionIconZeroImageView.tintColor = GlobalColors.selectedBlack
                actionIconOneImageView.tintColor = GlobalColors.selectedBlack
                actionIconTwoImageView.tintColor = GlobalColors.selectedBlack
                actionIconThreeImageView.tintColor = GlobalColors.unselectedGrey
                actionIconFourImageView.tintColor = GlobalColors.unselectedGrey
                item.deficient = false
                item.isDeficientItem = true
                if isFromAction { delegate?.inspectionItemTVCellUpdated(cell: self, action: "selected 3") }
            case .OneAction_notes:
                print("UNEXPECTED: There is no configuration for notes selection, Two")
            }
        }
    }
    
    func updateUIForThreeSelection(_ item: TemplateItem, mainInputTypeEnum: TemplateItemActions, isFromAction: Bool) {
        if !item.mainInputSelected {
            actionIconZeroImageView.tintColor = GlobalColors.unselectedGrey
            actionIconOneImageView.tintColor = GlobalColors.unselectedGrey
            actionIconTwoImageView.tintColor = GlobalColors.unselectedGrey
            actionIconThreeImageView.tintColor = GlobalColors.unselectedGrey
            actionIconFourImageView.tintColor = GlobalColors.unselectedGrey
            item.deficient = false
            item.isDeficientItem = false
            if isFromAction { delegate?.inspectionItemTVCellUpdated(cell: self, action: "unselected main input") }
        } else {
            switch mainInputTypeEnum {
            case .TwoActions_checkmarkX, .TwoActions_thumbs:
                print("UNEXPECTED: There is no configuration for TwoActions selection, Three")
            case .ThreeActions_checkmarkExclamationX, .ThreeActions_ABC:
                print("UNEXPECTED: There is no configuration for ThreeActions selection, Three")
            case .FiveActions_oneToFive:
                actionIconZeroImageView.tintColor = GlobalColors.selectedBlue
                actionIconOneImageView.tintColor = GlobalColors.selectedBlue
                actionIconTwoImageView.tintColor = GlobalColors.selectedBlue
                actionIconThreeImageView.tintColor = GlobalColors.selectedBlue
                actionIconFourImageView.tintColor = GlobalColors.unselectedGrey
                item.deficient = false
                item.isDeficientItem = true
                if isFromAction { delegate?.inspectionItemTVCellUpdated(cell: self, action: "selected 4") }
            case .OneAction_notes:
                print("UNEXPECTED: There is no configuration for notes selection, Three")
            }
        }
    }
    
    func updateUIForFourSelection(_ item: TemplateItem, mainInputTypeEnum: TemplateItemActions, isFromAction: Bool) {
        if !item.mainInputSelected {
            actionIconZeroImageView.tintColor = GlobalColors.unselectedGrey
            actionIconOneImageView.tintColor = GlobalColors.unselectedGrey
            actionIconTwoImageView.tintColor = GlobalColors.unselectedGrey
            actionIconThreeImageView.tintColor = GlobalColors.unselectedGrey
            actionIconFourImageView.tintColor = GlobalColors.unselectedGrey
            item.deficient = false
            item.isDeficientItem = false
            if isFromAction { delegate?.inspectionItemTVCellUpdated(cell: self, action: "unselected main input") }
        } else {
            switch mainInputTypeEnum {
            case .TwoActions_checkmarkX, .TwoActions_thumbs:
                print("UNEXPECTED: There is no configuration for TwoActions selection, Four")
            case .ThreeActions_checkmarkExclamationX, .ThreeActions_ABC:
                print("UNEXPECTED: There is no configuration for ThreeActions selection, Four")
            case .FiveActions_oneToFive:
                actionIconZeroImageView.tintColor = GlobalColors.selectedBlue
                actionIconOneImageView.tintColor = GlobalColors.selectedBlue
                actionIconTwoImageView.tintColor = GlobalColors.selectedBlue
                actionIconThreeImageView.tintColor = GlobalColors.selectedBlue
                actionIconFourImageView.tintColor = GlobalColors.selectedBlue
                item.deficient = false
                item.isDeficientItem = false
                if isFromAction { delegate?.inspectionItemTVCellUpdated(cell: self, action: "selected 5") }
            case .OneAction_notes:
                print("UNEXPECTED: There is no configuration for notes selection, Four")
            }
        }
    }

}

protocol InspectionItemTextInputTVCellDelegate: class {
    func inspectionItemTextInputTVCellUpdated(cell: InspectionItemTextInputTVCell, action: String)
}

class InspectionItemTextInputTVCell: UITableViewCell, UITextFieldDelegate {
    var item: TemplateItem?
    weak var delegate: InspectionItemTextInputTVCellDelegate?
    var readOnly = true
    
    @IBOutlet weak var itemName: UILabel!
    @IBOutlet weak var itemTextInputField: UITextField!
    @IBOutlet weak var viewNA: UIView!
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let text: NSString = (textField.text ?? "") as NSString
        let resultString = text.replacingCharacters(in: range, with: string)
        if let item = item {
            item.textInputValue = resultString
            delegate?.inspectionItemTextInputTVCellUpdated(cell: self, action: "updated main text")
            InspectionVC.updateTableViewCellForItemCompleteness(cell: self, item: item)
        }
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

class InspectionItemSignatureTVCell: UITableViewCell {
    var item: TemplateItem?
    var readOnly = true
    
    var signatureTapAction : (()->())?
    
    @IBOutlet weak var signatureImageView: UIImageView!
    @IBOutlet weak var viewNA: UIView!

    
    @IBAction func signatureButtonTapped(_ sender: UIButton) {
        signatureTapAction?()
    }
    
}
