//
//  JobsListVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 12/10/21.
//  Copyright © 2021 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import FirebaseFirestore

typealias JobsByState = (state: JobState, keyJobs: [KeyJob])

class JobsListVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    @IBOutlet weak var sortHeaderView: SortSectionHeader!
    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var navBar: UINavigationItem!

    // Inputs
    var keyProperty: (key: String, property: Property)?
    
    var keyJobs: [KeyJob] = []
    var jobsByState: [JobsByState] = []
    var keyJobToEdit: (key: String, job: Job)?
    var userListener: ListenerRegistration?
    var jobsListener: ListenerRegistration?
    
    var filterString = ""
    var filteredJobsByState: [JobsByState] = []
    
    var currentJobsSort: JobsSort = .Title // Default

    var dismissHUD = false

    deinit {
        if let listener = userListener {
            listener.remove()
        }
        if let listener = jobsListener {
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
        let nib = UINib(nibName: "JobSectionHeader", bundle: nil)
        tableView.register(nib, forHeaderFooterViewReuseIdentifier: "JobSectionHeader")
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0.0
        } else {
            // Fallback on earlier versions
        }
        tableView.sectionHeaderHeight = 30.0
        tableView.sectionFooterHeight = 0.0

        
        setObservers()
        
        if let sortStateString = UserDefaults.standard.object(forKey: GlobalConstants.UserDefaults_last_used_jobs_sort), let lastSortState = JobsSort(rawValue:sortStateString as! String) {
            currentJobsSort = lastSortState
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateSortUI()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func addButtonTapped(_ sender: Any) {
        keyJobToEdit = nil
        performSegue(withIdentifier: "showJobEdit", sender: self)
    }
    
    @IBAction func sortButtonTapped(_ sender: AnyObject) {
        switch currentJobsSort {
        case .Title:
            currentJobsSort = .UpdatedAt
        case .UpdatedAt:
            currentJobsSort = .CreatedAt
        case .CreatedAt:
            currentJobsSort = .JobType
        case .JobType:
            currentJobsSort = .Title
        }
        
        sortJobs()
            
        tableView.reloadData()
        
        // Save current as last used, to be reloaded
        UserDefaults.standard.set(currentJobsSort.rawValue, forKey: GlobalConstants.UserDefaults_last_used_properties_sort)
        
        updateSortUI()
    }
    
    func updateSortUI() {
        sortHeaderView.titleLabel.text = "Sorted by \(currentJobsSort.rawValue)"
        sortHeaderView.background.backgroundColor = GlobalColors.veryLightBlue
    }
    
    // MARK: UITableView DataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return jobsByStateAfterFilter().count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return jobsByStateAfterFilter()[section].keyJobs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "jobCell") as? JobTVCell ?? JobTVCell()
        let job = jobsByStateAfterFilter()[indexPath.section].keyJobs[indexPath.row].job
        
        cell.titleLabel?.text = job.title ?? "No Name"
        let formatter = DateFormatter()
        formatter.dateStyle = DateFormatter.Style.short
        formatter.timeStyle = .short
        if let createdAt = job.createdAt {
            cell.createdAtLabel?.text = "created: \(formatter.string(from: createdAt))"
        } else {
            cell.createdAtLabel?.text = "created: ?"
        }
        if let updatedAt = job.updatedAt {
            cell.updatedAtLabel?.text = "updated: \(formatter.string(from: updatedAt))"
        } else {
            cell.updatedAtLabel?.text = "updated: ?"
        }
        cell.jobTypeLabel?.text = job.type ?? "not set"

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
        let cell = self.tableView.dequeueReusableHeaderFooterView(withIdentifier: "JobSectionHeader")
        let header = cell as! JobSectionHeader
        
        switch jobsByStateAfterFilter()[section].state {
        case .open:
            header.titleLabel.text = jobsByStateAfterFilter()[section].state.rawValue.uppercased()
            header.background.backgroundColor = GlobalColors.sectionHeaderPurple
        case .approved:
            header.titleLabel.text = jobsByStateAfterFilter()[section].state.rawValue.uppercased()
            header.background.backgroundColor = GlobalColors.blue
        case .authorized:
            header.titleLabel.text = jobsByStateAfterFilter()[section].state.rawValue.uppercased()
            header.background.backgroundColor = GlobalColors.sectionHeaderGreen
        case .complete:
            header.titleLabel.text = "COMPLETED"
            header.background.backgroundColor = GlobalColors.veryLightBlue
        }
        
        header.titleLabel.textColor = UIColor.white

        return cell
    }
    
//    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
//        let delete = UITableViewRowAction(style: .normal, title: "Delete") { [unowned self] action, index in
//            if indexPath.row < self.jobsByStateAfterFilter()[indexPath.section].keyJobs.count {
//                let keyJob = self.jobsByStateAfterFilter()[indexPath.section].keyJobs[indexPath.row]
//                self.alertForDeleting(keyJob)
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
            let keyJob = jobsByStateAfterFilter()[indexPath.section].keyJobs[indexPath.row]
            keyJobToEdit = keyJob
            performSegue(withIdentifier: "showJobEdit", sender: self)
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    // MARK: UISearchBarDelegate
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        filterString = searchText
        filterJobsByState()
        tableView.reloadData()
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
    
    func filterJobsByState() {
        filteredJobsByState = []
        for keyJobsForState in jobsByState {
            let filteredkeyJobs = keyJobsForState.keyJobs.filter({ ($0.job.title ?? "").lowercased().contains(filterString.lowercased()) })
            let filteredJobsForState = JobsByState(state: keyJobsForState.state, keyJobs: filteredkeyJobs)
            filteredJobsByState.append(filteredJobsForState)
        }
    }
    
    func jobsByStateAfterFilter() -> [JobsByState] {
        if filterString != "" {
            return filteredJobsByState
        } else {
            return jobsByState
        }
    }
    
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showJobEdit" {
            if let vc = segue.destination as? JobEditVC {
                let newKey = dbCollectionJobs().document().documentID
                vc.keyProperty = keyProperty
                if let keyJobToEdit = keyJobToEdit {
                    vc.keyJobToEdit = keyJobToEdit
                } else {
                    vc.keyJobToCreate = (key: newKey, job: Job(JSONString: "{}")!)
                }
                
                keyJobToEdit = nil  // Reset
            }
        }
    }
    
    // MARK: Private Methods
    
    func sortJobs() {
        keyJobs = sortKeyJobs(keyJobs, jobsSort: currentJobsSort)

        var newJobsByState: [JobsByState] = []
        var state = JobState.open
        var keyJobsForState: [KeyJob] = keyJobs.filter({ $0.job.state == state.rawValue })
        var newKeyJobsForState = JobsByState(state: state, keyJobs: keyJobsForState)
        newJobsByState.append(newKeyJobsForState)

        state = JobState.approved
        keyJobsForState = keyJobs.filter({ $0.job.state == state.rawValue })
        newKeyJobsForState = JobsByState(state: state, keyJobs: keyJobsForState)
        newJobsByState.append(newKeyJobsForState)

        state = JobState.authorized
        keyJobsForState = keyJobs.filter({ $0.job.state == state.rawValue })
        newKeyJobsForState = JobsByState(state: state, keyJobs: keyJobsForState)
        newJobsByState.append(newKeyJobsForState)

        state = JobState.complete
        keyJobsForState = keyJobs.filter({ $0.job.state == state.rawValue })
        newKeyJobsForState = JobsByState(state: state, keyJobs: keyJobsForState)
        newJobsByState.append(newKeyJobsForState)
        
        jobsByState = newJobsByState
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
        
        guard let keyProperty = keyProperty else {
            return
        }
                
        dbQueryJobsWith(propertyId: keyProperty.key).getDocuments { [weak self] (querySnapshot, error) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                // Only ran once (setup)
                if let error = error {
                    dismissHUDForConnection()
                    print("Error getting Jobs: \(error)")
                    return
                } else if querySnapshot!.documents.count == 0 {
                    print("Jobs count: 0")
                    dismissHUDForConnection()
                } else {
                    print("Jobs count: \(querySnapshot!.documents.count)")
                    weakSelf.dismissHUD = true
                }
        
                weakSelf.jobsListener = dbQueryJobsWith(propertyId: keyProperty.key).addSnapshotListener { (querySnapshot, error) in
                    DispatchQueue.main.async {
                        guard let weakSelf = self else {
                            return
                        }
                        
                        if weakSelf.dismissHUD {
                            dismissHUDForConnection()
                            weakSelf.dismissHUD = false
                        }
                        
                        guard let snapshot = querySnapshot else {
                            print("Error fetching dbQueryJobsWith snapshot: \(error!)")
                            return
                        }
                        snapshot.documentChanges.forEach { diff in
                            if (diff.type == .added) {
                                let newJob = KeyJob(key: diff.document.documentID, job: Mapper<Job>().map(JSONObject: diff.document.data())!)
                                weakSelf.keyJobs.append(newJob)
                            } else if (diff.type == .modified) {
                                let changedJob: KeyJob = (diff.document.documentID, Mapper<Job>().map(JSONObject: diff.document.data())!)
                                if let index = weakSelf.keyJobs.index( where: { $0.key == diff.document.documentID} ) {
                                    weakSelf.keyJobs.remove(at: index)
                                    weakSelf.keyJobs.insert(changedJob, at: index)
                                }
                            } else if (diff.type == .removed) {
                                if let index = weakSelf.keyJobs.index( where: { $0.key == diff.document.documentID} ) {
                                    weakSelf.keyJobs.remove(at: index)
                                }
                            }
                            
                            weakSelf.sortJobs()
                            weakSelf.filterJobsByState()
                            weakSelf.tableView.reloadData()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: Alerts
    
    func alertForDeleting(_ keyJob: KeyJob) {
        let alertController = UIAlertController(title: "Are you sure you want to delete this job?", message: nil, preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel action"), style: .cancel, handler: { (action) in
            print("Cancel Action")
        })
        let deleteAction = UIAlertAction(title: NSLocalizedString("DELETE", comment: "Delete Action"), style: .destructive, handler: { [weak self] (action) in
            SVProgressHUD.show()
            dbDocumentJobWith(documentId: keyJob.key).delete { (error) in
                DispatchQueue.main.async {
                    if error != nil {
                        self?.showMessagePrompt(error!.localizedDescription)
                    } else {
                        Notifications.sendJobDeletion(job: keyJob.job)
                    }
                    
                    SVProgressHUD.dismiss()
                }
            }
        })
        alertController.addAction(cancelAction)
        alertController.addAction(deleteAction)
        
        present(alertController, animated: true, completion: {})
    }
    
    
}
