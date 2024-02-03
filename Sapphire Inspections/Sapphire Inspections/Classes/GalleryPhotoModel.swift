//
//  GalleryPhotoModel.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 9/13/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class GalleryPhotoModel: NSObject, INSPhotoViewable {

    var itemPhotoDataKey: String?
    
    var image: UIImage?
    var thumbnailImage: UIImage?
    
    var imageURL: URL?
    var thumbnailImageURL: URL?
    
    var attributedTitle: NSAttributedString?
    
    var startDate: Date? // For Deficient Items

    public func loadImageWithCompletionHandler(_ completion: @escaping (UIImage?, Error?) -> Void) {
        if let image = image {
            completion(image, nil)
            return
        }
        downloadImageWithURL(imageURL, completion: completion)
    }
    public func loadThumbnailImageWithCompletionHandler(_ completion: @escaping (UIImage?, Error?) -> Void) {
        if let thumbnailImage = thumbnailImage {
            completion(thumbnailImage, nil)
            return
        }
        downloadImageWithURL(thumbnailImageURL, completion: completion)
    }

//    func loadImageWithURL(url: NSURL?, completion: (image: UIImage?, error: NSError?) -> ()) {
//        let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
//        
//        if let imageURL = url {
//            session.dataTaskWithURL(imageURL, completionHandler: { (response: NSData?, data: NSURLResponse?, error: NSError?) in
//                
//                dispatch_async(dispatch_get_main_queue(), { () -> Void in
//                    if error != nil {
//                        completion(image: nil, error: error)
//                    } else if let response = response, let image = UIImage(data: response) {
//                        completion(image: image, error: nil)
//                    } else {
//                        completion(image: nil, error: NSError(domain: "INSPhotoDomain", code: -1, userInfo: [ NSLocalizedDescriptionKey: "Couldn't load image"]))
//                    }
//                    session.finishTasksAndInvalidate()
//                })
//                
//            }).resume()
//        } else {
//            completion(image: nil, error: NSError(domain: "INSPhotoDomain", code: -2, userInfo: [ NSLocalizedDescriptionKey: "Image URL not found."]))
//        }
//    }
    
    func downloadImageWithURL(_ url: URL?, completion: @escaping (_ image: UIImage?, _ error: NSError?) -> ()) {
        if let imageURL = url {
            let downloader = SDWebImageDownloader.shared
            downloader.downloadImage(with: imageURL, options: .highPriority, progress: { (receivedSize, expectedSize, targetURL) in
                
            }, completed: { (image, data, error, finished) in
                if error != nil {
                    completion(nil, error as NSError?)
                } else if let image = image , finished {
                    completion(image, nil)
                } else {
                    completion(nil, NSError(domain: "INSPhotoDomain", code: -1, userInfo: [ NSLocalizedDescriptionKey: "Couldn't load image"]))
                }
            })
        } else {
            completion(nil, NSError(domain: "INSPhotoDomain", code: -2, userInfo: [ NSLocalizedDescriptionKey: "Image URL not found."]))
        }
    }
}
