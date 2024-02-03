//
//  PropertyDetailsVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 7/29/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import ImagePicker
import FirebaseFirestore

class PropertyDetailsVC: UIViewController, UITextFieldDelegate, ImagePickerDelegate {
    
    enum SaveState {
        case idle
        case savingPropertyImage
        case savingBannerImage
        case savingPropertyData
    }

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var scrollViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var pickerView: UIPickerView!
    @IBOutlet weak var pickerContainerView: UIView!
    
    @IBOutlet weak var bannerImageView: UIImageView!
    @IBOutlet weak var addBannerImageButton: UIButton!
    @IBOutlet weak var propertyImageView: UIImageView!
    @IBOutlet weak var addImageButton: UIButton!
    var imageButtonLastPressed: UIButton?

    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var addr1Field: UITextField!
    @IBOutlet weak var addr2Field: UITextField!
    @IBOutlet weak var cityField: UITextField!
    @IBOutlet weak var stateField: UITextField!
    @IBOutlet weak var zipField: UITextField!
    @IBOutlet weak var yearBuiltField: UITextField!
    @IBOutlet weak var numOfUnitsField: UITextField!
    @IBOutlet weak var managerNameField: UITextField!
    @IBOutlet weak var maintSuperName: UITextField!
    @IBOutlet weak var loanTypeField: UITextField!
    @IBOutlet weak var codeField: UITextField!
    @IBOutlet weak var slackChannelField: UITextField!
    @IBOutlet weak var teamButton: UIButton!
    
    @IBOutlet weak var templatesButton: UIButton!
    
    @IBOutlet weak var navItem: UINavigationItem!
    @IBOutlet var saveButton: UIBarButtonItem!
    @IBOutlet var cancelButton: UIBarButtonItem!
    @IBOutlet weak var trelloButton: UIButton!
    
    
    var propertyKey: String?
    var propertyData: Property?
    var newPropertyData: Property?
    var propertyImage: UIImage?
    var bannerImage: UIImage?
    var propertyImageUpdated = false
    var bannerImageUpdated = false

    var newProperty = false
    
    var saveState = SaveState.idle
    
    var pickerData: [(title: String, value: String)] = []
    var pickerSelectedIndex: Int = -1
    var pickerMode = PickerMode.team
    
    var teamId: String?
    
    var teamsListener: ListenerRegistration?
    var keyTeams: [KeyTeam] = []
    
    enum PickerMode {
        case team
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        
        if let listener = teamsListener {
            listener.remove()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self,
                                                         selector: #selector(PropertyDetailsVC.keyboardWillShow(_:)),
                                                         name: UIResponder.keyboardWillShowNotification,
                                                         object: nil)
        NotificationCenter.default.addObserver(self,
                                                         selector: #selector(PropertyDetailsVC.keyboardWillHide(_:)),
                                                         name: UIResponder.keyboardWillHideNotification,
                                                         object: nil)

        if let property = propertyData {
            newPropertyData = Mapper<Property>().map(JSONObject: property.toJSON())
            
            nameField.text = property.name
            addr1Field.text = property.addr1
            addr2Field.text = property.addr2
            cityField.text = property.city
            stateField.text = property.state
            zipField.text = property.zip
            yearBuiltField.text = "\(property.year_built ?? 0)"
            numOfUnitsField.text = "\(property.num_of_units ?? 0)"
            managerNameField.text = property.manager_name
            maintSuperName.text = property.maint_super_name
            loanTypeField.text = property.loan_type
            codeField.text = property.code
            slackChannelField.text = property.slackChannel
            teamId = property.team
            
            if let urlString = property.logoPhotoURL, let url = URL(string: urlString) {
                bannerImageView.sd_setImage(with: url)
                addBannerImageButton.setTitle("", for: UIControl.State())
            } else if let urlString = property.bannerPhotoURL, let url = URL(string: urlString) {
                bannerImageView.sd_setImage(with: url)
                addBannerImageButton.setTitle("", for: UIControl.State())
            }
            
            if let urlString = property.photoURL, let url = URL(string: urlString) {
                propertyImageView.sd_setImage(with: url)
                addImageButton.setTitle("", for: UIControl.State())
            }
        } else {
            print("Created new Property object")
            newPropertyData = Property(JSONString: "{}")
        }
        
        if propertyKey == nil {
            print("Created new Property key")
            propertyKey = dbCollectionProperties().document().documentID
            newProperty = true
        }
        
        if teamId == nil || teamId == "" {
            teamButton.setTitle("Not Set", for: .normal)
        } else {
            teamButton.setTitle("...", for: .normal)
        }
        
        pickerContainerView.isHidden = true
        
        setObservers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        scrollView.contentSize = contentView.bounds.size
        
        if let property = newPropertyData {
            var templatesCount = property.templates.keys.count
            for templateValue in property.templates.values {
                if let fieldValue = templateValue as? FieldValue, fieldValue == FieldValue.delete() {
                    templatesCount -= 1
                }
            }
            let title = "Templates (\(templatesCount))"
            templatesButton.setTitle(title, for: UIControl.State())
        }
        
        updateSaveAndCancelButtons()
        updateTrelloButton()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func updateNewPropertyData() {
        guard newPropertyData != nil else {
            print("ERROR: newPropertyData is nil")
            return
        }
        
        if let text = slackChannelField.text {
            if text != "" && !text.hasPrefix("#") {
                slackChannelField.text = "#" + text
            }
        }
        
        newPropertyData?.name = nameField.text
        newPropertyData?.addr1 = addr1Field.text
        newPropertyData?.addr2 = addr2Field.text
        newPropertyData?.city = cityField.text
        newPropertyData?.state = stateField.text
        newPropertyData?.zip  = zipField.text
        newPropertyData?.year_built = Int(yearBuiltField.text!) ?? 0
        newPropertyData?.num_of_units = Int(numOfUnitsField.text!) ?? 0
        newPropertyData?.manager_name = managerNameField.text
        newPropertyData?.maint_super_name = maintSuperName.text
        newPropertyData?.loan_type = loanTypeField.text
        newPropertyData?.code = codeField.text
        newPropertyData?.slackChannel = slackChannelField.text
        newPropertyData?.team = teamId
    }
    
    func updateSaveAndCancelButtons() {
        var showButtons = false
        
        updateNewPropertyData()
        
        if newProperty {
            showButtons = true
        } else if propertyImageUpdated || bannerImageUpdated {
            showButtons = true
        } else if propertyData?.toJSONString() != newPropertyData?.toJSONString() {
            showButtons = true
        }
        
        if showButtons {
            addSaveButton()
            addCancelButton()
        } else {
            removeSaveButton()
            removeCancelButton()
        }
    }
    
    func updateTrelloButton() {
        trelloButton.isEnabled = !newProperty
        trelloButton.alpha = newProperty ? 0.5 : 1.0
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
    
    @IBAction func teamButtonTapped(_ sender: UIButton) {
        pickerData = []
        pickerData.append((title: "Not Set", value: "nil"))
        var selectedRow = 0
        for (index, keyTeam) in keyTeams.enumerated() {
            pickerData.append((title: keyTeam.team.name ?? "Untitled", value: keyTeam.key))
            if let teamId = teamId, teamId == keyTeam.key {
                selectedRow = index + 1
            }
        }
        
        pickerView.reloadAllComponents()
        pickerView.selectRow(selectedRow, inComponent: 0, animated: true)
        pickerContainerView.isHidden = false
        pickerSelectedIndex = -1
    }
    
    @IBAction func backgroundTapped(_ sender: AnyObject) {
        view.endEditing(true)
        updateSaveAndCancelButtons()
    }
    
    @IBAction func pickerBackgroundTapped(_ sender: Any) {
        pickerContainerView.isHidden = true
        updateSaveAndCancelButtons()
    }
    
    @IBAction func addBannerImageTapped(_ sender: UIButton) {
        imageButtonLastPressed = sender
        
        let imagePickerController = ImagePickerController()
        imagePickerController.modalPresentationStyle = .fullScreen
        imagePickerController.imageLimit = 1
        imagePickerController.delegate = self
        present(imagePickerController, animated: true, completion: nil)
    }
    
    @IBAction func addImageButtonTapped(_ sender: UIButton) {
        imageButtonLastPressed = sender

        let imagePickerController = ImagePickerController()
        imagePickerController.modalPresentationStyle = .fullScreen
        imagePickerController.imageLimit = 1
        imagePickerController.delegate = self
        present(imagePickerController, animated: true, completion: nil)
    }
    
    @IBAction func cancelButtonTapped(_ sender: AnyObject) {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        }
    }
    
    @IBAction func saveButtonTapped(_ sender: AnyObject) {
        view.endEditing(true)
        if !validateFields() {
            return
        }
        
        guard let propertyKey = propertyKey else {
            self.showMessagePrompt("Error occurred when creating new property key")
            return
        }
        
        guard let newPropertyData = newPropertyData else {
            self.showMessagePrompt("Error occurred when creating new property object")
            return
        }
        
        updateNewPropertyData()

        SVProgressHUD.show()

        // Store photo, if one exists
        if propertyImageUpdated, let image = self.propertyImage, let imageData = image.jpegData(compressionQuality: 0.65) {
            saveState = .savingPropertyImage
            let filename = "\(propertyKey).jpg"
            let imageRef = storagePropertyImagesRef.child(filename)
            print("Saving Property Image")
            saveImage(property: newPropertyData, filename: filename, imageRef: imageRef, imageData: imageData)
        } else if bannerImageUpdated, let image = self.bannerImage, let imageData = image.jpegData(compressionQuality: 0.65) {
            saveState = .savingBannerImage
            let filename = "\(propertyKey)_banner.jpg"
            let imageRef = storagePropertyImagesRef.child(filename)
            print("Saving Banner Image")
            saveImage(property: newPropertyData, filename: filename, imageRef: imageRef, imageData: imageData)
        } else {
            saveState = .savingPropertyData
            print("Saving Property Data")
            saveProperty(property: newPropertyData)
        }
    }
    
    func saveImage(property: Property, filename: String, imageRef: StorageReference, imageData: Data) {
        // Upload the file using the property key as the image name
        imageRef.putData(imageData, metadata: nil) { metadata, error in
            if (error != nil) {
                DispatchQueue.main.async { [weak self] in
                    guard let weakSelf = self else {
                        SVProgressHUD.dismiss()
                        return
                    }
                    
                    switch weakSelf.saveState {
                    case .idle:
                        break
                    case .savingPropertyImage:
                        weakSelf.showMessagePrompt("Error occurred when saving property image")
                    case .savingBannerImage:
                        weakSelf.showMessagePrompt("Error occurred when saving banner image")
                    case .savingPropertyData:
                        break
                    }
                    SVProgressHUD.dismiss()
                }
            } else {
                storagePropertyImagesRef.child(filename).downloadURL(completion: { [weak self] (downloadURL, error) in
                    DispatchQueue.main.async { [weak self] in
                        guard let weakSelf = self else {
                            SVProgressHUD.dismiss()
                            return
                        }
                        
                        guard error == nil, let downloadURL = downloadURL else {
                            switch weakSelf.saveState {
                            case .idle:
                                break
                            case .savingPropertyImage:
                                weakSelf.showMessagePrompt("Error occurred when requesting saved property image URL")
                            case .savingBannerImage:
                                weakSelf.showMessagePrompt("Error occurred when requesting saved banner image URL")
                            case .savingPropertyData:
                                break
                            }
                            SVProgressHUD.dismiss()
                            return
                        }
                    
                        switch weakSelf.saveState {
                        case .idle:
                            break
                        case .savingPropertyImage:
                            // Metadata contains file metadata such as size, content-type, and download URL.
                            property.photoURL = downloadURL.absoluteString
                            property.photoName = metadata!.name
                            weakSelf.propertyImageUpdated = false
                            if weakSelf.bannerImageUpdated {
                                if let propertyKey = weakSelf.propertyKey,
                                    let image = weakSelf.bannerImage,
                                    let imageData = image.jpegData(compressionQuality: 0.65) {
                                    
                                    let filename = "\(propertyKey)_banner.jpg"
                                    let imageRef = storagePropertyImagesRef.child(filename)
                                    weakSelf.saveState = .savingBannerImage
                                    weakSelf.saveImage(property: property, filename: filename, imageRef: imageRef, imageData: imageData)
                                    return
                                }
                            }
                        case .savingBannerImage:
                            // Metadata contains file metadata such as size, content-type, and download URL.
                            property.logoPhotoURL = downloadURL.absoluteString
                            property.logoName = metadata!.name
                            weakSelf.bannerImageUpdated = false
                        case .savingPropertyData:
                            break
                        }
                        
                        // else save property data
                        weakSelf.saveState = .savingPropertyData
                        weakSelf.saveProperty(property: property)
                    }
                })
            }
        }
    }
    
    func sendMessages() {
        guard let newPropertyData = newPropertyData else {
            print("Error sending message, missing property data")
            return
        }
        if newProperty {
            newProperty = false
            Notifications.sendPropertyCreation(newProperty: newPropertyData)
        } else {
            guard let prevPropertyData = propertyData else {
                print("Error sending message, missing property data")
                return
            }
            
            if prevPropertyData.toJSONString() != newPropertyData.toJSONString() {
                Notifications.sendPropertyUpdate(prevProperty: prevPropertyData, newProperty: newPropertyData)
            }
        }
        
        close()
    }
    
    func close() {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        }
    }
    
    func updateTeamButton() {
        if teamId == nil || teamId == "" {
            teamButton.setTitle("Not Set", for: .normal)
        } else {
            var teamFound = false
            for keyTeam in keyTeams {
                if teamId == keyTeam.key {
                    teamButton.setTitle(keyTeam.team.name, for: .normal)
                    teamFound = true
                    break
                }
            }
            
            if !teamFound {
                teamButton.setTitle("Not Set", for: .normal)
            }
        }
    }
    
    // MARK: UITextField Delegates
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.layoutIfNeeded()  // Fixes iOS 9 glitch
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case nameField:
            addr1Field.becomeFirstResponder()
        case addr1Field:
            addr2Field.becomeFirstResponder()
        case addr2Field:
            cityField.becomeFirstResponder()
        case cityField:
            stateField.becomeFirstResponder()
        case stateField:
            zipField.becomeFirstResponder()
        case zipField:
            yearBuiltField.becomeFirstResponder()
        case yearBuiltField:
            numOfUnitsField.becomeFirstResponder()
        case numOfUnitsField:
            managerNameField.becomeFirstResponder()
        case managerNameField:
            maintSuperName.becomeFirstResponder()
        case maintSuperName:
            loanTypeField.becomeFirstResponder()
        case loanTypeField:
            codeField.becomeFirstResponder()
        case codeField:
            slackChannelField.becomeFirstResponder()
        default:
            view.endEditing(true)
        }
        
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let newString = (textField.text! as NSString).replacingCharacters(in: range, with: string)
        textField.text = newString
        
        updateSaveAndCancelButtons()
        
        return false
    }
    
    // MARK: Keyboard
    
    @objc func keyboardWillShow(_ note: Notification) {
        let keyboardData = keyboardInfoFromNotification(note)
        let offsetHeight = keyboardData.endFrame.size.height
        scrollView.layoutIfNeeded()
        UIView.animate(withDuration: keyboardData.animationDuration,
                                   delay: 0,
                                   options: keyboardData.animationCurve,
                                   animations: {
                                    self.scrollViewBottomConstraint.constant = offsetHeight
                                    self.scrollView.layoutIfNeeded()
            },
                                   completion: nil)
    }
    
    @objc func keyboardWillHide(_ note: Notification) {
        let keyboardData = keyboardInfoFromNotification(note)
        UIView.animate(withDuration: keyboardData.animationDuration,
                                   delay: 0,
                                   options: keyboardData.animationCurve,
                                   animations: {
                                    self.scrollViewBottomConstraint.constant = 0
                                    self.scrollView.layoutIfNeeded()
            }, completion: nil)
    }

    // MARK: ImagePicker Delegates
    
    public func wrapperDidPress(_ imagePicker: ImagePickerController, images: [UIImage]) {
        print("wrapperDidPress")
    }
    
    public func doneButtonDidPress(_ imagePicker: ImagePickerController, images: [UIImage]) {
        if images.count > 0 {
            if imageButtonLastPressed == addImageButton {
                propertyImage = images.first
                propertyImageView.image = propertyImage
                addImageButton.setTitle("", for: UIControl.State())
                propertyImageUpdated = true
            } else if imageButtonLastPressed == addBannerImageButton {
                bannerImage = images.first
                bannerImageView.image = bannerImage
                addBannerImageButton.setTitle("", for: UIControl.State())
                bannerImageUpdated = true
            }

        }
        
        dismiss(animated: true, completion: nil)
    }
    
    public func cancelButtonDidPress(_ imagePicker: ImagePickerController) {
        print("cancelButtonDidPress")
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: Private Methods
    
    func validateFields() -> Bool {
        if nameField.text == "" {
            showMessagePrompt("Name required")
            return false
        }
        
        return true
    }
    
    func saveProperty(property: Property) {
        databaseUpdateProperty(key: propertyKey!, property: property, completion: { [weak self] (error) in
            DispatchQueue.main.async {
                SVProgressHUD.dismiss()
                if error != nil {
                    self?.showMessagePrompt("Error occurred when saving property details")
                } else {
                    self?.sendMessages()
                    self?.updateTrelloButton()
                }
                
                self?.saveState = .idle
            }
        })
    }
    
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "templatesSelect" {
            if let vc = segue.destination as? TemplatesSelectVC {
                vc.keyPropertyToEdit = (key: propertyKey!, property: newPropertyData!)
            }
        } else if segue.identifier == "propertyTrelloEdit" {
            if let vc = segue.destination as? PropertyEditTrelloVC {
                vc.keyPropertyTrello = (key: propertyKey!, propertyTrello: nil)
                if let key = propertyKey, let property = propertyData {
                    vc.keyProperty = (key: key, property: property)
                }
            }
        }
    }
    
    func setObservers() {
        teamsListener = dbCollectionTeams().addSnapshotListener { [weak self] (querySnapshot, error) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }

                guard let documents = querySnapshot?.documents else {
                    print("Error fetching documents: \(error!)")
                    weakSelf.keyTeams = []
                    weakSelf.updateTeamButton()
                    return
                }
                
                var newKeyTeams: [KeyTeam] = []
                for document in documents {
                    let newKeyTeam: KeyTeam = (document.documentID, Mapper<Team>().map(JSONObject: document.data())!)
                    newKeyTeams.append(newKeyTeam)
                }
                newKeyTeams.sort( by: { $0.team.name?.lowercased() ?? "" < $1.team.name?.lowercased() ?? "" } )
                weakSelf.keyTeams = newKeyTeams
                weakSelf.updateTeamButton()
            }
        }
        
    }
}

extension PropertyDetailsVC: UIPickerViewDelegate, UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerData.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        
        return pickerData[row].title
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        pickerSelectedIndex = row
        
        switch pickerMode {
        case .team:
            if pickerSelectedIndex < pickerData.count && pickerSelectedIndex >= 0 {
                teamId = pickerData[pickerSelectedIndex].value
                if teamId == "nil" {
                    teamId = ""
                }
                updateTeamButton()
                updateSaveAndCancelButtons()
            }
        }
    }
}
