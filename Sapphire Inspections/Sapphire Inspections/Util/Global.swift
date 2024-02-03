//
//  Global.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 7/26/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import FirebaseFirestore
import SwiftyJSON

let AWSS3URL = "https://sapphireinspections.s3.amazonaws.com"
let AWSS3Bucket = "sapphireinspections"

#if RELEASE_BLUESTONE
let webAppBaseURL = "https://bluestone-prop.sapphire-standard.com"
#elseif RELEASE_STAGING
let webAppBaseURL = "https://staging.sapphire-standard.com"
#else
let webAppBaseURL = "https://staging.sapphire-standard.com"
#endif


#if RELEASE_BLUESTONE
let cloundFunctionBaseURL = "https://us-central1-sapphire-inspections.cloudfunctions.net"
#elseif RELEASE_STAGING
let cloundFunctionBaseURL = "https://us-central1-sapphire-inspections-staging.cloudfunctions.net"
#else
let cloundFunctionBaseURL = "https://us-central1-sapphire-inspections-staging.cloudfunctions.net"
#endif

#if RELEASE_BLUESTONE
let cobaltBaseURL: String? = "https://cobalt-production.herokuapp.com/collections_by_tenant_details"
#elseif RELEASE_STAGING
let cobaltBaseURL: String? = "https://cobalt-dev.herokuapp.com/collections_by_tenant_details"
#else
let cobaltBaseURL: String? = "https://cobalt-dev.herokuapp.com/collections_by_tenant_details"
#endif

// Firebase API URLs
// ------
let versionsURLString = "\(cloundFunctionBaseURL)/api/v0/versions"
let setSlackAuthorizorURLString = "\(cloundFunctionBaseURL)/api/v0/integrations/slack/authorization"
let setTrelloAuthorizorURLString = "\(cloundFunctionBaseURL)/api/v0/integrations/trello/authorization"
let getTrelloBoardsURLString = "\(cloundFunctionBaseURL)/api/v0/integrations/trello/boards"
let getTrelloListsBaseURLString = "\(cloundFunctionBaseURL)/api/v0/integrations/trello/boards"
let createTrelloCardURLString = "\(cloundFunctionBaseURL)/api/v0/deficiencies"
let reassignInspectionsPropertyURLString = "\(cloundFunctionBaseURL)/api/v0/inspections"
let inspectionsURLString = "\(cloundFunctionBaseURL)/api/v0/inspections"
let propertiesURLString = "\(cloundFunctionBaseURL)/api/v0/properties"

func getTrelloListsURLString(boardId: String) -> String {
    return "\(getTrelloListsBaseURLString)/\(boardId)/lists"
}

func createTrelloCardURLString(deficientItemId: String) -> String {
    return "\(createTrelloCardURLString)/\(deficientItemId)/trello/card"
}

func getYardiResidentsURLString(propertyId: String) -> String {
    return "\(propertiesURLString)/\(propertyId)/yardi/residents"
}

func getYardiWorkOrdersURLString(propertyId: String) -> String {
    return "\(propertiesURLString)/\(propertyId)/yardi/work-orders"
}

func createNewJobURLString(propertyId: String) -> String {
    return "\(propertiesURLString)/\(propertyId)/jobs"
}

func updateJobURLString(propertyId: String, jobId: String) -> String {
    return "\(propertiesURLString)/\(propertyId)/jobs/\(jobId)"
}

func createNewBidURLString(propertyId: String, jobId: String) -> String {
    return "\(propertiesURLString)/\(propertyId)/jobs/\(jobId)/bids"
}

func updateBidURLString(propertyId: String, jobId: String, bidId: String) -> String {
    // TODO: Confirm Endpoint
    return "\(propertiesURLString)/\(propertyId)/jobs/\(jobId)/bids/\(bidId)"
}

func cobaltGetCollectionsByTenant() -> String? {
    if let cobaltBaseURL = cobaltBaseURL {
        return "\(cobaltBaseURL)/json_api"
    } else {
        return nil
    }
}

func firebaseAPIErrorMessages(data: Data?, error: Error?, statusCode: Int?) -> String? {
    var errorString: String?
    
    let json = JSON(data ?? Data())
    
    if let errors = json["errors"].array {
        for error in errors {
            if let detail = error["detail"].string {
                switch errorString {
                case nil:
                    errorString = detail
                default:
                    errorString! += ", \(detail)"
                }
            }
        }
    } else if let error = error {
        errorString = error.localizedDescription
    } else if let statusCode = statusCode {
        errorString = "\(statusCode): Unknown Error"
    }
    
    return errorString
}


var incognitoMode = false

typealias FIRDatabaseCompletionBlock = (_ error: Error?) -> Void

extension Notification.Name {
    static let FirebaseConnectionUpdate = Notification.Name("FirebaseConnectionUpdate")
    static let OfflinePhotoUploaded = Notification.Name("OfflinePhotoUploaded")
    static let UserProfileUpdated = Notification.Name("UserProfileUpdated")
    static let TemplateSectionsUpdated = Notification.Name("TemplateSectionsUpdated")
}

struct GlobalConstants {
    // NSUserDefaults
    static let UserDefaults_last_used_properties_sort = "UserDefaults_last_used_properties_sort"
    static let UserDefaults_last_used_inspections_sort = "UserDefaults_last_used_inspections_sort"
    static let UserDefaults_last_used_completed_inspections_sort = "UserDefaults_last_used_completed_inspections_sort"
    static let UserDefaults_last_used_jobs_sort = "UserDefaults_last_used_jobs_sort"

}

struct GlobalColors {
    static let darkBlue      = UIColor(red: 3/255.0, green: 44/255.0, blue: 166/255.0, alpha: 1.0)
    static let blue          = UIColor(red: 48/255.0, green: 113/255.0, blue: 242/255.0, alpha: 1.0)
    static let lightBlue     = UIColor(red: 82/255.0, green: 152/255.0, blue: 242/255.0, alpha: 1.0)
    static let veryLightBlue = UIColor(red: 148/255.0, green: 189/255.0, blue: 242/255.0, alpha: 1.0)
    static let white         = UIColor(red: 242/255.0, green: 242/255.0, blue: 242/255.0, alpha: 1.0)
    static let selectedBlue  = UIColor(red: 21/255.0, green: 0/255.0, blue: 255/255.0, alpha: 1.0)
    static let selectedBlack = UIColor(red: 0/255.0, green: 0/255.0, blue: 0/255.0, alpha: 1.0)
    static let selectedRed   = UIColor(red: 255/255.0, green: 0/255.0, blue: 0/255.0, alpha: 1.0)
    static let unselectedGrey = UIColor(red: 204/255.0, green: 204/255.0, blue: 204/255.0, alpha: 1.0)
    static let debugOrange    = UIColor(red: 255/255.0, green: 131/255.0, blue: 94/255.0, alpha: 1.0)
    static let itemDueDateRed    = UIColor(red: 255/255.0, green: 38/255.0, blue: 0/255.0, alpha: 1.0)
    static let itemDueDatePendingBlue    = UIColor(red: 64/255.0, green: 128/255.0, blue: 200/255.0, alpha: 1.0)
    static let itemCompletedGreen    = UIColor(red: 0/255.0, green: 143/255.0, blue: 0/255.0, alpha: 1.0)
    static let sectionHeaderPurple   = UIColor(red: 83/255.0, green: 27/255.0, blue: 147/255.0, alpha: 1.0)
    static let sectionHeaderGreen   = UIColor(red: 5/255.0, green: 174/255.0, blue: 167/255.0, alpha: 1.0)
    static let sectionHeaderRed      = UIColor(red: 148/255.0, green: 17/255.0, blue: 0/255.0, alpha: 1.0)
    static let sectionHeaderBlack    = UIColor(red: 0/255.0, green: 0/255.0, blue: 0/255.0, alpha: 1.0)
    static let sectionHeaderBlue    = UIColor(red: 39/255.0, green: 92/255.0, blue: 194/255.0, alpha: 1.0)
    static let sectionHeaderBrightRed    = UIColor(red: 234/255.0, green: 46/255.0, blue: 73/255.0, alpha: 1.0)
    static let sectionHeaderOrange    = UIColor(red: 254/255.0, green: 127/255.0, blue: 1/255.0, alpha: 1.0)
    static let incompleteItemColor   = UIColor(displayP3Red: 1.0, green: 230/255.0, blue: 230/255.0, alpha: 1.0)
    static let trelloBlue            = UIColor(red: 0/255.0, green: 121/255.0, blue: 191/255.0, alpha: 1.0)
}

func presentHUDForConnection() {
    if FIRConnection.connected() {
        SVProgressHUD.show()
    }
}

func dismissHUDForConnection() {
    if FIRConnection.connected() {
        if SVProgressHUD.isVisible() {
            SVProgressHUD.dismiss()
        }
    } else {
        if !SVProgressHUD.isVisible() {
            FIRConnection.showOfflineDataHUD()
        }
    }
}


func firebaseConnectionColor() -> UIColor {
    if FIRConnection.connected() {
        #if RELEASE_BLUESTONE
        return GlobalColors.white
        #elseif RELEASE_STAGING
        return GlobalColors.debugOrange
        #else
        return GlobalColors.debugOrange
        #endif
    } else {
        return UIColor.black
    }
}

func firebaseConnectionAlpha() -> CGFloat {
    if FIRConnection.connected() {
        #if RELEASE_BLUESTONE
        return 1.0
        #elseif RELEASE_STAGING
        return 0.5
        #else
        return 0.5
        #endif
    } else {
        return 0.5
    }
}

// Current X.Y.Z >= Required X.Y.Z
func doesCurrentVersionMeetRequirement(requiredVersion: String) -> Bool {
    if requiredVersion == "" {
        return true
    }
    
    var isCurrentGreaterThan = false
    var isCurrentEqualTo = false
    if let currentVersion = Bundle.main.releaseVersionNumber {
        let currentVersionSegments = currentVersion.components(separatedBy: ".")
        let requiredVersionSegments = requiredVersion.components(separatedBy: ".")
        if currentVersionSegments.count > 0 && requiredVersionSegments.count > 0 {
            // X >= X
            isCurrentGreaterThan = (Int(currentVersionSegments[0]) ?? 0 > Int(requiredVersionSegments[0]) ?? 0)
            isCurrentEqualTo = (Int(currentVersionSegments[0]) ?? 0 == Int(requiredVersionSegments[0]) ?? 0)
            if isCurrentEqualTo && currentVersionSegments.count > 1 && requiredVersionSegments.count > 1 {
                // Y >= Y
                isCurrentGreaterThan = (Int(currentVersionSegments[1]) ?? 0 > Int(requiredVersionSegments[1]) ?? 0)
                isCurrentEqualTo = (Int(currentVersionSegments[1]) ?? 0 == Int(requiredVersionSegments[1]) ?? 0)
                if isCurrentEqualTo && currentVersionSegments.count > 2 && requiredVersionSegments.count > 2 {
                    // Z >= Z
                    isCurrentGreaterThan = (Int(currentVersionSegments[2]) ?? 0 > Int(requiredVersionSegments[2]) ?? 0)
                    isCurrentEqualTo = (Int(currentVersionSegments[2]) ?? 0 == Int(requiredVersionSegments[2]) ?? 0)
                }
            }
        }
    }
    
    return isCurrentEqualTo || isCurrentGreaterThan
}

var currentUser: User? {
    return Auth.auth().currentUser
}

var userAgent: String {
    return "iOS Version \(Bundle.main.releaseVersionNumber ?? "?") (\(Bundle.main.buildVersionNumber ?? "?"))"
}

var currentOrganizationTrello: OrganizationTrello?
var currentOrganizationSlack: OrganizationSlack?

enum EnumUserRole {
    case none
    case admin
    case corporate
    case team
    case property
}

func userRole(_ keyUser: (key: String, user: UserProfile)) -> EnumUserRole {
    let user = keyUser.user
    let admin = user.admin
    let corporate = user.corporate
    let team = user.teams.count > 0
    let property = user.properties.count > 0

    if admin {
        return .admin
    }
    if corporate {
        return .corporate
    }
    if team {
        return .team
    }
    if property {
        return .property
    }
    
    return .none
}

var latestVersionAvailable = ""
var requiredVersionForcesUpdate = false

// MARK: Database References

var currentUserProfile: UserProfile?

var ref: DatabaseReference! {
     return Database.database().reference()
}
let db = Firestore.firestore()

var connectedRef: DatabaseReference! {
    return ref.child(".info/connected")
}


func dbCollectionUsers() -> CollectionReference {
    return db.collection("users")
}
func dbDocumentUserWith(userId: String) -> DocumentReference {
    return db.collection("users").document(userId)
}


func dbCollectionInspections() -> CollectionReference {
    return db.collection("inspections")
}
func dbQueryInspectionsWith(propertyId: String) -> Query {
    return db.collection("inspections").whereField("property", isEqualTo: propertyId)
}
func dbDocumentInspectionWith(documentId: String) -> DocumentReference {
    return db.collection("inspections").document(documentId)
}


func dbQueryDeficiencesWith(propertyId: String) -> Query {
    return db.collection("deficiencies").whereField("property", isEqualTo: propertyId)
}
func dbDocumentDeficientItemWith(documentId: String) -> DocumentReference {
    return db.collection("deficiencies").document(documentId)
}
func dbCollectionDeficiencies() -> CollectionReference {
    return db.collection("deficiencies")
}


func dbCollectionProperties() -> CollectionReference {
    return db.collection("properties")
}
func dbDocumentPropertyWith(documentId: String) -> DocumentReference {
    return db.collection("properties").document(documentId)
}


func dbCollectionTeams() -> CollectionReference {
    return db.collection("teams")
}
func dbDocumentTeamWith(documentId: String) -> DocumentReference {
    return db.collection("teams").document(documentId)
}


func dbCollectionTemplates() -> CollectionReference {
    return db.collection("templates")
}
func dbQueryTemplatesWith(propertyId: String) -> Query {
    return db.collection("templates").whereField("properties", arrayContains: propertyId)
}
func dbDocumentTemplateWith(documentId: String) -> DocumentReference {
    return db.collection("templates").document(documentId)
}


func dbCollectionTemplateCategories() -> CollectionReference {
    return db.collection("templateCategories")
}
func dbDocumentTemplateCategoryWith(documentId: String) -> DocumentReference {
    return db.collection("templateCategories").document(documentId)
}

func dbCollectionJobs() -> CollectionReference {
    return db.collection("jobs")
}
func dbQueryJobsWith(propertyId: String) -> Query {
    let propertyRef = db.collection("properties").document(propertyId)
    return db.collection("jobs").whereField("property", isEqualTo: propertyRef)
}
func dbDocumentJobWith(documentId: String) -> DocumentReference {
    return db.collection("jobs").document(documentId)
}

func dbQueryBidsWith(jobId: String) -> Query {
    let jobRef = db.collection("jobs").document(jobId)
    return db.collection("bids").whereField("job", isEqualTo: jobRef)
}
func dbDocumentBidWith(documentId: String) -> DocumentReference {
    return db.collection("bids").document(documentId)
}


var registrationTokensRef: DatabaseReference! {
    return ref.child("registrationTokens")
}


func dbDocumentIntegrationTrelloPropertyWith(propertyId: String) -> DocumentReference {
    return db.collection("integrations").document("trello-\(propertyId)")
}


func dbDocumentIntegrationOrganizationTrello() -> DocumentReference {
    return db.collection("integrations").document("trello")
}


func dbDocumentIntegrationOrganizationSlack() -> DocumentReference {
    return db.collection("integrations").document("slack")
}


func dbCollectionNotifications() -> CollectionReference {
    return db.collection("notifications")
}

// MARK: Storage References

var storageRef: StorageReference! {
    return Storage.storage().reference()
}

var storagePropertyImagesRef: StorageReference! {
    return storageRef.child("propertyImages")
}

var storageInspectionItemImagesRef: StorageReference! {
    return storageRef.child("inspectionItemImages")
}

var storageDeficientItemImagesRef: StorageReference! {
    return storageRef.child("deficientItemImages")
}

var storageInspectionReportsRef: StorageReference! {
    return storageRef.child("inspectionReports")
}

func storageJobAttachmentsRef(propertyId: String, jobId: String, filename: String) -> StorageReference! {
    return storageRef.child("properties").child(propertyId).child("jobs").child(jobId).child("attachments").child(filename)
}
func storageBidAttachmentsRef(propertyId: String, jobId: String, bidId: String, filename: String) -> StorageReference! {
    return storageRef.child("properties").child(propertyId).child("jobs").child(jobId).child("bids").child(bidId).child("attachments").child(filename)
}

// MARK: Properties

enum PropertiesSort: String {
    case Name = "Name"
    case City = "City"
    case State = "State"
    case LastInspectionDate = "Last Entry Date"
    case LastInspectionScore = "Last Entry Score"
}

func sortKeyProperties(_ keyProperties: [(key: String, property: Property)], propertiesSort: PropertiesSort) -> [(key: String, property: Property)] {
    switch propertiesSort {
    case .Name:
        return keyProperties.sorted(by: { $0.property.name?.lowercased() ?? "" < $1.property.name?.lowercased() ?? "" })
    case .City:
        return keyProperties.sorted(by: { $0.property.city?.lowercased() ?? "" < $1.property.city?.lowercased() ?? "" })
    case .State:
        return keyProperties.sorted(by: { $0.property.state?.lowercased() ?? "" < $1.property.state?.lowercased() ?? "" })
    case .LastInspectionDate:
        return keyProperties.sorted(by: { $0.property.lastInspectionDate?.timeIntervalSince1970 ?? 0 > $1.property.lastInspectionDate?.timeIntervalSince1970 ?? 0 })
    case .LastInspectionScore:
        return keyProperties.sorted(by: { $0.property.lastInspectionScore ?? 0 > $1.property.lastInspectionScore ?? 0})
    }    
}

func databaseUpdateProperty(key: String, property: Property, completion: @escaping FIRDatabaseCompletionBlock) {
    var post = property.toJSON()
    post = Property.updateJSONToExcludeReadOnlyValues(json: post)
    
    dbDocumentPropertyWith(documentId: key).setData(post, merge: true) { (error) in
        completion(error)
    }
}

func databaseUpdateTeam(key: String, team: Team, completion: @escaping FIRDatabaseCompletionBlock) {
    var post = team.toJSON()
    post = Team.updateJSONToExcludeReadOnlyValues(json: post)

    dbDocumentTeamWith(documentId: key).setData(post, merge: true) { (error) in
        completion(error)
    }
}

// MARK: Inspections

var pauseUploadingPhotos = false

enum InspectionsSort: String {
    case InspectorName = "CreatorName"
    case CreationDate = "CreationDate"
    case LastUpdateDate = "LastUpdateDate"
    case Score = "Score"
    case Category = "Category"
}

func sortKeyInspections(_ keyInspections: [(key: String, inspection: Inspection)], inspectionsSort: InspectionsSort) -> [(key: String, inspection: Inspection)] {
    switch inspectionsSort {
    case .InspectorName:
        return keyInspections.sorted(by: { $0.inspection.inspectorName?.lowercased() ?? "" < $1.inspection.inspectorName?.lowercased() ?? "" })
    case .CreationDate:
        return keyInspections.sorted(by: { $0.inspection.creationDate?.timeIntervalSince1970 ?? 0 > $1.inspection.creationDate?.timeIntervalSince1970 ?? 0})
    case .LastUpdateDate:
        return keyInspections.sorted(by: { $0.inspection.updatedLastDate?.timeIntervalSince1970 ?? 0 > $1.inspection.updatedLastDate?.timeIntervalSince1970 ?? 0})
    case .Score:
        let sortedKeyInspections = keyInspections.sorted(by: { $0.inspection.score > $1.inspection.score })
        return sortedKeyInspections.sorted(by: {
            let firstComplete = $0.inspection.itemsCompleted == $0.inspection.totalItems
            let secondComplete = $1.inspection.itemsCompleted == $1.inspection.totalItems
            return firstComplete && !secondComplete
        })
//    case .DeficienciesExist:
//        return keyInspections.sorted(by: { $0.inspection.deficienciesExist && !$1.inspection.deficienciesExist })
    case .Category:
        return keyInspections.sorted(by: { $0.inspection.templateCategory ?? "" < $1.inspection.templateCategory ?? "" })
    }
}

// MARK: Jobs

enum JobsSort: String {
    case Title = "Title"
    case UpdatedAt = "Updated At"
    case CreatedAt = "Created At"
    case JobType = "Type"
}

func sortKeyJobs(_ keyJobs: [(key: String, job: Job)], jobsSort: JobsSort) -> [(key: String, job: Job)] {
    switch jobsSort {
    case .Title:
        return keyJobs.sorted(by: { $0.job.title?.lowercased() ?? "" < $1.job.title?.lowercased() ?? "" })
    case .UpdatedAt:
        return keyJobs.sorted(by: { $0.job.updatedAt?.timeIntervalSince1970 ?? 0 > $1.job.updatedAt?.timeIntervalSince1970 ?? 0 })
    case .CreatedAt:
        return keyJobs.sorted(by: { $0.job.createdAt?.timeIntervalSince1970 ?? 0 > $1.job.createdAt?.timeIntervalSince1970 ?? 0 })
    case .JobType:
        return keyJobs.sorted(by: { $0.job.type ?? "" < $1.job.type ?? "" })
    }
}

enum BidsSort: String {
    case vendor = "Vendor"
    case updatedAt = "Updated At"
}

func sortKeyBids(_ keyBids: [KeyBid], bidsSort: BidsSort) -> [KeyBid] {
    switch bidsSort {
    case .vendor:
        return keyBids.sorted(by: { $0.bid.vendor?.lowercased() ?? "" < $1.bid.vendor?.lowercased() ?? "" })
    case .updatedAt:
        return keyBids.sorted(by: { $0.bid.updatedAt?.timeIntervalSince1970 ?? 0 > $1.bid.updatedAt?.timeIntervalSince1970 ?? 0 })
    }
}

//func databaseUpdateInspection(key: String, inspection: Inspection, completion: @escaping FIRDatabaseCompletionBlock) {
//    let post = inspection.toJSON()
//    let childUpdates = [key: post]
//    inspectionsRef.updateChildValues(childUpdates, withCompletionBlock: { (error, ref) in
//        completion(error, ref)
//    })
//}

//func sendPushMessagesForProperty(propertyKey: String, title: String, message: String) {
//    if incognitoMode {
//        return
//    }
//
//    #if RELEASE
//    #else
//    let title = "[STAGING] \(title)"
//    #endif
//
//    usersRef.observeSingleEvent(of: .value, with: { (snapshot) in
//        var recepientIds: [String] = []
//        for child in snapshot.children {
//            let childSnapshot = child as! DataSnapshot
//            if let json = childSnapshot.value as? [String: Any] {
//                // Ignore self
//                if childSnapshot.key == currentUser?.uid {
//                    continue
//                }
//
//                if let user = UserProfile(JSON: json) {
//                    if user.pushOptOut == true {
//                        continue
//                    }
//
//                    if user.isDisabled == true {
//                        continue
//                    }
//
//                    // All Admins and Corporates
//                    if user.admin || user.corporate {
//                        recepientIds.append(childSnapshot.key)
//                    } else {
//                        // If user has access to same property
//                        for key in user.properties.keys {
//                            if key == propertyKey {
//                                recepientIds.append(childSnapshot.key)
//                                continue
//                            }
//                        }
//                    }
//                }
//            }
//        }
//
//        // Send each push message
//        for recepientId in recepientIds {
//            let sendMessage = SendMessage(recipientId: recepientId, title: title, message: message)
//            sendMessage.update { (error, ref) in
//                // save to send
//            }
//        }
//    })
//}
//
//func sendPushMessagesForAdmins(title: String, message: String) {
//    if incognitoMode {
//        return
//    }
//
//    #if RELEASE
//    #else
//    let title = "[STAGING] \(title)"
//    #endif
//
//    usersRef.observeSingleEvent(of: .value, with: { (snapshot) in
//        var recepientIds: [String] = []
//        for child in snapshot.children {
//            let childSnapshot = child as! DataSnapshot
//            if let json = childSnapshot.value as? [Sxtring: Any] {
//                // Ignore self
//                if childSnapshot.key == currentUser?.uid {
//                    continue
//                }
//
//                if let user = UserProfile(JSON: json) {
//                    if user.pushOptOut == true {
//                        continue
//                    }
//                    if user.isDisabled == true {
//                        continue
//                    }
//                    // All Admins
//                    if user.admin {
//                        recepientIds.append(childSnapshot.key)
//                    }
//                }
//            }
//        }
//
//        // Send each push message
//        for recepientId in recepientIds {
//            let sendMessage = SendMessage(recipientId: recepientId, title: title, message: message)
//            sendMessage.update { (error, ref) in
//                // save to send
//            }
//        }
//    })
//}
