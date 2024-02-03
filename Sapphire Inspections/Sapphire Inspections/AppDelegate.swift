//
//  AppDelegate.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 7/17/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications
import SideMenuController
import FirebaseCrashlytics
import WebKit
import RealmSwift


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let gcmMessageIDKey = "gcm.message_id"

    class var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
//        Fabric.with([Crashlytics.self, Answers.self])

//        NotificationCenter.default.addObserver(self, selector: #selector(self.tokenRefreshNotification),
//                                               name: NSNotification.Name.InstanceIDTokenRefresh, object: nil)
        
        #if RELEASE_BLUESTONE
        let filePath = Bundle.main.path(forResource: "Bluestone-GoogleService-Info", ofType: "plist")
        guard let options = FirebaseOptions(contentsOfFile: filePath!) else {
            assert(false, "Couldn't load config file")
            return false
        }
        FirebaseApp.configure(options: options)
        #elseif RELEASE_STAGING
        let filePath = Bundle.main.path(forResource: "Staging-GoogleService-Info", ofType: "plist")
        guard let options = FirebaseOptions(contentsOfFile: filePath!) else {
            assert(false, "Couldn't load config file")
            return false
        }
        FirebaseApp.configure(options: options)
        #else
        let filePath = Bundle.main.path(forResource: "Staging-GoogleService-Info", ofType: "plist")
        guard let options = FirebaseOptions(contentsOfFile: filePath!) else {
            assert(false, "Couldn't load config file")
            return false
        }
        // Change to Staging Database
        // stagingOptions.databaseURL = "https://staging-sapphire-inspections.firebaseio.com"
        FirebaseApp.configure(options: options)
        #endif
        
        Messaging.messaging().delegate = self
        
        Database.database().isPersistenceEnabled = false
        
        FIRConnection.startMonitoring()
        
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType:.USEast2,
                                                                identityPoolId:"us-east-2:6d9aa019-65cb-4e64-9e21-be030483a6a4")
        let configuration = AWSServiceConfiguration(region:.USEast2, credentialsProvider:credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        
        SideMenuController.preferences.drawing.menuButtonImage = UIImage(named: "menu")
        SideMenuController.preferences.drawing.sidePanelPosition = .overCenterPanelLeft
        SideMenuController.preferences.drawing.sidePanelWidth = 300
        SideMenuController.preferences.drawing.centerPanelShadow = true
        SideMenuController.preferences.animating.statusBarBehaviour = .horizontalPan
        SideMenuController.preferences.interaction.swipingEnabled = false
        
        SVProgressHUD.setDefaultStyle(.dark)
        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.setMaximumDismissTimeInterval(2.5)
        
        // If a Realm Auto migration is needed
        
        let config = Realm.Configuration(
            // Set the new schema version. This must be greater than the previously used
            // version (if you've never set a schema version before, the version is 0).
            schemaVersion: 1,
            
            // Set the block which will be called automatically when opening a Realm with
            // a schema version lower than the one set above
            migrationBlock: { migration, oldSchemaVersion in
                // We haven’t migrated anything yet, so oldSchemaVersion == 0
                if (oldSchemaVersion < 1) {
                    // Nothing to do!
                    // Realm will automatically detect new properties and removed properties
                    // And will update the schema on disk automatically
                }
        })
        
        // Tell Realm to use this new configuration object for the default Realm
        Realm.Configuration.defaultConfiguration = config
        
        // Now that we've told Realm how to handle the schema change, opening the file
        // will automatically perform the migration
        let _ = try! Realm()
        
        
        WKWebView.clearCache()
                
        return true
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let incomingURL = userActivity.webpageURL,
            let components = NSURLComponents(url: incomingURL, resolvingAgainstBaseURL: true),
            let path = components.path else {
                return false
        }
        
        print("path = \(path)")
        
        let params = components.queryItems ?? []
        
        if path == "/trello/oauth/callback" {
            if let token = params.first(where: { $0.name == "token" } )?.value {
                
                print("trello oauth token = \(token)")
                return true
            }
        }
        
        // Grab top view controller
        if let topController = UIApplication.shared.topMostViewController() {
            
            guard let sideMenuController = topController as? SparkleSideMenuVC else {
                return false
            }
            
            guard let sINavController = sideMenuController.centerViewController as? SINavController else {
                return false
            }

            // OPEN INSPECTION
            // /properties/-KYLYDoEoEwbxJ5AjWaX/update-inspection/-Lz8Lh7A88IHqIZ-_7xB
            // If contains properties AND update-inspection
            if path.contains("/properties/") && path.contains("/inspections/edit") {
                let pathToArray = path.components(separatedBy: "/")
                if pathToArray.count >= 6 && pathToArray[5] != "" {
                    let propertyKey = pathToArray[2]
                    let inspectionKey = pathToArray[5]
                    
                    let inspectionsStoryboard = UIStoryboard(name: "Inspections", bundle: nil)
                    if let vc = inspectionsStoryboard.instantiateViewController(withIdentifier: "inspection") as? InspectionVC {
                        
                        vc.propertyKey = propertyKey
                        vc.inspectionKey = inspectionKey

                        sINavController.pushViewController(vc, animated: true)
                    }
                }
                
                return false
            }
            
            // OPEN DEFICIENT ITEM OR DEFICIENT ITEMS
            // /properties/-KYLYDoEoEwbxJ5AjWaX/update-inspection/-Lz8Lh7A88IHqIZ-_7xB
            // If contains properties AND update-inspection
            if path.contains("/properties/") && path.contains("/deficient-items/") {
                let pathToArray = path.components(separatedBy: "/")
                // OPEN DEFICIENT ITEM
                if pathToArray.count >= 5 && pathToArray[4] != "" {
                    let propertyKey = pathToArray[2]
                    let deficientItemKey = pathToArray[4]
                    
                    let inspectionsStoryboard = UIStoryboard(name: "Inspections", bundle: nil)
                    if let vc = inspectionsStoryboard.instantiateViewController(withIdentifier: "deficient-item") as? DeficientItemVC {
                        
                        vc.propertyKey = propertyKey
                        vc.deficientItemKey = deficientItemKey

                        sINavController.pushViewController(vc, animated: true)
                    }
                } else if pathToArray.count >= 5 {
                    let propertyKey = pathToArray[2]
                    
                    let inspectionsStoryboard = UIStoryboard(name: "Inspections", bundle: nil)
                    if let vc = inspectionsStoryboard.instantiateViewController(withIdentifier: "deficientItemsView") as? DeficientItemsVC {
                        
                        vc.propertyKey = propertyKey

                        sINavController.pushViewController(vc, animated: true)
                    }
                }
                
                return false
            }
            
        }
        

        
        return false
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


    func initializeNotifcationServices() {
        
        if #available(iOS 10.0, *) {
            // For iOS 10 display notification (sent via APNS)
            UNUserNotificationCenter.current().delegate = self
            
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: {_, _ in })
        } else {
            let settings: UIUserNotificationSettings =
                UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            UIApplication.shared.registerUserNotificationSettings(settings)
        }
        
        UIApplication.shared.registerForRemoteNotifications()
        
        //        let settings = UIUserNotificationSettings(types: [.sound, .alert, .badge], categories: nil)
        //
        //        UIApplication.shared.registerUserNotificationSettings(settings)
        //
        //        UIApplication.shared.registerForRemoteNotifications()
    }
    
    // [START receive_message]
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: Handle data of notification
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: Handle data of notification
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
        
        completionHandler(UIBackgroundFetchResult.newData)
    }
    // [END receive_message]
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Unable to register for remote notifications: \(error.localizedDescription)")
    }
    
    // This function is added here only for debugging purposes, and can be removed if swizzling is enabled.
    // If swizzling is disabled then this function must be implemented so that the APNs token can be paired to
    // the FCM registration token.
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("APNs token retrieved: \(deviceToken)")
        
//        InstanceID.instanceID().instanceID { (result, error) in
//            if let error = error {
//                print("Error fetching remote instance ID: \(error)")
//            } else if let result = result {
//                debugPrint("InstanceID token: \(result.token)")
//                
//                if let currentUser = currentUser {
//                    registrationTokensRef.child(currentUser.uid).updateChildValues([result.token: Date().timeIntervalSince1970])
//                }
//            }
//        }
        
        // With swizzling disabled you must set the APNs token here.
        // Messaging.messaging().apnsToken = deviceToken
    }
    
//    @objc func tokenRefreshNotification(_ notification: Foundation.Notification) {
//        InstanceID.instanceID().instanceID { (result, error) in
//            if let error = error {
//                print("Error fetching remote instance ID: \(error)")
//            } else if let result = result {
//                debugPrint("InstanceID token: \(result.token)")
//                
//                if let currentUser = currentUser {
//                    registrationTokensRef.child(currentUser.uid).updateChildValues([result.token: Date().timeIntervalSince1970])
//                }
//            }
//        }
//    }
}

// [START ios_10_message_handling]
@available(iOS 10, *)
extension AppDelegate : UNUserNotificationCenterDelegate {
    
    // Receive displayed notifications for iOS 10 devices.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
        
        // Change this to your preferred presentation option
        completionHandler([])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
        
        completionHandler()
    }
}
// [END ios_10_message_handling]


extension AppDelegate : MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")

        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(
        name: Notification.Name("FCMToken"),
        object: nil,
        userInfo: dataDict
        )
        // TODO: If necessary send token to application server.
        // Note: This callback is fired at each app startup and whenever a new token is generated.
        if let currentUser = currentUser, let token = fcmToken {
            registrationTokensRef.child(currentUser.uid).updateChildValues([token: Date().timeIntervalSince1970])
        }
    }
}





