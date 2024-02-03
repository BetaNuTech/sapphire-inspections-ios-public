//
//  InspectionReportPDF.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 2/8/17.
//  Copyright © 2017 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import TPPDF

class InspectionReportPDF: NSObject {
    
    static let singleton = InspectionReportPDF()
    
//    private var pdf: PDFGenerator?
    private var document: PDFDocument?
    private var keyInspection: (key: String, inspection: Inspection)?
    private var keyProperty: (key: String, property: Property)?
    private var keySectionsWithKeyItems: KeySectionsWithKeyItems?
    private var completion: ( (_ fileName: String, _ url: URL, _ success: Bool, _ errorMessage: String) -> Void )?
    
    var imageZeroSelectedCheckmark: UIImage?
    var imageZeroSelectedThumbsUp: UIImage?
    var imageZeroSelectedA: UIImage?
    var imageZeroSelected1: UIImage?
    var imageOneSelectedX: UIImage?
    var imageOneSelectedThumbsDown: UIImage?
    var imageOneSelectedExclamation: UIImage?
    var imageOneSelectedB: UIImage?
    var imageOneSelected2: UIImage?
    var imageTwoSelectedX: UIImage?
    var imageTwoSelectedC: UIImage?
    var imageTwoSelected3: UIImage?
    var imageThreeSelected4: UIImage?
    var imageFourSelected5: UIImage?
    
    let sectionFont = UIFont.systemFont(ofSize: 20, weight: UIFont.Weight.bold)
    let itemFont = UIFont.systemFont(ofSize: 15, weight: UIFont.Weight.medium)
    let noteFont = UIFont.italicSystemFont(ofSize: 10)
    let noteTitleFont = UIFont.systemFont(ofSize: 10, weight: UIFont.Weight.medium)
    let fontNA = UIFont.italicSystemFont(ofSize: 20)
    let adminFont = UIFont.systemFont(ofSize: 15, weight: UIFont.Weight.medium)
    
    class func createPDF(keyInspection: (key: String, inspection: Inspection), keyProperty: (key: String, property: Property), keySectionsWithKeyItems: KeySectionsWithKeyItems, forDate date: Date, completion: @escaping (String, URL, Bool, String) -> Void) {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            singleton.keyProperty = keyProperty
            singleton.keyInspection = keyInspection
            singleton.keySectionsWithKeyItems = keySectionsWithKeyItems
            singleton.completion = completion
            
            if !singleton.setupSelectedImages() {
                print("PDF ERROR: unable to setup selected images")
                endPDF(success: false, errorMessage: "Failed to setup images for Sparkle report.")
                return
            }
            
//            singleton.pdf = PDFGenerator(format: .usLetter, paginationContainer: .footerRight, imageQuality: 0.8)
            singleton.document = PDFDocument(format: .usLetter)
            setupPDF(date: date)
            
            showScore()
            
            displaySectionDetails(forSectionIndex: 0)
        }
    }
    
    fileprivate func setupSelectedImages() -> Bool {
        // Zero Selected
        guard let imageZeroSelectedCheckmark = UIImage(named: twoActions_checkmarkX_iconNames.iconName0)?.tintedImage(tintColor: GlobalColors.selectedBlue),
            let imageZeroSelectedThumbsUp = UIImage(named: twoActions_thumbs_iconNames.iconName0)?.tintedImage(tintColor: GlobalColors.selectedBlue),
            let imageZeroSelectedA = UIImage(named: threeActions_ABC_iconNames.iconName0)?.tintedImage(tintColor: GlobalColors.selectedBlue),
            let imageZeroSelected1 = UIImage(named: fiveActions_oneToFive_iconNames.iconName0)?.tintedImage(tintColor: GlobalColors.selectedRed)
        else {
            return false
        }
        self.imageZeroSelectedCheckmark = imageZeroSelectedCheckmark
        self.imageZeroSelectedThumbsUp = imageZeroSelectedThumbsUp
        self.imageZeroSelectedA = imageZeroSelectedA
        self.imageZeroSelected1 = imageZeroSelected1

        // One Selected
        guard let imageOneSelectedX = UIImage(named: twoActions_checkmarkX_iconNames.iconName1)?.tintedImage(tintColor: GlobalColors.selectedRed),
            let imageOneSelectedThumbsDown = UIImage(named: twoActions_thumbs_iconNames.iconName1)?.tintedImage(tintColor: GlobalColors.selectedRed),
            let imageOneSelectedExclamation = UIImage(named: threeActions_checkmarkExclamationX_iconNames.iconName1)?.tintedImage(tintColor: GlobalColors.selectedBlack),
            let imageOneSelectedB = UIImage(named: threeActions_ABC_iconNames.iconName1)?.tintedImage(tintColor: GlobalColors.selectedBlack),
            let imageOneSelected2 = UIImage(named: fiveActions_oneToFive_iconNames.iconName1)?.tintedImage(tintColor: GlobalColors.selectedRed)
            else {
                return false
        }
        self.imageOneSelectedX = imageOneSelectedX
        self.imageOneSelectedThumbsDown = imageOneSelectedThumbsDown
        self.imageOneSelectedExclamation = imageOneSelectedExclamation
        self.imageOneSelectedB = imageOneSelectedB
        self.imageOneSelected2 = imageOneSelected2

        // Two Selected
        guard let imageTwoSelectedX = UIImage(named: threeActions_checkmarkExclamationX_iconNames.iconName2)?.tintedImage(tintColor: GlobalColors.selectedRed),
            let imageTwoSelectedC = UIImage(named: threeActions_ABC_iconNames.iconName2)?.tintedImage(tintColor: GlobalColors.selectedRed),
            let imageTwoSelected3 = UIImage(named: fiveActions_oneToFive_iconNames.iconName2)?.tintedImage(tintColor: GlobalColors.selectedBlack)
            else {
                return false
        }
        self.imageTwoSelectedX = imageTwoSelectedX
        self.imageTwoSelectedC = imageTwoSelectedC
        self.imageTwoSelected3 = imageTwoSelected3

        // Three Selected
        guard let imageThreeSelected4 = UIImage(named: fiveActions_oneToFive_iconNames.iconName3)?.tintedImage(tintColor: GlobalColors.selectedBlue)
            else {
                return false
        }
        self.imageThreeSelected4 = imageThreeSelected4
        
        // Four Selected
        guard let imageFourSelected5 = UIImage(named: fiveActions_oneToFive_iconNames.iconName4)?.tintedImage(tintColor: GlobalColors.selectedBlue)
            else {
                return false
        }
        self.imageFourSelected5 = imageFourSelected5
        
        return true
    }
    
    fileprivate func resetSelectedImages() {
        // Zero Selected
        self.imageZeroSelectedCheckmark = nil
        self.imageZeroSelectedThumbsUp = nil
        self.imageZeroSelectedA = nil
        self.imageZeroSelected1 = nil
        
        // One Selected
        self.imageOneSelectedX = nil
        self.imageOneSelectedThumbsDown = nil
        self.imageOneSelectedExclamation = nil
        self.imageOneSelectedB = nil
        self.imageOneSelected2 = nil
        
        // Two Selected
        self.imageTwoSelectedX = nil
        self.imageTwoSelectedC = nil
        self.imageTwoSelected3 = nil
        
        // Three Selected
        self.imageThreeSelected4 = nil
        
        // Four Selected
        self.imageFourSelected5 = nil
    }
    
    fileprivate class func setupPDF(date: Date) {
        let document = singleton.document!
        let property = singleton.keyProperty!.property
        let inspection = singleton.keyInspection!.inspection
        
        var templateName = "<name missing>"
        if let template = Mapper<Template>().map(JSON: singleton.keyInspection!.inspection.template ?? [:]) {
            if let name = template.name {
                templateName = name
            }
        }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.setLocalizedDateFormatFromTemplate("E, MMM d, yyyy")
        let formattedDate = dateFormatter.string(from: date)
        document.info.title = "\(property.name ?? "Property"): \(formattedDate)"
        document.info.subject = "Sparkle Report"
        document.info.author = inspection.inspectorName ?? "Creator Unknown"
//        pdf.headerSpace = 32
//        pdf.footerSpace = 42
        
        // Header
        let image = UIImage(named: "app_icon_128")!
        document.addText(.headerCenter, text: "\(property.name ?? "Unknown Property") | \(inspection.inspectorName ?? "Creator Unknown") | \(formattedDate)")
        document.addText(.headerCenter, text: "Template: \(templateName)")
        document.addImage(.footerCenter, image: PDFImage(image: image, size: CGSize(width: 32, height: 32)))
        
//        document.addLineSeparator(.headerCenter, style: PDFLineStyle.none)
//        document.addLineSeparator(.footerCenter, style: PDFLineStyle.none)
//        pdf.addLineSeparator(.footerCenter, thickness: 0.1)
        
        // Footer
//        document.addText(.footerCenter, text: "Created using Sparkle for iOS.")

//        let lightFont = UIFont.systemFont(ofSize: 10, weight: UIFontWeightLight)
//        let title = NSMutableAttributedString(string: "Sapphire Inspections Report", attributes: [
//            NSFontAttributeName : lightFont,
//            NSForegroundColorAttributeName : UIColor.gray
//            ])
//        pdf.setFont(font: UIFont.systemFont(ofSize: 8, weight: UIFontWeightLight))
//        pdf.addText(.footerCenter, text: "Sapphire Inspections Report")
//        pdf.resetFont()
    }
    
    fileprivate class func showScore() {
        let document = singleton.document!
        let inspection = singleton.keyInspection!.inspection

        document.addSpace(space: 12.0)

        var scoreColor = GlobalColors.selectedBlue
        if inspection.deficienciesExist {
            scoreColor = GlobalColors.selectedRed
        }
        let score = String(format:"Score: %.1f", inspection.score) + "%"
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28.0),
            .foregroundColor: scoreColor
            ]
        let title = NSMutableAttributedString(string: score, attributes: attributes) 
        document.addAttributedText(text: title)
        
        document.addSpace(space: 12.0)
        //pdf.addLineSeparator(thickness: 0.1, color: UIColor.lightGray)
    }
    
    // Display an section's details of a section, plus start display items
    fileprivate class func displaySectionDetails(forSectionIndex sectionIndex: Int) {
        let document = singleton.document!
        let keySectionsWithKeyItems = singleton.keySectionsWithKeyItems!
        
        if sectionIndex >= keySectionsWithKeyItems.count {
            displayAdminEditsSummary()
            return
        }
        let keySectionWithKeyItems = keySectionsWithKeyItems[sectionIndex]

        let sectionFont = singleton.sectionFont
        
        document.addSpace(space: 30.0)
        //            let title = NSMutableAttributedString(string: keySectionWithKeyItems.section.title?.uppercased() ?? "Unknown Section Name".uppercased(), attributes: [
        //                NSFontAttributeName : sectionFont,
        //                NSForegroundColorAttributeName : UIColor.black
        //                ])
        //pdf.addAttributedText(text: title)
        document.setFont(font: sectionFont)
        document.setIndentation(indent: 0, left: true)
        document.addText(text: keySectionWithKeyItems.section.title?.uppercased() ?? "Unknown Section Name".uppercased())
        document.addSpace(space: 15)
        document.addLineSeparator(.contentLeft, style: PDFLineStyle(color: UIColor.lightGray, width: 0.1))

        displayItemDetails(forSectionIndex: sectionIndex, forItemIndex: 0)
    }
    
    // Display an item's details of a section/item
    fileprivate class func displayItemDetails(forSectionIndex sectionIndex: Int, forItemIndex itemIndex: Int) {
        print("displayItemDetails: \(sectionIndex) \(itemIndex)")

        let document = singleton.document!
        let keySectionsWithKeyItems = singleton.keySectionsWithKeyItems!

        if sectionIndex >= keySectionsWithKeyItems.count {
            print("PDF ERROR: unable to pull section: \(sectionIndex)")
            endPDF(success: false, errorMessage: "Failed to pull section \(sectionIndex) data.")
            return
        }
        
        let keySectionWithKeyItems = keySectionsWithKeyItems[sectionIndex]
        if itemIndex >= keySectionWithKeyItems.keyItems.count {
            displaySectionDetails(forSectionIndex: sectionIndex + 1)
            return
        }
        
        let item = keySectionWithKeyItems.keyItems[itemIndex].item
        let itemKey = keySectionWithKeyItems.keyItems[itemIndex].key
        let itemFont = singleton.itemFont
        let noteFont = singleton.noteFont
        let fontNA = singleton.fontNA

        //                let title = NSMutableAttributedString(string: keyItem.item.title?.capitalized ?? "Unknown Item Name", attributes: [
        //                    NSFontAttributeName : itemFont,
        //                    NSForegroundColorAttributeName : UIColor.black
        //                    ])
        //pdf.addAttributedText(text: title)
        document.addSpace(space: 12.0)
        document.setFont(font: itemFont)
        document.setIndentation(indent: 0, left: true)
        let type = item.templateItemType()
        switch type {
        case .main:
            document.addText(text: item.title?.capitalized ?? "Untitled:")
            document.setIndentation(indent: 10, left: true)
            if item.isItemNA {
                document.setFont(font: fontNA)
                document.addText(text: "NA")
            } else if let mainInputType = item.mainInputType, let mainInputTypeEnum = TemplateItemActions(rawValue: mainInputType.lowercased()) {
                if mainInputTypeEnum == .OneAction_notes {
                    if let mainInputNotes = item.mainInputNotes {
                        document.setFont(font: noteFont)
                        document.addText(text: mainInputNotes)
                    }
                } else {
                    if let mainInputSelection = item.mainInputSelection , item.mainInputSelected {
                        switch mainInputSelection {
                        case 0:
                            displayImageForZeroSelection(mainInputTypeEnum: mainInputTypeEnum)
                        case 1:
                            displayImageForOneSelection(mainInputTypeEnum: mainInputTypeEnum)
                        case 2:
                            displayImageForTwoSelection(mainInputTypeEnum: mainInputTypeEnum)
                        case 3:
                            displayImageForThreeSelection(mainInputTypeEnum: mainInputTypeEnum)
                        case 4:
                            displayImageForFourSelection(mainInputTypeEnum: mainInputTypeEnum)
                            
                        default:
                            break
                        }
                    }
                }
            }
        case .textInput:
            if item.isItemNA {
                document.addText(text: "\(item.title?.capitalized ?? "Untitled:") NA")
            } else {
                document.addText(text: "\(item.title?.capitalized ?? "Untitled:") \(item.textInputValue)")
            }
            document.setIndentation(indent: 10, left: true)
        case .signature:
            document.addText(text: "SIGNATURE")
            if item.isItemNA {
                document.setIndentation(indent: 10, left: true)
                document.setFont(font: fontNA)
                document.addText(text: "NA")
            } else {
                if item.signatureTimestampKey != "" {
                    if item.signatureDownloadURL == "" {
                        let keyInspection = singleton.keyInspection!
                        if let localImage = LocalInspectionImages.localInspectionItemImage(inspectionKey: keyInspection.key, itemKey: itemKey, key: item.signatureTimestampKey) {
                            let image = compressAndResizeImage(image: UIImage(data: localImage.imageData!)!)
                            document.addImage(image: PDFImage(image: image, size: CGSize(width: 200, height: 60), sizeFit: .widthHeight))
                        }
                    } else {
                        let signatureURL = URL(string: item.signatureDownloadURL)
                        let downloader = SDWebImageDownloader.shared
                        downloader.downloadImage(with: signatureURL, options: .highPriority, progress: { (receivedSize, expectedSize, targetURL) in
                        }, completed: { (image, data, error, finished) in
                            if let image = image , finished {
                                document.addImage(image: PDFImage(image: image, size: CGSize(width: 200, height: 60), sizeFit: .widthHeight))
                            }
                            
                            displayItemDetailsContinued(forSectionIndex: sectionIndex, forItemIndex: itemIndex)
                        })
                        
                        return
                    }
                }
            }
        case .unsupported:
            document.addText(text: "Unsupported Item (Update App)")
        }
        
        displayItemDetailsContinued(forSectionIndex: sectionIndex, forItemIndex: itemIndex)
    }
    
    fileprivate class func displayItemDetailsContinued(forSectionIndex sectionIndex: Int, forItemIndex itemIndex: Int) {
        print("displayItemDetailsContinued: \(sectionIndex) \(itemIndex)")
        
        let document = singleton.document!
        let keySectionsWithKeyItems = singleton.keySectionsWithKeyItems!
        let keySectionWithKeyItems = keySectionsWithKeyItems[sectionIndex]
        
        let item = keySectionWithKeyItems.keyItems[itemIndex].item
        let noteFont = singleton.noteFont
        let noteTitleFont = singleton.noteTitleFont
        
        document.addSpace(space: 4.0)
        document.setIndentation(indent: 30, left: true)
        if let inspectorNotes = item.inspectorNotes, inspectorNotes != "" {
            document.setFont(font: noteTitleFont)
            document.addText(text: "Notes:")
            document.setFont(font: noteFont)
            document.addText(text: inspectorNotes)
            document.addSpace(space: 4.0)
        }
        if item.sortedAdminEdits().count > 0 {
            document.setFont(font: noteTitleFont)
            document.addText(text: "Admin Edits:")
            document.setFont(font: noteFont)
            let formatter = DateFormatter()
            formatter.dateStyle = DateFormatter.Style.short
            formatter.timeStyle = .short
            for adminEdit in item.sortedAdminEdits() {
                if let editDate = adminEdit.editDate {
                    let formattedDate = formatter.string(from: editDate)
                    document.addText(text: "\(formattedDate): \(adminEdit.adminName) \(adminEdit.action).")
                }
            }
            document.addSpace(space: 4.0)
        }
        
        if item.photosData.isEmpty {
            DispatchQueue.main.async {
                displayItemDetails(forSectionIndex: sectionIndex, forItemIndex: itemIndex + 1)
            }
        } else {
            var photos: [GalleryPhotoModel] = []
            for (key, value) in item.photosData {
                if let value = value as? [String: AnyObject], let downloadURL = value["downloadURL"] as? String {
                    let caption = value["caption"] as? String ?? ""
                    let photo = GalleryPhotoModel()
                    photo.itemPhotoDataKey = key
                    if downloadURL == "" {
                        let keyItem = keySectionWithKeyItems.keyItems[itemIndex]
                        let keyInspection = singleton.keyInspection!
                        if let localImage = LocalInspectionImages.localInspectionItemImage(inspectionKey: keyInspection.key, itemKey: keyItem.key, key: key) {
                            print("Loaded offline photo with key=\(key)")
                            photo.image = compressAndResizeImage(image: UIImage(data: localImage.imageData!)!)
                        } else {
                            let section = keySectionWithKeyItems.section
                            print("ERROR: Failed to load offline photo for SECTION: \(section.title ?? "") ITEM: \(keyItem.item.title ?? "")")
                            let attributes: [NSAttributedString.Key: Any] = [
                                .font: UIFont.systemFont(ofSize: 20.0),
                                .foregroundColor: GlobalColors.selectedRed
                                ]
                            let errorText = NSMutableAttributedString(string: "[ missing image ]", attributes: attributes)
                            document.addAttributedText(text: errorText)
                            // TODO: Add back, once we have a solution
                            //endPDF(success: false, errorMessage: "Failed to pull locally saved image for SECTION: \(section.title ?? "") ITEM: \(keyItem.item.title ?? ""). Please contact an admin to correct.")
                            //return
                            continue
                        }
                    }
                    photo.imageURL = URL(string: downloadURL)
                    photo.attributedTitle = NSAttributedString(string: caption)
                    photos.append(photo)
                }
            }
            photos.sort(by: { $0.itemPhotoDataKey! < $1.itemPhotoDataKey! } )
            displayItemImages(forSectionIndex: sectionIndex, forItemIndex: itemIndex, photos: photos, nextImageIndex: 0)
        }
    }
    
    fileprivate class func displayItemImages(forSectionIndex sectionIndex: Int, forItemIndex itemIndex: Int, photos: [GalleryPhotoModel], nextImageIndex: Int) {
        print("displayItemImages: \(sectionIndex) \(itemIndex) \(nextImageIndex)")
        if nextImageIndex == photos.count {
            print("all images ready")
            let document = singleton.document!
//            var imageIndex: Int = 0
//            while imageIndex < photos.count {
//                let imagesLeft: Int = photos.count - imageIndex
//                var photosToAdd : [GalleryPhotoModel] = []
//                var imagesToAdd : [UIImage] = []
//                var captionsToAdd : [NSAttributedString] = []
//                if imagesLeft >= 4 {
//                    photosToAdd = Array<GalleryPhotoModel>(photos[imageIndex...imageIndex+3])
//                    imageIndex += 4
//                } else if imagesLeft > 1 {
//                    photosToAdd = Array<GalleryPhotoModel>(photos[imageIndex...imageIndex+imagesLeft-1])
//                    imageIndex += imagesLeft
//                } else {
//                    photosToAdd.append(photos[imageIndex])
//                    imageIndex += 1
//                }
//                for photo in photosToAdd {
//                    imagesToAdd.append(photo.image!)
//                    captionsToAdd.append(photo.attributedTitle ?? NSAttributedString(string: ""))
//                }
//            
//                pdf.addImagesInRow(images: imagesToAdd, captions: captionsToAdd, spacing: 10.0)
//            }
            for photo in photos {
                if let image = photo.image {
                    document.addImage(image: PDFImage(image: image, caption: PDFAttributedText(text: photo.attributedTitle ?? NSAttributedString(string: "")), size: CGSize(width: 200, height: 200), sizeFit: .height))
                    document.addSpace(space: 10.0)
                }
            }
            DispatchQueue.main.async {
                displayItemDetails(forSectionIndex: sectionIndex, forItemIndex: itemIndex + 1)
            }
        } else {
            let photo: GalleryPhotoModel? = photos[nextImageIndex]
            if photo != nil {
                photo!.loadImageWithCompletionHandler({ (image, error) in
                    DispatchQueue.main.async(execute: {
                        if let image = image, error == nil {
                            photo!.image = compressAndResizeImage(image: image)
                            displayItemImages(forSectionIndex: sectionIndex, forItemIndex: itemIndex, photos: photos, nextImageIndex: nextImageIndex + 1)
                        } else {
                            let keySectionsWithKeyItems = singleton.keySectionsWithKeyItems!
                            let section = keySectionsWithKeyItems[sectionIndex].section
                            let item = keySectionsWithKeyItems[sectionIndex].keyItems[itemIndex].item
                            endPDF(success: false, errorMessage: "Failed to download photo for SECTION: \(section.title ?? "") ITEM: \(item.title ?? "") Please contact an admin to correct.")
                        }
                    })
                })
            } else {
                print("ERROR: GalleryPhotoModel photo was nil")
                displayItemImages(forSectionIndex: sectionIndex, forItemIndex: itemIndex, photos: photos, nextImageIndex: nextImageIndex + 1)
            }
        }
    }
    
    fileprivate class func displayImageForZeroSelection(mainInputTypeEnum: TemplateItemActions) {
        let document = singleton.document!

        switch mainInputTypeEnum {
        case .TwoActions_checkmarkX:
            document.addImage(image: PDFImage(image: singleton.imageZeroSelectedCheckmark!, size: CGSize(width: 24, height: 24), sizeFit: .height))
        case .TwoActions_thumbs:
            document.addImage(image: PDFImage(image: singleton.imageZeroSelectedThumbsUp!, size: CGSize(width: 24, height: 24), sizeFit: .height))
        case .ThreeActions_checkmarkExclamationX:
            document.addImage(image: PDFImage(image: singleton.imageZeroSelectedCheckmark!, size: CGSize(width: 24, height: 24), sizeFit: .height))
        case .ThreeActions_ABC:
            document.addImage(image: PDFImage(image: singleton.imageZeroSelectedA!, size: CGSize(width: 24, height: 24), sizeFit: .height))
        case .FiveActions_oneToFive:
            document.addImage(image: PDFImage(image: singleton.imageZeroSelected1!, size: CGSize(width: 24, height: 24), sizeFit: .height))
        case .OneAction_notes:
            break
        }
    }
    
    fileprivate class func displayImageForOneSelection(mainInputTypeEnum: TemplateItemActions) {
        let document = singleton.document!

        switch mainInputTypeEnum {
        case .TwoActions_checkmarkX:
            document.addImage(image: PDFImage(image: singleton.imageOneSelectedX!, size: CGSize(width: 24, height: 24), sizeFit: .height))
        case .TwoActions_thumbs:
            document.addImage(image: PDFImage(image: singleton.imageOneSelectedThumbsDown!, size: CGSize(width: 24, height: 24), sizeFit: .height))
        case .ThreeActions_checkmarkExclamationX:
            document.addImage(image: PDFImage(image: singleton.imageOneSelectedExclamation!, size: CGSize(width: 24, height: 24), sizeFit: .height))
        case .ThreeActions_ABC:
            document.addImage(image: PDFImage(image: singleton.imageOneSelectedB!, size: CGSize(width: 24, height: 24), sizeFit: .height))
        case .FiveActions_oneToFive:
            document.addImage(image: PDFImage(image: singleton.imageOneSelected2!, size: CGSize(width: 24, height: 24), sizeFit: .height))
        case .OneAction_notes:
            break
        }
    }
    
    fileprivate class func displayImageForTwoSelection(mainInputTypeEnum: TemplateItemActions) {
        let document = singleton.document!

        switch mainInputTypeEnum {
        case .TwoActions_checkmarkX:
            break
        case .TwoActions_thumbs:
            break
        case .ThreeActions_checkmarkExclamationX:
            document.addImage(image: PDFImage(image: singleton.imageTwoSelectedX!, size: CGSize(width: 24, height: 24), sizeFit: .height))
        case .ThreeActions_ABC:
            document.addImage(image: PDFImage(image: singleton.imageTwoSelectedC!, size: CGSize(width: 24, height: 24), sizeFit: .height))
        case .FiveActions_oneToFive:
            document.addImage(image: PDFImage(image: singleton.imageTwoSelected3!, size: CGSize(width: 24, height: 24), sizeFit: .height))
        case .OneAction_notes:
            break
        }
    }
    
    fileprivate class func displayImageForThreeSelection(mainInputTypeEnum: TemplateItemActions) {
        let document = singleton.document!

        switch mainInputTypeEnum {
        case .TwoActions_checkmarkX:
            break
        case .TwoActions_thumbs:
            break
        case .ThreeActions_checkmarkExclamationX:
            break
        case .ThreeActions_ABC:
            break
        case .FiveActions_oneToFive:
            document.addImage(image: PDFImage(image: singleton.imageThreeSelected4!, size: CGSize(width: 24, height: 24), sizeFit: .height))
        case .OneAction_notes:
            break
        }
    }
    
    fileprivate class func displayImageForFourSelection(mainInputTypeEnum: TemplateItemActions) {
        let document = singleton.document!

        switch mainInputTypeEnum {
        case .TwoActions_checkmarkX:
            break
        case .TwoActions_thumbs:
            break
        case .ThreeActions_checkmarkExclamationX:
            break
        case .ThreeActions_ABC:
            break
        case .FiveActions_oneToFive:
            document.addImage(image: PDFImage(image: singleton.imageFourSelected5!, size: CGSize(width: 24, height: 24), sizeFit: .height))
        case .OneAction_notes:
            break
        }
    }

    fileprivate class func endPDF(success: Bool, errorMessage: String) {
        let document = singleton.document!
        let completion = singleton.completion!
        let keyProperty = singleton.keyProperty!
        let keyInspection = singleton.keyInspection!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let creationDate = formatter.string(from: keyInspection.inspection.creationDate!)

        let propertyName = (keyProperty.property.name?.capitalized ?? "Property").replacingOccurrences(of: " ", with: "_")
        let fileName = "\(propertyName)_-_SparkleReport_-_\(creationDate)"
        
        let url = try! PDFGenerator.generateURL(document: document, filename: fileName)
        
        completion(fileName, url, success, errorMessage)
        
        // Clear data
        singleton.document = nil
        singleton.keyInspection = nil
        singleton.keyProperty = nil
        singleton.keySectionsWithKeyItems = nil
        singleton.completion = nil
        singleton.resetSelectedImages()
    }
    
    fileprivate class func compressAndResizeImage(image: UIImage) -> UIImage {
        let newImageSize = image.RBResizeImage(CGSize(width: 480, height: 480))
        let jpegData = newImageSize.jpegData(compressionQuality: 0.8)
        return UIImage(data: jpegData!)!
    }
    
    fileprivate class func displayAdminEditsSummary() {
        let document = singleton.document!
        let keySectionsWithKeyItems = singleton.keySectionsWithKeyItems!
        var adminEditCountsDict: [String: Int] = [:]
        for keySectionWithKeyItems in keySectionsWithKeyItems {
            for keyItem in keySectionWithKeyItems.keyItems {
                if keyItem.item.adminEdits.count > 0 {
                    for adminEdit in keyItem.item.adminEdits.values {
                        let count = (adminEditCountsDict[adminEdit.adminName] ?? 0) + 1
                        adminEditCountsDict[adminEdit.adminName] = count
                    }
                }
            }
        }
        
        if adminEditCountsDict.count > 0 {
            document.addSpace(space: 48.0)
            document.setIndentation(indent: 0, left: true)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22.0),
                .foregroundColor: GlobalColors.lightBlue,
                ]
            let title = NSMutableAttributedString(string: "Summary of Admin Activity", attributes: attributes)
            document.addAttributedText(text: title)
            document.addSpace(space: 15.0)
            document.addLineSeparator(.contentLeft, style: PDFLineStyle(color: UIColor.lightGray, width: 0.1))
            let adminFont = singleton.adminFont
            document.setIndentation(indent: 10, left: true)
            document.setFont(font: adminFont)
            for (adminName, countOfEdits) in adminEditCountsDict {
                document.addSpace(space: 4.0)
                document.addText(text: "\(adminName) made a total of \(countOfEdits) edit\(countOfEdits == 1 ? "" : "s" ).")
            }
        }
        
        endPDF(success: true, errorMessage: "")
    }
}
