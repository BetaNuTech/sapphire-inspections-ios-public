//
//  PropertyWorkOrdersVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 4/1/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import Alamofire
import SWXMLHash
import MessageUI
import FirebaseFirestore
import SwiftyJSON


enum PropertyWorkOrdersSort: String {
    case createdAtASC = "createdAtASC"
    case createdAtDESC = "createdAtDESC"
    case updatedLast = "updatedLast"
}

struct WorkOrder {
    var ServiceRequestId: String?
    var Origin: String?
    var UnitCode: String?
    var TenantCode: String?
//    var ServiceRequestFullDescription: String?
    var Priority: String?
    var Category: String?
    var HasPermissionToEnter: Bool?
    var ProblemDescriptionNotes: String?
    var TechnicianNotes: String?
    var TenantCaused: Bool?
    var RequestorName: String?
    var RequestorPhoneNumber: String?
    var RequestorEmail: String?
    var ServiceRequestDate: String?
    var CreatedDate: NSNumber?
    var UpdateDate: NSNumber?
    var UpdatedBy: String?
    var CurrentStatus: String?
}

struct WorkOrderAction {
    var order: Int
    var action: WorkOrderActionType
    var value: String
}

enum WorkOrderActionType {
    case call
    case email
}

//<ServiceRequest>
//    <ServiceRequestId>407634</ServiceRequestId>
//    <Origin>OL</Origin>
//    <PropertyCode>villas</PropertyCode>
//    <UnitCode>05-207</UnitCode>
//    <TenantCode>t0152776</TenantCode>
//    <ServiceRequestBriefDescription>Requesting a call back about fixing</ServiceRequestBriefDescription>
//    <ServiceRequestFullDescription>Requesting a call back about fixing my air. I’m on day 3 of heat and I need help ASAP. 901-826-6307</ServiceRequestFullDescription>
//    <Priority>High</Priority>
//    <Category>Miscellaneous</Category>
//    <HasPermissionToEnter>false</HasPermissionToEnter>
//    <ProblemDescriptionNotes>Requesting a call back about fixing my air. I’m on day 3 of heat and I need help ASAP. 901-826-6307</ProblemDescriptionNotes>
//    <TechnicianNotes>Waiting on part</TechnicianNotes>
//    <TenantCaused>false</TenantCaused>
//    <RequestorName>Melanie Smith</RequestorName>
//    <RequestorPhoneNumber>9018266307</RequestorPhoneNumber>
//    <RequestorEmail>macsbaby1@moc.oohay.z</RequestorEmail>
//    <ServiceRequestDate>2020-03-19</ServiceRequestDate>
//    <CreatedBy>gazv_live_service</CreatedBy>
//    <UpdateDate>2020-03-19T17:21:40</UpdateDate>
//    <UpdatedBy>cbedford</UpdatedBy>
//    <CurrentStatus>In Progress</CurrentStatus>
//    <StatusHistory>
//        <Status Type="" TimeStamp="2020-03-19T17:21:40" />
//        <Status Type="In Progress" TimeStamp="2020-03-19T17:21:40" />
//    </StatusHistory>
//</ServiceRequest>

// Extension for AlamoFire, to set HTTP Body with a string
extension String: ParameterEncoding {

    public func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var request = try urlRequest.asURLRequest()
        request.httpBody = data(using: .utf8, allowLossyConversion: false)
        return request
    }

}

class  PropertyWorkOrdersVC: UIViewController, UITableViewDelegate, UITableViewDataSource, MFMailComposeViewControllerDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var sortLabel: UILabel!
    
    var adminCorporateUser = false
    
    var keyProperty: (key: String, property: Property)?
    
    var userListener: ListenerRegistration?

    var workOrders: [WorkOrder] = []

    var filterString = ""
    var filteredWorkOrders: [WorkOrder] = []
    
    var workOrdersFilteredAndSorted: [WorkOrder] = []
    
    var dismissHUD = false
        
    var currentSort = PropertyWorkOrdersSort.createdAtASC

    deinit {
        if let listener = userListener {
            listener.remove()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let code = keyProperty?.property.code {
            self.title = code.uppercased() + " WOs"
        }
        
        // Defaults
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.estimatedRowHeight = 100.0;
        
        // UITable Setup

        setObservers()
        
        getCurrentWorkOrdersFromFirebase()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateWorkOrders()
        updateSortLabel()
    }
    
    // MARK: Actions

    @IBAction func sortButtonTapped(_ sender: UIBarButtonItem) {
        // Change sorting
        switch currentSort {
        case .createdAtASC:
            currentSort = .createdAtDESC
        case .createdAtDESC:
            currentSort = .updatedLast
        case .updatedLast:
            currentSort = .createdAtASC
        }
        
        // Update sort label
        updateSortLabel()

        // Reload Data
        updateWorkOrders()
    }
    
    func updateSortLabel() {
        switch currentSort {
        case .updatedLast:
            sortLabel.text = "Sorted by Last Update"
        case .createdAtASC:
            sortLabel.text = "Sorted by WO Request Date (Oldest)"
        case .createdAtDESC:
            sortLabel.text = "Sorted by WO Request Date (Newest)"
        }
    }
    
    // MARK: Yardi API Call
    
//    func getOpenWorkOrders() {
//        guard let code = keyProperty?.property.code else {
//            print("ERROR: Missing property code for Yardi.")
//            return
//        }
//
//        #if RELEASE_BLUESTONE
//        let database = "gazv_live"
//        let server = "gazv_live"
//        #elseif RELEASE_STAGING
//        let database = "gazv_test"
//        let server = "gazv_test"
//        #else
//        let database = "gazv_test"
//        let server = "gazv_test"
//        #endif
//
//        let propertyCode = code
//        let xmlBody = "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\"><soap:Body><GetServiceRequest_Search xmlns=\"http://tempuri.org/YSI.Interfaces.WebServices/ItfServiceRequests\"><UserName>sapphire</UserName><Password>sapphire</Password><ServerName>\(server)</ServerName><Database>\(database)</Database><Platform>SQL Server</Platform><YardiPropertyId>\(propertyCode)</YardiPropertyId><InterfaceEntity>Sapphire Standard</InterfaceEntity><InterfaceLicense>MIIBEAYJKwYBBAGCN1gDoIIBATCB/gYKKwYBBAGCN1gDAaCB7zCB7AIDAgABAgJoAQICAIAEAAQQgoUIPFloyIysfjl7v+NuRASByIbcmZa2IpfLI/QX12F68yMaCNPYnciO/iVtkg+YaEsZc4OBdCgFzCb5hiZyOlgP5HRVHcB2IUSI3x1cKujMbf5e4psI+0rfdPf8HRsr8jaYf/7gn02JRSfmtjqk04ZAXSsmxXMPLhIcbDnrNZCgQqRigyqczT0ShoM3LJ+cSrmYOxPF/KCqklEXEFyrdvyFnfnu9MFf9nfex/oxd5DCSX+r32VJFaCO76YpnBmh5u+AK947xxF/lZAuPVMxnXuUUOdOfxnGgFIu</InterfaceLicense><OpenOrClosed>Open</OpenOrClosed></GetServiceRequest_Search></soap:Body></soap:Envelope>"
//
//        let headers: HTTPHeaders = [
//            "Content-Type": "text/xml; charset=utf-8",
//            "Content-Length": "\(xmlBody.count)",
//            "SOAPAction": "http://tempuri.org/YSI.Interfaces.WebServices/ItfServiceRequests/GetServiceRequest_Search"
//        ]
//
//        AF.request("https://www.yardiasp14.com/21253beta/Webservices/itfServiceRequests.asmx", method: .post, parameters: nil, encoding: xmlBody, headers: headers)
//            .response { [weak self] (dataResponse) in
//                if let statusCode = dataResponse.response?.statusCode {
//                    if statusCode >= 400 {
//                        print("ERROR: Status Code = \(statusCode)")
//                        self?.showMessagePrompt("ERROR: Status Code = \(statusCode)")
//                    } else if let data = dataResponse.data {
//                        let xml = SWXMLHash.parse(data)
//                        let serviceRequests = xml["soap:Envelope"]["soap:Body"]["GetServiceRequest_SearchResponse"]["GetServiceRequest_SearchResult"]["ServiceRequests"]["ServiceRequest"].all
//                        var newWorkOrders:[WorkOrder] = []
//                        if serviceRequests.count == 1, let error = serviceRequests[0]["ErrorMessages"]["Error"].element?.text {
//                            print("ERROR: \(error)")
//                            self?.showMessagePrompt("ERROR: \(error)")
//                        } else {
//                            for serviceRequest in serviceRequests {
//                                if let workOrder = self?.processServiceRequest(serviceRequest: serviceRequest) {
//                                    newWorkOrders.append(workOrder)
//                                }
//                            }
//                            self?.workOrders = newWorkOrders
//                            self?.updateWorkOrders()
//                        }
//                    }
//                } else if let error = dataResponse.error {
//                    print("ERROR: \(error.localizedDescription)")
//                    self?.showMessagePrompt("ERROR: \(error.localizedDescription)")
//                } else {
//                    print("ERROR: Unknown")
//                    self?.showMessagePrompt("ERROR: Unknown")
//                }
//
//                dismissHUDForConnection()
//        }
//    }
    
    // MARK: Get Residents and Collections (Firebase)
    
    fileprivate func getCurrentWorkOrdersFromFirebase() {
        guard let keyProperty = keyProperty else {
            print("ERROR: keyProperty Data is nil")
            return
        }
        
        if let user = currentUser {
            user.getIDToken { [weak self] (token, error) in
                if let token = token {
                    let headers: HTTPHeaders = [
                        "Authorization": "FB-JWT \(token)",
                        "Content-Type": "application/json"
                    ]
                    
//                    let parameters: Parameters = [:]
                    
                    presentHUDForConnection()
                    AF.request(getYardiWorkOrdersURLString(propertyId: keyProperty.key), method: .get, headers: headers).responseJSON { [weak self] response in
                        DispatchQueue.main.async {
                            // debugPrint(response)
                            
                            if let statusCode = response.response?.statusCode, statusCode >= 200 && statusCode < 300 {
                                if let data = response.data {
                                    let jsonData = JSON(data)
                                    
                                    var newWorkOrders: [WorkOrder] = []
                                    if let workOrdersArray = jsonData["data"].array {
                                        for workOrderData in workOrdersArray {
                                            if let workOrder = self?.processWorkOrder(json: workOrderData) {
                                                newWorkOrders.append(workOrder)
                                            }
                                        }
                                    }
                                    
                                    self?.workOrders = newWorkOrders
                                    self?.updateWorkOrders()
                                    
                                } else {
                                    print("getYardiWorkOrdersURLString - No Data")
                                }
                            } else {
                              let errorMessage = firebaseAPIErrorMessages(data: response.data, error: response.error, statusCode: response.response?.statusCode)
                              let alertController = UIAlertController(title: "Yardi Work Orders Error", message: errorMessage, preferredStyle: .alert)
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
    
//    func processServiceRequest(serviceRequest: XMLIndexer) -> WorkOrder {
//        var workOrder = WorkOrder()
//        workOrder.ServiceRequestId = serviceRequest["ServiceRequestId"].element?.text
//        workOrder.ServiceRequestDate = serviceRequest["ServiceRequestDate"].element?.text
//        workOrder.CurrentStatus = serviceRequest["CurrentStatus"].element?.text
//
//        workOrder.UnitCode = serviceRequest["UnitCode"].element?.text
//        workOrder.TenantCode = serviceRequest["TenantCode"].element?.text
//        workOrder.ServiceRequestFullDescription = serviceRequest["ServiceRequestFullDescription"].element?.text
//        workOrder.Category = serviceRequest["Category"].element?.text
//        workOrder.Priority = serviceRequest["Priority"].element?.text
//        workOrder.ProblemDescriptionNotes = serviceRequest["ProblemDescriptionNotes"].element?.text
//        workOrder.TechnicianNotes = serviceRequest["TechnicianNotes"].element?.text
//        workOrder.HasPermissionToEnter = serviceRequest["HasPermissionToEnter"].element?.text
//        workOrder.TenantCaused = serviceRequest["TenantCaused"].element?.text
//        workOrder.RequestorName = serviceRequest["RequestorName"].element?.text
//        workOrder.RequestorPhoneNumber = serviceRequest["RequestorPhoneNumber"].element?.text
//        workOrder.RequestorEmail = serviceRequest["RequestorEmail"].element?.text
//        workOrder.UpdateDate = serviceRequest["UpdateDate"].element?.text
//        workOrder.UpdatedBy = serviceRequest["UpdatedBy"].element?.text
//        workOrder.Origin = serviceRequest["Origin"].element?.text
//
//        return workOrder
//    }
    
    func processWorkOrder(json: JSON) -> WorkOrder {
        var workOrder = WorkOrder()
        workOrder.ServiceRequestId = json["id"].string
        workOrder.ServiceRequestDate = json["attributes"]["requestDate"].string
        workOrder.CurrentStatus = json["attributes"]["status"].string

        workOrder.UnitCode = json["attributes"]["unit"].string
        workOrder.TenantCode = json["relationships"]["resident"]["data"]["id"].string
//        workOrder.ServiceRequestFullDescription = json["attributes"]["ServiceRequestFullDescription"].element?.text
        workOrder.Category = json["attributes"]["category"].string
        workOrder.Priority = json["attributes"]["priority"].string
        workOrder.ProblemDescriptionNotes = json["attributes"]["problemNotes"].string
        workOrder.TechnicianNotes = json["attributes"]["technicianNotes"].string
        workOrder.HasPermissionToEnter = json["attributes"]["permissionToEnter"].bool
        workOrder.TenantCaused = json["attributes"]["tenantCaused"].bool
        workOrder.RequestorName = json["attributes"]["requestorName"].string
        workOrder.RequestorPhoneNumber = json["attributes"]["requestorPhone"].string
        workOrder.RequestorEmail = json["attributes"]["requestorEmail"].string
        workOrder.CreatedDate = json["attributes"]["createdAt"].number
        workOrder.UpdateDate = json["attributes"]["updatedAt"].number
        workOrder.UpdatedBy = json["attributes"]["updatedBy"].string
        workOrder.Origin = json["attributes"]["origin"].string
        
        return workOrder
    }
    
    func formatWorkOrderData(workOrder: WorkOrder) -> NSAttributedString {

        let bold: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 12), NSAttributedString.Key.foregroundColor: GlobalColors.darkBlue]
        let regular: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12)]

        let string = NSMutableAttributedString(string: "", attributes: regular)

        string.append(NSAttributedString(string: "Unit:", attributes: bold))
        string.append(NSAttributedString(string: " \(workOrder.UnitCode ?? ""), ", attributes: regular))
        string.append(NSAttributedString(string: "Tenant:", attributes: bold))
        string.append(NSAttributedString(string: " \(workOrder.TenantCode ?? "")\n", attributes: regular))
        
        if let updateDateUnixTimestamp = workOrder.UpdateDate?.doubleValue {
            string.append(NSAttributedString(string: "Updated:", attributes: bold))
            let updateDate = Date(timeIntervalSince1970: updateDateUnixTimestamp)
            let formatter = DateFormatter()
            formatter.dateStyle = DateFormatter.Style.short
            formatter.timeStyle = .short
            let dateString = formatter.string(from: updateDate)
            string.append(NSAttributedString(string: " \(dateString), ", attributes: regular))
            string.append(NSAttributedString(string: "By:", attributes: bold))
            string.append(NSAttributedString(string: " \(workOrder.UpdatedBy ?? "")\n", attributes: regular))
        }

        string.append(NSAttributedString(string: "Problem Notes:", attributes: bold))
        string.append(NSAttributedString(string: " \(workOrder.ProblemDescriptionNotes ?? "")\n", attributes: regular))

        string.append(NSAttributedString(string: "Category:", attributes: bold))
        string.append(NSAttributedString(string: " \(workOrder.Category ?? "None"), ", attributes: regular))
        string.append(NSAttributedString(string: "Priority:", attributes: bold))
        string.append(NSAttributedString(string: " \(workOrder.Priority ?? "")\n", attributes: regular))

//        var showProblemNotes = false
//        if let problem = workOrder.ProblemDescriptionNotes {
//            if let desc = workOrder.ServiceRequestFullDescription {
//                if !desc.contains(problem) {
//                    showProblemNotes = true
//                }
//            } else {
//                showProblemNotes = true
//            }
//        }
//        if showProblemNotes {
//            string.append(NSAttributedString(string: "Problem Notes:", attributes: bold))
//            string.append(NSAttributedString(string: " \(workOrder.ProblemDescriptionNotes ?? "")\n", attributes: regular))
//        }

        string.append(NSAttributedString(string: "Technician Notes:", attributes: bold))
        string.append(NSAttributedString(string: " \(workOrder.TechnicianNotes ?? "")\n", attributes: regular))

        string.append(NSAttributedString(string: "Has Permission To Enter:", attributes: bold))
        if let permissionToEnter = workOrder.HasPermissionToEnter {
            string.append(NSAttributedString(string: " \(permissionToEnter ? "YES" : "NO")\n", attributes: regular))
        } else {
            string.append(NSAttributedString(string: " NO\n", attributes: regular))
        }

        string.append(NSAttributedString(string: "Tenant Caused:", attributes: bold))
        if let tenantCaused = workOrder.TenantCaused {
            string.append(NSAttributedString(string: " \(tenantCaused ? "YES" : "NO")\n", attributes: regular))
        } else {
            string.append(NSAttributedString(string: " NO\n", attributes: regular))
        }

        string.append(NSAttributedString(string: "Requestor:", attributes: bold))
        string.append(NSAttributedString(string: " \(workOrder.RequestorName ?? "") (\(workOrder.RequestorEmail ?? "") / \(workOrder.RequestorPhoneNumber ?? ""))\n", attributes: regular))
        
        string.append(NSAttributedString(string: "Origin:", attributes: bold))
        string.append(NSAttributedString(string: " \(workOrder.Origin ?? "")\n", attributes: regular))

        return string
    }

    
    // MARK: UISearchBarDelegate
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        filterString = searchText
        updateWorkOrders()
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
    
    func filterWorkOrders() {
        if filterString != "" {
            filteredWorkOrders = workOrders.filter({  formatWorkOrderData(workOrder: $0).string.lowercased().contains(filterString.lowercased())  })
        } else {
            filteredWorkOrders = workOrders
        }
    }
    
    func updateWorkOrders() {
        
        var workOrdersAfterFilter = workOrders
        
        if filterString != "" {
            filterWorkOrders()
            workOrdersAfterFilter = filteredWorkOrders
        }
        
        let highValue = "9999"
        let lowValue = "-1"
        
        let lowValueDouble: Double = 0.0

        // Apply sorting
        switch currentSort {
        case .updatedLast:
            print("sorted by UpdateDate")
            workOrdersAfterFilter.sort { $0.UpdateDate?.doubleValue ?? lowValueDouble > $1.UpdateDate?.doubleValue ?? lowValueDouble }
        case .createdAtASC:
            print("sorted by createdAtASC")
            workOrdersAfterFilter.sort { $0.ServiceRequestDate ?? highValue <= $1.ServiceRequestDate ?? highValue }
        case .createdAtDESC:
            print("sorted by createdAtDESC")
            workOrdersAfterFilter.sort { $0.ServiceRequestDate ?? lowValue > $1.ServiceRequestDate ?? lowValue }
        }
        
        workOrdersFilteredAndSorted = workOrdersAfterFilter
        tableView.reloadData()
    }
        
    // MARK: - TableView
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return workOrdersFilteredAndSorted.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "workOrderCell")! as! WorkOrderTVCell
        
        let workOrder = workOrdersFilteredAndSorted[indexPath.row]
        
        cell.idCreatedAtLabel.text = " \(workOrder.ServiceRequestId ?? "<no id>")  \(workOrder.ServiceRequestDate ?? "<date missing>") "
        cell.statusLabel.text = " \(workOrder.CurrentStatus ?? "<Unknown Status>") "
        cell.propertiesLabel.attributedText = formatWorkOrderData(workOrder: workOrder)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        
        let workOrder = workOrdersFilteredAndSorted[indexPath.row]

        presentAlertOptionsFor(workOrder: workOrder, indexPath: indexPath)
    }
        
    func presentAlertOptionsFor(workOrder: WorkOrder, indexPath: IndexPath) {
        
        let canDeviceEmail = MFMailComposeViewController.canSendMail()
        var canDeviceCall = false
        if let url = URL(string: "tel://"), UIApplication.shared.canOpenURL(url) {
            canDeviceCall = true
        }
        
        if !canDeviceEmail && !canDeviceCall {
            let alertController = UIAlertController(title: "Unsupported Action", message: "Calling and emailing are not options on this device.", preferredStyle: .alert)
            let okayAction = UIAlertAction(title: "OK", style: .default) { action in
            }
            alertController.addAction(okayAction)
            present(alertController, animated: true, completion: nil)
            return
        }

        // Selection : {WorkOrderAction : Value}
        var selections: [String: WorkOrderAction] = [:]
        var order: Int = 0
        
        let name = workOrder.RequestorName ?? ""
        if let email = workOrder.RequestorEmail, email != "", canDeviceEmail {
            let section = name + " - Email"
            let action = WorkOrderAction(order: order, action: .email, value: email)
            selections[section] = action
            order += 1
        }
        if let phoneNumber = workOrder.RequestorPhoneNumber, canDeviceCall {
            let section = name + " - " + phoneNumber
            let action = WorkOrderAction(order: order, action: .call, value: phoneNumber)
            selections[section] = action
            order += 1
        }
        
        let actionsMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        for selection in selections.sorted(by: { $0.value.order < $1.value.order }) {
            let action = UIAlertAction(title: selection.key, style: .default, handler: { [weak self] (action) in
                self?.handleSelection(action: selection.value)
            })
            actionsMenu.addAction(action)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
            
        })
        actionsMenu.addAction(cancelAction)
        
        // iPad support only
        if let popoverPresentationController = actionsMenu.popoverPresentationController {
            let cellRect = tableView.rectForRow(at: indexPath)
            popoverPresentationController.sourceView = tableView
            popoverPresentationController.sourceRect = cellRect
            popoverPresentationController.permittedArrowDirections  = .any
        }
        
        present(actionsMenu, animated: true, completion: nil)
    }
    
    func handleSelection(action: WorkOrderAction) {
        if action.action == .call {
            if let url = URL(string: "tel://\(action.value.digits)"), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                let alertController = UIAlertController(title: "Phone number unsupported", message: nil, preferredStyle: .alert)
                let okayAction = UIAlertAction(title: "OK", style: .default) { action in
                }
                alertController.addAction(okayAction)
                present(alertController, animated: true, completion: nil)
            }
        } else if action.action == .email {
            if MFMailComposeViewController.canSendMail() {
                let mail = MFMailComposeViewController()
                mail.mailComposeDelegate = self
                mail.setToRecipients([action.value])
                mail.setMessageBody("", isHTML: false)
                present(mail, animated: true)
            } else {
                let alertController = UIAlertController(title: "Email unsupported", message: nil, preferredStyle: .alert)
                let okayAction = UIAlertAction(title: "OK", style: .default) { action in
                }
                alertController.addAction(okayAction)
                present(alertController, animated: true, completion: nil)
            }
        }
    }
        
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }

    
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

    }
 
    
    func setObservers() {
        if let user = currentUser {
            userListener = dbDocumentUserWith(userId: user.uid).addSnapshotListener({ [weak self] (documentSnapshot, error) in
                DispatchQueue.main.async {
                    print("Current User Profile Updated, observed by PropertyWorkOrdersVC")
                    self?.adminCorporateUser = false
                    if let document = documentSnapshot, document.exists {
                        if let profile = Mapper<UserProfile>().map(JSONObject: document.data()), !profile.isDisabled {
                            let admin = profile.admin
                            let corporate = profile.corporate
                            self?.adminCorporateUser = admin || corporate
                        }
                    }
                }
            })
        }
        
        presentHUDForConnection()
    }
}
