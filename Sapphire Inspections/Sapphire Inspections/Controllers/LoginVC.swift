//
//  LoginVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 7/17/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import FirebaseFirestore
import DeviceKit
import Firebase
import FirebaseAnalytics
//import FirebaseCrashlytics

class LoginVC: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var resetPasswordButton: UIButton!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var versionLabel: UILabel!
    
    let requiredEmailSuffix = "@bluestone-prop.com"
    var userListener: ListenerRegistration?
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .portrait
        }
        
        return .all
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

//        loginButton.isEnabled = false
        
        startAuthListener()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if requiredVersionForcesUpdate == true {
            let title = "Version \(latestVersionAvailable) Available"
            let message = "Update required, please install the latest version."
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default) { action in
                let urlString = webAppBaseURL + "/ios"
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
            let cancelAction = UIAlertAction(title: "CANCEL", style: .cancel) { action in
            }
            alertController.addAction(okAction)
            alertController.addAction(cancelAction)
            present(alertController, animated: true, completion: nil)
        }
        
        // Set version #
        if let version = Bundle.main.releaseVersionNumber, let build = Bundle.main.buildVersionNumber {
            versionLabel.text = "v\(version) (\(build))"
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func didTapEmailLogin(_ sender: AnyObject) {
        guard let email = emailTextField.text else {
            displayMessage(title: "Login", message: "Please enter your email.")
            return
        }
        
        guard validateEmail(email) else {
            displayMessage(title: "Login", message: "Please enter a valid email address.")
            return
        }
        
        guard let password = passwordTextField.text else {
            displayMessage(title: "Login", message: "Please enter a password.")
            return
        }
        
        guard validatePassword(password) else {
            displayMessage(title: "Login", message: "Please enter a valid password, with 8 or more characters.")
            return
        }
        
        if let email = emailTextField.text, let password = passwordTextField.text {
            SVProgressHUD.show()
            
            // Switch databases
//            // Change to correct database
//            FIRConnection.stopMonitoring()
//            // Configure with manual options.
//            let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")
//            guard let stagingOptions = FirebaseOptions(contentsOfFile: filePath!) else {
//                assert(false, "Couldn't load config file")
//                SVProgressHUD.dismiss()
//                return
//            }
//            // Change to Staging Database
//            stagingOptions.databaseURL = "https://sapphire-inspections.firebaseio.com"
//            FirebaseApp.app()?.delete({ (success) in
//                print("Firebase App deleted")
//            })
//            FirebaseApp.configure(options: stagingOptions)
//            Database.database().isPersistenceEnabled = false
//            FIRConnection.startMonitoring()
//            startAuthListener()
            
            
            Auth.auth().signIn(withEmail: email, password: password) { [weak self] (user, error) in
                SVProgressHUD.dismiss()
                if let error = error {
                    self?.showMessagePrompt(error.localizedDescription)
                }
            }
        } else {
            showMessagePrompt("email/password can't be empty")
        }
    }
    
    @IBAction func resetPasswordButtonTapped(_ sender: Any) {
        let alertController = UIAlertController(title: "Reset Password", message: "Please enter your Sparkle user account email.", preferredStyle: .alert)
        
        let emailEntered = emailTextField.text

        alertController.addTextField { (textField) in
            textField.text = emailEntered
            textField.placeholder = "Email"
            textField.keyboardType = .emailAddress
        }

        // add the buttons/actions to the view controller
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { [weak self] (action) in
            self?.view.endEditing(true)
        }
        let saveAction = UIAlertAction(title: "Send", style: .default) { [weak self] _ in
            guard let weakSelf = self else {
                return
            }
            
            weakSelf.view.endEditing(true)
            
            let email = alertController.textFields![0].text ?? ""

            guard weakSelf.validateEmail(email) else {
                weakSelf.displayMessage(title: "Reset Password", message: "Please enter a valid email address.")
                return
            }
            
            SVProgressHUD.show()
            Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
                SVProgressHUD.dismiss()
                
                guard let weakSelf = self else {
                    return
                }
                
                if let error = error {
                    weakSelf.displayMessage(title: "Reset Password", message: "Error: \(error.localizedDescription)")
                } else {
                    weakSelf.displayMessage(title: "Reset Password", message: "Success: Check your email for the reset password link.")

                }
            }

        }

        alertController.addAction(cancelAction)
        alertController.addAction(saveAction)

        present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func newUserButtonTapped(_ sender: Any) {
        displayMessage(title: "New User", message: "Enter your email address above, and then tap on Reset Password.  This will send you an email, with a reset password link, to set your new password.  Return to this app, enter your password, and then Log In!")
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }
    
    // MARK: - UITextField
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
//        let newString = (textField.text! as NSString).replacingCharacters(in: range, with: string)

//        if textField == emailTextField {
//            updateLoginButton(email: newString, pass: passwordTextField.text!)
//        } else {
//            updateLoginButton(email: emailTextField.text!, pass: newString)
//        }
        
        return true
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
//        loginButton.isEnabled = false
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailTextField {
            if !emailTextField.text!.contains("@") && emailTextField.text! != "" {
                emailTextField.text = emailTextField.text! + requiredEmailSuffix
            }
            passwordTextField.becomeFirstResponder()
        } else {
            passwordTextField.resignFirstResponder()
        }
        
        return true
    }
    
    // MARK: - Validation
    
    func updateLoginButton(email: String, pass: String) {
        if validateEmail(email) && validatePassword(pass) {
//            loginButton.isEnabled = true
        } else {
//            loginButton.isEnabled = false
        }
    }

    func validateEmail(_ candidate: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,6}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: candidate)
    }
    
    func validateEmailSuffix(_ candidate: String) -> Bool {
        return candidate.hasSuffix(requiredEmailSuffix)
    }
    
    func validatePassword(_ candidate: String) -> Bool {
        return candidate.count >= 8
    }
    
//    func addFirstAndLastToUser(_ user: User?) {
//        if let user = user {
//            // Acquire lastSignInDate
//            let lastSignInDate = user.metadata.lastSignInDate ?? Date()
//
//            usersRef.child(user.uid).observeSingleEvent(of: .value, with: { snapshot in
//                if (!snapshot.exists()) {
//                    self.showTextInputPrompt(withMessage: "Enter your first name:") { (userPressedOK, first) in
//                        if let first = first {
//                            self.showTextInputPrompt(withMessage: "Enter your last name:") { (userPressedOK, last) in
//                                if let last = last {
//                                    SVProgressHUD.show()
//                                    let changeRequest = currentUser?.createProfileChangeRequest()
//                                    changeRequest?.displayName = first + " " + last
//                                    changeRequest?.commitChanges() { (error) in
//                                        SVProgressHUD.dismiss()
//                                        if let error = error {
//                                            self.showMessagePrompt(error.localizedDescription)
//                                            return
//                                        }
//                                        currentUserProfile = Mapper<UserProfile>().map(JSON: ["firstName": first, "lastName": last, "email": currentUser!.email!, "admin": false, "corporate": false, "lastSignInDate": lastSignInDate.timeIntervalSince1970, "lastUserAgent": userAgent])
//
//                                        usersRef!.child(currentUser!.uid).setValue(currentUserProfile?.toJSON())
//                                        //self.performSegueWithIdentifier("signIn", sender: nil)
//                                    }
//                                } else {
//                                    self.showMessagePrompt("last name can't be empty")
//                                }
//                            }
//                        } else {
//                            self.showMessagePrompt("first name can't be empty")
//                        }
//                    }
//                } else {
//                    currentUserProfile = Mapper<UserProfile>().map(JSONObject: snapshot.value)
//
//                    //                            self.performSegueWithIdentifier("signIn", sender: nil)
//                }
//            })
//        }
//    }
    
    func displayMessage(title: String, message: String?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default) { action in
        }
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }
    
    func startAuthListener() {
        Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            if let user = user {
                print("User is signed in.")
                
                // Acquire lastSignInDate
                let lastSignInDate = user.metadata.lastSignInDate ?? Date()
                
                if self?.userListener == nil {
                    self?.userListener = dbDocumentUserWith(userId: user.uid).addSnapshotListener({ (documentSnapshot, error) in
                        DispatchQueue.main.async {
                            print("Current User Profile Updated, observed by LoginVC")
                            if let document = documentSnapshot, document.exists {
                                currentUserProfile = Mapper<UserProfile>().map(JSONObject: document.data())
                                
                                // Update last sign on date, and last userAgent
                                currentUserProfile?.lastSignInDate = lastSignInDate
                                currentUserProfile?.lastUserAgent = userAgent
                                
                                // Firebase Analytics, "appleDevice"
                                if !Device.current.isSimulator {
                                    print("User Property, appleDevice: \(Device.current.description)")
                                    Analytics.setUserProperty(Device.current.description, forName: "appleDevice")
                                }
                                
                                if let profile = currentUserProfile {
                                    var json = profile.toJSON()
                                    json = UserProfile.updateJSONToExcludeReadOnlyValues(json: json)

                                    dbDocumentUserWith(userId: user.uid).setData(json, merge: true) { (error) in
                                        DispatchQueue.main.async {
                                            if let error = error {
                                                self?.showMessagePrompt(error.localizedDescription)
                                            } else {
                                                print("User Profile: lastSignInDate & lastUserAgent updated")
                                            }
                                        }
                                    }
                                    
                                    Crashlytics.crashlytics().setUserID(profile.email ?? "Email Unknown")
                                }
                            } else {
                                //self.addFirstAndLastToUser(user)
                                //self.showMessagePrompt("Please update your Profile")
                                currentUserProfile = Mapper<UserProfile>().map(JSON: ["firstName": "", "lastName": "", "email": user.email!, "admin": false, "corporate": false, "lastSignInDate": lastSignInDate.timeIntervalSince1970, "lastUserAgent": userAgent])
                                if let newUserProfile = currentUserProfile {
                                    var json = newUserProfile.toJSON()
                                    json = UserProfile.updateJSONToExcludeReadOnlyValues(json: json)

                                    dbDocumentUserWith(userId: user.uid).setData(json)
                                    Notifications.sendUserCreation(newUserProfile: newUserProfile)
                                    
                                    Crashlytics.crashlytics().setUserID(newUserProfile.email ?? "Email Unknown")
                                }
                            }
                        }
                    })
                }
                
                if self?.presentedViewController == nil {
                    self?.performSegue(withIdentifier: "signIn", sender: nil)
                }
                
                LocalInspectionImages.singleton.setup()
                LocalDeficientImages.singleton.setup()
                
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    appDelegate.initializeNotifcationServices()
                }
                
                //                if let _ = self.visibleViewController as? LoginVC {
                //                    self.performSegueWithIdentifier("signIn", sender: nil)
                //
                ////                    let changeRequest = currentUser?.profileChangeRequest()
                ////                    changeRequest?.displayName = "Stu Carney"
                ////                    changeRequest?.commitChangesWithCompletion() { (error) in }
                //                }
            } else {
                print("User is signed out.")
                self?.dismiss(animated: true, completion: nil)

                if let listener = self?.userListener {
                    listener.remove()
                }
                
                // Clear all stored data
                self?.emailTextField.text = ""
                self?.passwordTextField.text = ""
                currentUserProfile = nil
                self?.userListener = nil
                
                LocalInspectionImages.singleton.reachability.stopNotifier()
                LocalDeficientImages.singleton.reachability.stopNotifier()
            }
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
