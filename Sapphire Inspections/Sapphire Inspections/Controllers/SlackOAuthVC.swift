//
//  SlackOAuthVC.swift
//

import UIKit
import WebKit
import KeychainSwift
import Alamofire
import SwiftyJSON

class SlackOAuthVC: UIViewController {
    
    private let slackClientId = "148699982064.678105000770"
    private let slackScope = "incoming-webhook,channels:write,chat:write:bot"

    private let slackClientRedirectUri = "\(webAppBaseURL)/oauth/slack"

    private let baseURL = "https://slack.com"
    
    var clientId: String = ""
    var redirectUri: String = ""
    var scope: String = ""

    private enum SlackEndpoints: String {
        case Authorize = "/oauth/authorize"
    }
    
    @IBOutlet weak var wkWebViewContainer: UIView!
    private var wkWebView: WKWebView?
    
    fileprivate var activityIndicatorView: UIActivityIndicatorView!
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
//        clearCache()
//        URLCache.shared.removeAllCachedResponses()
//        HTTPCookieStorage.shared.removeCookies(since: Date(timeIntervalSince1970: 0))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        getLoginPage()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        clientId = slackClientId
        redirectUri = slackClientRedirectUri
        scope = slackScope

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        wkWebView = WKWebView(frame: wkWebViewContainer.frame, configuration: configuration)
        wkWebViewContainer.addSubview(wkWebView!)
        wkWebView!.translatesAutoresizingMaskIntoConstraints = false
        wkWebView!.widthAnchor.constraint(equalTo: wkWebViewContainer.widthAnchor).isActive = true
        wkWebView!.heightAnchor.constraint(equalTo: wkWebViewContainer.heightAnchor).isActive = true
        wkWebView!.centerXAnchor.constraint(equalTo: wkWebViewContainer.centerXAnchor).isActive = true
        wkWebView!.centerYAnchor.constraint(equalTo: wkWebViewContainer.centerYAnchor).isActive = true
        
//        webView = UIWebView(frame: view.frame)
        wkWebView!.uiDelegate = self
        wkWebView!.navigationDelegate = self
//        view.addSubview(webView)
        
        activityIndicatorView = UIActivityIndicatorView(style: .gray)
//        activityIndicatorView.center = wkWebView!.center
        activityIndicatorView.isHidden = true
        activityIndicatorView.hidesWhenStopped = true
        wkWebView!.addSubview(activityIndicatorView)
        activityIndicatorView.bindFrameToSuperview()
    }
    
//    @IBAction func hitClose(_ sender: UIBarButtonItem) {
//        dismiss()
//    }
    
    private func getLoginPage() {
        activityIndicatorView.isHidden = false
        activityIndicatorView.startAnimating()
        
        let authUrl = baseURL + SlackEndpoints.Authorize.rawValue
        let components = NSURLComponents(string: authUrl)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "redirect_uri", value: redirectUri)
        ]
        let request = URLRequest(url: components.url!, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10)
        wkWebView?.load(request)
//        webView.loadRequest(request)
    }
    
    fileprivate func setAccessCode(slackCode: String) {
        print("slackCode = \(slackCode)")
        
        if let user = currentUser {
            user.getIDToken { [weak self] (token, error) in
                if let token = token {
                    let headers: HTTPHeaders = [
                        "Authorization": "FB-JWT \(token)",
                        "Content-Type": "application/json"
                    ]
                    
                    let parameters: Parameters = [
                        "redirectUri": self?.redirectUri ?? "",
                        "slackCode": slackCode
                    ]
                    
                    presentHUDForConnection()
                    AF.request(setSlackAuthorizorURLString, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { [weak self] response in
                        debugPrint(response)

                        if let statusCode = response.response?.statusCode, statusCode >= 200 && statusCode < 300 {
                            let alertController = UIAlertController(title: "Authorization Successful", message: nil, preferredStyle: .alert)
                            let okayAction = UIAlertAction(title: "OK", style: .default) { action in
                                self?.navigationController?.popViewController(animated: true)
                            }
                            alertController.addAction(okayAction)
                            self?.present(alertController, animated: true, completion: nil)
                            
                            dbDocumentIntegrationOrganizationSlack().getDocument(completion: { (documentSnapshot, error) in
                                print("Organization Slack observed")
                                if let document = documentSnapshot, document.exists {
                                    if let slackOrg = Mapper<OrganizationSlack>().map(JSONObject: document.data()) {
                                        Notifications.sendSlackIntegrationAddition(organizationSlack: slackOrg)
                                    }
                                }
                            })
                        } else {
                            let errorMessage = firebaseAPIErrorMessages(data: response.data, error: response.error, statusCode: response.response?.statusCode)
                            let alertController = UIAlertController(title: "Sparkle Authorization Failed", message: errorMessage, preferredStyle: .alert)
                            let okayAction = UIAlertAction(title: "OK", style: .default) { action in
                                self?.navigationController?.popViewController(animated: true)
                            }
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

extension SlackOAuthVC: WKUIDelegate, WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicatorView.stopAnimating()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print(error.localizedDescription)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
//        print("webView:\(webView) decidePolicyForNavigationAction:\(navigationAction) decisionHandler:\(decisionHandler)")
        
        if let urlString = navigationAction.request.url?.absoluteString {
            if urlString.hasPrefix(slackClientRedirectUri) {
                decisionHandler(.cancel)

                let params = navigationAction.request.url?.queryParameters ?? [:]
                if let code = params["code"] {
                    setAccessCode(slackCode: code)
                    return
                }
                
                // OAuth failed, there is no code returned, and we need to return to the app
                var errorMessage: String?
                if let error = params["error"] {
                    errorMessage = error
                }
                
                let alertController = UIAlertController(title: "Slack Authorization Failed", message: errorMessage, preferredStyle: .alert)
                let okayAction = UIAlertAction(title: "OK", style: .default) { [weak self] action in
                    self?.navigationController?.popViewController(animated: true)
                }
                alertController.addAction(okayAction)
                present(alertController, animated: true, completion: nil)
            } else {
                decisionHandler(.allow)
            }
        } else {
            decisionHandler(.allow)
        }
    }
}
