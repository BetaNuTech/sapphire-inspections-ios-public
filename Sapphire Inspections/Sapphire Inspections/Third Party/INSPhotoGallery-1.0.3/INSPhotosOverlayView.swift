//
//  INSPhotosOverlayView.swift
//  INSPhotoViewer
//
//  Created by Michal Zaborowski on 28.02.2016.
//  Copyright © 2016 Inspace Labs Sp z o. o. Spółka Komandytowa. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this library except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import UIKit

public protocol INSPhotosOverlayViewable:class {
    weak var photosViewController: INSPhotosViewController? { get set }
    
    func populateWithPhoto(_ photo: INSPhotoViewable)
    func setHidden(_ hidden: Bool, animated: Bool)
    func view() -> UIView
}

extension INSPhotosOverlayViewable where Self: UIView {
    public func view() -> UIView {
        return self
    }
}

open class INSPhotosOverlayView: UIView , INSPhotosOverlayViewable {
    open fileprivate(set) var navigationBar: UINavigationBar!
    open fileprivate(set) var captionLabel: UILabel!
    
    open fileprivate(set) var navigationItem: UINavigationItem!
    open weak var photosViewController: INSPhotosViewController?
    fileprivate var currentPhoto: INSPhotoViewable?
    
    var leftBarButtonItem: UIBarButtonItem? {
        didSet {
            navigationItem.leftBarButtonItem = leftBarButtonItem
        }
    }
    var rightBarButtonItem: UIBarButtonItem? {
        didSet {
            navigationItem.rightBarButtonItem = rightBarButtonItem
        }
    }
    var titleTextAttributes: [String : AnyObject] = [:] {
        didSet {
            navigationBar.titleTextAttributes = convertToOptionalNSAttributedStringKeyDictionary(titleTextAttributes)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupNavigationBar()
        setupCaptionLabel()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Pass the touches down to other views
    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let hitView = super.hitTest(point, with: event) , hitView != self {
            return hitView
        }
        return nil
    }
    
    open override func layoutSubviews() {
        // The navigation bar has a different intrinsic content size upon rotation, so we must update to that new size.
        // Do it without animation to more closely match the behavior in `UINavigationController`
        UIView.performWithoutAnimation { () -> Void in
            self.navigationBar.invalidateIntrinsicContentSize()
            self.navigationBar.layoutIfNeeded()
        }
        super.layoutSubviews()
    }
    
    open func setHidden(_ hidden: Bool, animated: Bool) {
        if self.isHidden == hidden {
            return
        }
        
        if animated {
            self.isHidden = false
            self.alpha = hidden ? 1.0 : 0.0
            
            UIView.animate(withDuration: 0.2, delay: 0.0, options: [.allowAnimatedContent, .allowUserInteraction], animations: { () -> Void in
                self.alpha = hidden ? 0.0 : 1.0
                }, completion: { result in
                    self.alpha = 1.0
                    self.isHidden = hidden
            })
        } else {
            self.isHidden = hidden
        }
    }
    
    open func populateWithPhoto(_ photo: INSPhotoViewable) {
        self.currentPhoto = photo

        if let photosViewController = photosViewController {
            if let index = photosViewController.dataSource.indexOfPhoto(photo) {
                navigationItem.title = NSLocalizedString("\(index+1) of \(photosViewController.dataSource.numberOfPhotos)", comment: "1 of 10")
            }
            captionLabel.attributedText = photo.attributedTitle
        }
    }
    
    @objc fileprivate func closeButtonTapped(_ sender: UIBarButtonItem) {
        photosViewController?.dismiss(animated: true, completion: nil)
    }
    
    @objc fileprivate func actionButtonTapped(_ sender: UIBarButtonItem) {
        if let currentPhoto = currentPhoto {
            currentPhoto.loadImageWithCompletionHandler({ [weak self] (image, error) -> () in
                if let image = (image ?? currentPhoto.thumbnailImage) {
                    let activityController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
                    activityController.popoverPresentationController?.barButtonItem = sender
                    self?.photosViewController?.present(activityController, animated: true, completion: nil)
                }
            });
        }
    }
    
    fileprivate func setupNavigationBar() {
        navigationBar = UINavigationBar()
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        navigationBar.backgroundColor = UIColor.clear
        navigationBar.barTintColor = nil
        navigationBar.isTranslucent = true
        navigationBar.shadowImage = UIImage()
        navigationBar.setBackgroundImage(UIImage(), for: .default)
        
        navigationItem = UINavigationItem(title: "")
        navigationBar.items = [navigationItem]
        addSubview(navigationBar)
        
        let guide = self.safeAreaLayoutGuide
        
        let topConstraint = NSLayoutConstraint(item: navigationBar, attribute: .top, relatedBy: .equal, toItem: guide, attribute: .top, multiplier: 1.0, constant: 0.0)
        let widthConstraint = NSLayoutConstraint(item: navigationBar, attribute: .width, relatedBy: .equal, toItem: self, attribute: .width, multiplier: 1.0, constant: 0.0)
        let horizontalPositionConstraint = NSLayoutConstraint(item: navigationBar, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1.0, constant: 0.0)
        self.addConstraints([topConstraint,widthConstraint,horizontalPositionConstraint])
        
        if let bundlePath = Bundle(for: type(of: self)).path(forResource: "INSPhotoGallery", ofType: "bundle") {
            let bundle = Bundle(path: bundlePath)
            leftBarButtonItem = UIBarButtonItem(image: UIImage(named: "INSPhotoGalleryClose", in: bundle, compatibleWith: nil), landscapeImagePhone: UIImage(named: "INSPhotoGalleryCloseLandscape", in: bundle, compatibleWith: nil), style: .plain, target: self, action: #selector(INSPhotosOverlayView.closeButtonTapped(_:)))
        } else {
            leftBarButtonItem = UIBarButtonItem(title: "CLOSE".uppercased(), style: .plain, target: self, action: #selector(INSPhotosOverlayView.closeButtonTapped(_:)))
        }
        
        rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(INSPhotosOverlayView.actionButtonTapped(_:)))
    }
    
    fileprivate func setupCaptionLabel() {
        captionLabel = UILabel()
        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        captionLabel.backgroundColor = UIColor.clear
        captionLabel.numberOfLines = 0
        captionLabel.layer.shadowColor = UIColor.black.cgColor
        captionLabel.layer.shadowOpacity = 0.6
        captionLabel.layer.shadowOffset = CGSize.zero
        captionLabel.layer.shadowRadius = 10

        addSubview(captionLabel)
        
        let guide = self.safeAreaLayoutGuide
        
        let bottomConstraint = NSLayoutConstraint(item: guide, attribute: .bottom, relatedBy: .equal, toItem: captionLabel, attribute: .bottom, multiplier: 1.0, constant: 8.0)
        let leadingConstraint = NSLayoutConstraint(item: captionLabel, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1.0, constant: 8.0)
        let trailingConstraint = NSLayoutConstraint(item: self, attribute: .trailing, relatedBy: .equal, toItem: captionLabel, attribute: .trailing, multiplier: 1.0, constant: 8.0)
        self.addConstraints([bottomConstraint,leadingConstraint,trailingConstraint])
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}
