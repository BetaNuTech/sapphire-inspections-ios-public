//
//  JobUploadPreviewVC.swift
//
//

import UIKit
import WebKit


class JobUploadPreviewVC: UIViewController {
    
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var shareButton: UIBarButtonItem!
    @IBOutlet weak var navBar: UINavigationItem!

    var url: URL!
    var fileName = "SOW Upload"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let req = NSMutableURLRequest(url: url)
        req.timeoutInterval = 60.0
        req.cachePolicy = .reloadRevalidatingCacheData

        webView.load(req as URLRequest)

        view.backgroundColor = firebaseConnectionColor()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction fileprivate func share(_ sender: Any) {
//        guard let pdfData = NSData(contentsOf: url) else {
//            print("ERROR: pdfData failed to create data object")
//            return
//        }
        
        let activityViewController = UIActivityViewController(activityItems: [fileName, url], applicationActivities: nil)
        
        weak var weakSelf = self
        if UIDevice.current.userInterfaceIdiom == .pad {
            if let presentation = activityViewController.popoverPresentationController {
                presentation.barButtonItem = weakSelf?.shareButton
            }
        }
        present(activityViewController, animated: true)
    }
    
    func setupWithURL(fileName: String, url: URL) {
        self.url = url
        self.fileName = fileName
    }

}
