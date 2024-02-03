//
//  TrelloOAuthVC.swift
//

import UIKit
import WebKit
import KeychainSwift
import Alamofire
import SwiftyJSON

class TrelloOAuthVC: UIViewController {
    
    private let trelloClientKey = "<key>"
    private let trelloClientRedirectUri = "https://oauth-callback/trello"

    private let baseURL = "https://trello.com"
    
    var clientKey: String = ""
    var redirectUri: String = ""
    
    private enum TrelloEndpoints: String {
        case Authorize = "/1/authorize"
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
        
        clientKey = trelloClientKey
        redirectUri = trelloClientRedirectUri
        
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
        
        let authUrl = baseURL + TrelloEndpoints.Authorize.rawValue
        let components = NSURLComponents(string: authUrl)!
        components.queryItems = [
            URLQueryItem(name: "key", value: clientKey),
            URLQueryItem(name: "expiration", value: "never"),
            URLQueryItem(name: "scope", value: "read,write"),
            URLQueryItem(name: "response_type", value: "fragment"),
            URLQueryItem(name: "name", value: "Sparkle"),
            URLQueryItem(name: "return_url", value: redirectUri)
        ]
        let request = URLRequest(url: components.url!, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10)
        wkWebView?.load(request)
//        webView.loadRequest(request)
    }
    
    fileprivate func setAccessToken(trelloToken: String) {
        print("trelloToken = \(trelloToken)")
        
        if let user = currentUser {
            user.getIDToken { [weak self] (token, error) in
                if let token = token {
                    let headers: HTTPHeaders = [
                        "Authorization": "FB-JWT \(token)",
                        "Content-Type": "application/json"
                    ]
                    
                    let parameters: Parameters = [
                        "apikey": self?.trelloClientKey ?? "",
                        "authToken": trelloToken
                    ]
                    
                    presentHUDForConnection()
                    AF.request(setTrelloAuthorizorURLString, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { [weak self] response in
                        debugPrint(response)

                        if let statusCode = response.response?.statusCode, statusCode >= 200 && statusCode < 300 {
                            let alertController = UIAlertController(title: "Authorization Successful", message: nil, preferredStyle: .alert)
                            let okayAction = UIAlertAction(title: "OK", style: .default) { action in
                                self?.navigationController?.popViewController(animated: true)
                            }
                            alertController.addAction(okayAction)
                            self?.present(alertController, animated: true, completion: nil)
                            
                            dbDocumentIntegrationOrganizationTrello().getDocument(completion: { (documentSnapshot, error) in
                                print("Organization Trello observed")
                                if let document = documentSnapshot, document.exists {
                                    if let trelloOrg = Mapper<OrganizationTrello>().map(JSONObject: document.data()) {
                                        Notifications.sendTrelloIntegrationAddition(organizationTrello: trelloOrg)
                                    }
                                }
                            })

                        } else {
                            let errorMessage = firebaseAPIErrorMessages(data: response.data, error: response.error, statusCode: response.response?.statusCode)
                            let alertController = UIAlertController(title: "Authorization Failed", message: errorMessage, preferredStyle: .alert)
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

extension TrelloOAuthVC: WKUIDelegate, WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicatorView.stopAnimating()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print(error.localizedDescription)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
//        print("webView:\(webView) decidePolicyForNavigationAction:\(navigationAction) decisionHandler:\(decisionHandler)")
        
        if let urlString = navigationAction.request.url?.absoluteString {
            if let range = urlString.range(of: "\(trelloClientRedirectUri)?token=") {
                let location = range.upperBound
                let token = urlString[location...]
                setAccessToken(trelloToken: String(token))
                decisionHandler(.cancel)
            } else if let range = urlString.range(of: "\(trelloClientRedirectUri)&token=") {
                let location = range.upperBound
                let token = urlString[location...]
                setAccessToken(trelloToken: String(token))
                decisionHandler(.cancel)
            } else if let range = urlString.range(of: "\(trelloClientRedirectUri)#token=") {
                let location = range.upperBound
                let token = urlString[location...]
                setAccessToken(trelloToken: String(token))
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        } else {
            decisionHandler(.allow)
        }
    }
}

