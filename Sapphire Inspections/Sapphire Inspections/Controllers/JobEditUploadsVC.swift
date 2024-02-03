//
//  JobEditUploadsVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 2/23/22.
//  Copyright © 2022 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import FirebaseFirestore
import UniformTypeIdentifiers
import MobileCoreServices

class JobEditUploadsVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var navBar: UINavigationItem!
    
    var keyProperty: KeyProperty?
    var keyJobToEdit: KeyJob?
    var areBidUploads = false  // Supporting both Job SOW uploads and Bid Uploads
    var keyBidToEdit: KeyBid? // Should be set if areBidUploads == TRUE
    
    var uploads: [JobOrBidAttachment] = []
    var userListener: ListenerRegistration?
    var jobListener: ListenerRegistration?
    var bidListener: ListenerRegistration?  // areBidUploads == TRUE

    private var previewUploadURL: URL?
    private var previewUploadFilename: String?
    
    private var pickedDocument: UIDocument?

    var dismissHUD = false

    deinit {
        if let listener = userListener {
            listener.remove()
        }
        if let listener = jobListener {
            listener.remove()
        }
        if let listener = bidListener {
            listener.remove()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Defaults
        addButton.isEnabled = false
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.estimatedRowHeight = 72.0;
        tableView.keyboardDismissMode = UIScrollView.KeyboardDismissMode.onDrag
        
        setObservers()
        
        if areBidUploads {
            title = "Vendor Uploads"
        } else {
            title = "SOW Uploads"
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func addButtonTapped(_ sender: Any) {
        // Upload file and metadata
        guard (keyProperty?.key) != nil else {
            print("keyProperty is nil")
            return
        }
        guard (keyJobToEdit?.key) != nil else {
            print("keyJobToEdit is nil")
            return
        }
        if areBidUploads {
            guard (keyBidToEdit?.key) != nil else {
                print("keyBidToEdit is nil")
                return
            }
        }
        
        let supportedTypes = [UTType.image, UTType.text, UTType.plainText, UTType.utf8PlainText,    UTType.utf16ExternalPlainText, UTType.utf16PlainText, UTType.rtf, UTType.pdf, UTType.spreadsheet]
        
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        documentPicker.shouldShowFileExtensions = true
        present(documentPicker, animated: true, completion: nil)
    }
    

    
    
    // MARK: UITableView DataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return uploads.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "jobOrBidUploadCell") as? JobOrBidUploadTVCell ?? JobOrBidUploadTVCell()
        let upload = uploads[indexPath.row]
        
        cell.filenameLabel?.text = upload.name
        
        let formatter = DateFormatter()
        formatter.dateStyle = DateFormatter.Style.short
        formatter.timeStyle = .medium
        if let createdAt = upload.createdAt {
            let createdAtDate = Date(timeIntervalSince1970: Double(createdAt))
            cell.timestampLabel?.text = "Uploaded: \(formatter.string(from: createdAtDate))"
        } else {
            cell.timestampLabel?.text = "Uploaded: <data missing>"
        }

        return cell
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (_, _, completion) in
            guard let weakSelf = self else {
                completion(false)
                return
            }
            if indexPath.row < weakSelf.uploads.count {
                let upload = weakSelf.uploads[indexPath.row]
                weakSelf.alertForDeleting(upload)
                completion(true)
            } else {
                completion(false)
            }
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
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        // This method is for showing slide-to-actions
    }
    
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
        let upload = uploads[indexPath.row]
        if let urlString = upload.url, let url = URL(string: urlString) {
            previewUploadURL = url
            previewUploadFilename = upload.name
            performSegue(withIdentifier: "showJobUpload", sender: nil)
        } else {
            showAlertWithOkayButton(title: "Invalid or Missing URL", message: nil)
        }
        
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showJobUpload" {
            if let vc = segue.destination as? JobUploadPreviewVC {
                if let url = previewUploadURL, let filename = previewUploadFilename {
                    vc.setupWithURL(fileName: filename, url: url)
                    previewUploadURL = nil  // Reset
                    previewUploadFilename = nil  // Reset
                }
            }
        }
    }
    
    // MARK: Private Methods
    
    func updateJobUploads() {
        var newUploads: [JobOrBidAttachment] = []
        if let keyJob = keyJobToEdit, let attachments = keyJob.job.scopeOfWorkAttachments {
            newUploads = attachments
        }
        
        newUploads.sort(by: { $0.createdAt ?? 0 > $1.createdAt ?? 0 } )
        
        uploads = newUploads
    }
    
    func updateBidUploads() {
        var newUploads: [JobOrBidAttachment] = []
        if let keyBid = keyBidToEdit, let attachments = keyBid.bid.attachments {
            newUploads = attachments
        }
        
        newUploads.sort(by: { $0.createdAt ?? 0 > $1.createdAt ?? 0 } )
        
        uploads = newUploads
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
                            weakSelf.addButton.isEnabled = true
                        } else {
                            weakSelf.addButton.isEnabled = false
                        }
                    }
                    
                    dismissHUDForConnection()
                }
            })
        }
           
        if areBidUploads {
            if let bidKey = keyBidToEdit?.key {
                bidListener = dbDocumentBidWith(documentId: bidKey).addSnapshotListener({ [weak self] (documentSnapshot, error) in
                    DispatchQueue.main.async {
                        guard let weakSelf = self else {
                            return
                        }
                        
                        if let document = documentSnapshot, document.exists {
                            print("Bid Updated")
                            let updatedBid: KeyBid = (document.documentID, Mapper<Bid>().map(JSONObject: document.data())!)
                            weakSelf.keyBidToEdit = updatedBid
                            weakSelf.updateBidUploads()
                            weakSelf.tableView.reloadData()
                        } else {
                            print("ERROR: Bid Not Found")
                        }
                    }
                })
                
            }

        } else {
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
                            weakSelf.updateJobUploads()
                            weakSelf.tableView.reloadData()
                        } else {
                            print("ERROR: Job Not Found")
                        }
                    }
                })
                
            }
        }
        
        presentHUDForConnection()
    }
    
    // MARK: Alerts
    
    func alertForDeleting(_ upload: JobOrBidAttachment) {
        let alertController = UIAlertController(title: "Are you sure you want to delete this upload?", message: nil, preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel action"), style: .cancel, handler: { (action) in
            print("Cancel Action")
        })
        alertController.addAction(cancelAction)

        if areBidUploads {
            let deleteAction = UIAlertAction(title: NSLocalizedString("DELETE", comment: "Delete Action"), style: .destructive, handler: { [weak self] (action) in
                guard let bidId = self?.keyBidToEdit?.key else {
                    print("keyBidToEdit is nil")
                    return
                }
                DispatchQueue.main.async {
                    SVProgressHUD.show()
                    upload.remove(fromArray: "attachments", atDocumentRef: dbDocumentBidWith(documentId: bidId))
                    SVProgressHUD.dismiss()
                }
            })
            alertController.addAction(deleteAction)

        } else {
            let deleteAction = UIAlertAction(title: NSLocalizedString("DELETE", comment: "Delete Action"), style: .destructive, handler: { [weak self] (action) in
                guard let jobId = self?.keyJobToEdit?.key else {
                    print("keyJobToEdit is nil")
                    return
                }
                DispatchQueue.main.async {
                    SVProgressHUD.show()
                    upload.remove(fromArray: "scopeOfWorkAttachments", atDocumentRef: dbDocumentJobWith(documentId: jobId))
                    SVProgressHUD.dismiss()
                }
            })
            alertController.addAction(deleteAction)
        }
        
        present(alertController, animated: true, completion: {})
    }
    
    func didPickDocument(document: UIDocument?) {
        if let pickedDoc = document {
            let localFile = pickedDoc.fileURL

            let fileExtension = localFile.pathExtension as CFString
            guard
                let extUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, nil)?.takeUnretainedValue()
            else { return }
            
            guard
                let mimeUTI = UTTypeCopyPreferredTagWithClass(extUTI, kUTTagClassMIMEType)
            else { return }
            
            let fileType = String(mimeUTI.takeRetainedValue())
            print(fileType)
            
            guard let filename = localFile.pathComponents.last else {
                print("filename is nil")
                return
            }
            print(filename)
            
            // Create the file metadata
            let metadata = StorageMetadata()
            metadata.contentType = fileType

            // Upload file and metadata
            guard let propertyId = keyProperty?.key else {
                print("keyProperty is nil")
                return
            }
            guard let jobId = keyJobToEdit?.key else {
                print("keyJobToEdit is nil")
                return
            }
            
            let uniqueFilename = UUID().uuidString + "." + localFile.pathExtension
            var storageRef: StorageReference?
            
            let bidId = keyBidToEdit?.key
            
            if areBidUploads {
                guard let bidId = bidId  else {
                    print("keyBidToEdit is nil")
                    return
                }
                storageRef = storageBidAttachmentsRef(propertyId: propertyId, jobId: jobId, bidId: bidId, filename: uniqueFilename)
            } else {
                storageRef = storageJobAttachmentsRef(propertyId: propertyId, jobId: jobId, filename: uniqueFilename)
            }
            
            guard let storageRef = storageRef else {
                print("storageRef is nil")
                return
            }
            
            let areBidUploads = areBidUploads
            
            print(storageRef.fullPath)
            let uploadTask = storageRef.putFile(from: localFile, metadata: metadata)

            // Listen for state changes, errors, and completion of the upload.
            uploadTask.observe(.resume) { snapshot in
              // Upload resumed, also fires when the upload starts
                print("upload started/resumed")
            }

            uploadTask.observe(.pause) { snapshot in
              // Upload paused
                print("upload paused")
            }

            uploadTask.observe(.progress) { snapshot in
              // Upload reported progress
              let percentComplete = 100.0 * Double(snapshot.progress!.completedUnitCount)
                / Double(snapshot.progress!.totalUnitCount)
                SVProgressHUD.showProgress(Float(percentComplete))
            }

            uploadTask.observe(.success) { snapshot in
              // Upload completed successfully
                SVProgressHUD.show()
                DispatchQueue.main.async {
                    storageRef.getMetadata { metadata, error in
                        guard let metadata = metadata, error == nil else {
                            SVProgressHUD.showError(withStatus: "Metadata missing")
                            return
                        }
                        DispatchQueue.main.async {
                            storageRef.downloadURL { downloadURL, error in
                                guard let downloadURL = downloadURL, error == nil else {
                                    SVProgressHUD.showError(withStatus: "DownloadURL missing")
                                    return
                                }
                                let newJobOrBidAttachmentJSON: [String: Any] = [
                                    "url" : downloadURL.absoluteString,
                                    "storageRef" : metadata.name ?? "",
                                    "createdAt" : Int(metadata.timeCreated?.timeIntervalSince1970 ?? Date().timeIntervalSince1970),
                                    "size" : Int(metadata.size),
                                    "name" : filename,
                                    "type" : fileType
                                ]
                                guard let newJobOrBidAttachment = Mapper<JobOrBidAttachment>().map(JSON: newJobOrBidAttachmentJSON) else {
                                    SVProgressHUD.showError(withStatus: "JobOrBidAttachment model not created")
                                    return
                                }
                                DispatchQueue.main.async {
                                    if areBidUploads {
                                        guard let bidId = bidId  else {
                                            print("keyBidToEdit is nil")
                                            return
                                        }
                                        newJobOrBidAttachment.add(toArray: "attachments", atDocumentRef: dbDocumentBidWith(documentId: bidId))
                                        SVProgressHUD.showSuccess(withStatus: "Upload Successful")

                                    } else {
                                        newJobOrBidAttachment.add(toArray: "scopeOfWorkAttachments", atDocumentRef: dbDocumentJobWith(documentId: jobId))
                                        SVProgressHUD.showSuccess(withStatus: "SOW Upload Successful")
                                    }
                                }
                            }
                        }
                    }
                }
            }

            uploadTask.observe(.failure) { snapshot in
                if let error = snapshot.error as? NSError {
                    switch (StorageErrorCode(rawValue: error.code)!) {
                        case .objectNotFound:
                          // File doesn't exist
                            SVProgressHUD.showError(withStatus: "File doesn't exist")
                          break
                        case .unauthorized:
                          // User doesn't have permission to access file
                            SVProgressHUD.showError(withStatus: "Unauthorized Access")
                          break
                        case .cancelled:
                          // User canceled the upload
                            SVProgressHUD.showError(withStatus: "File Upload Cancelled")
                          break

                        /* ... */

                        case .unknown:
                          // Unknown error occurred, inspect the server response
                            SVProgressHUD.showError(withStatus: "File Upload: Unknown Error")
                          break
                        default:
                          // A separate error occurred. This is a good place to retry the upload.
                            SVProgressHUD.showError(withStatus: "File Upload: Unknown Error")
                          break
                        }
                } else {
                    SVProgressHUD.showError(withStatus: "File Upload Failed: No Error")
                }
            }
        }
    }
}


extension JobEditUploadsVC: UIDocumentPickerDelegate {
        
    /// delegate method, when the user selects a file
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            return
        }
        documentFromURL(pickedURL: url)
        didPickDocument(document: pickedDocument)
    }

    /// delegate method, when the user cancels
    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        didPickDocument(document: nil)
    }

    private func documentFromURL(pickedURL: URL) {
        
        /// start accessing the resource
        let shouldStopAccessing = pickedURL.startAccessingSecurityScopedResource()

        defer {
            if shouldStopAccessing {
                pickedURL.stopAccessingSecurityScopedResource()
            }
        }
        NSFileCoordinator().coordinate(readingItemAt: pickedURL, error: NSErrorPointer.none) { (readURL) in
            let document = UIDocument(fileURL: readURL)
            pickedDocument = document
        }
    }
}
