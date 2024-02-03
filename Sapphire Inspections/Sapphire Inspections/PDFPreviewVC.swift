//
//  PDFPreviewVC.swift
//  PDFGenerator
//
//  Created by Suguru Kishimoto on 2016/02/06.
//
//

import UIKit
import WebKit


class PDFPreviewVC: UIViewController {
    
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var navView: SparkleNavigationBar!
    @IBOutlet weak var shareButton: UIBarButtonItem!
    
    var url: URL!
    var fileName = "Sparkle Report"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let req = NSMutableURLRequest(url: url)
        req.timeoutInterval = 60.0
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        webView.load(req as URLRequest)

        view.backgroundColor = firebaseConnectionColor()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @objc @IBAction fileprivate func close(_ sender: AnyObject!) {
        dismiss(animated: true, completion: nil)
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
