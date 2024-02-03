//
//  UIHelpers.swift
//

import UIKit

extension String {
    func heightWithConstrainedWidth(width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font
        ]
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
        
        return boundingBox.height
    }
    
    func htmlEncodedString() -> String? {
        
        guard let data = self.data(using: .utf8) else {
            return nil
        }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        guard let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }
        
        return attributedString.string
    }
}

extension NSAttributedString {
    func heightWithConstrainedWidth(width: CGFloat) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, context: nil)
        
        return boundingBox.height
    }
    
    func widthWithConstrainedHeight(height: CGFloat) -> CGFloat {
        let constraintRect = CGSize(width: .greatestFiniteMagnitude, height: height)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, context: nil)
        
        return boundingBox.width
    }
}

extension UIImage {

    public func imageFromAspectFillToSize(_ size: CGSize) -> UIImage {
        //Create the bitmap graphics context
        UIGraphicsBeginImageContextWithOptions(CGSize(width: size.width, height: size.height), false, 1.0)  // 1.0 for exact pixels
        let context = UIGraphicsGetCurrentContext()
        
        //Get the width and heights
        let imageWidth = self.size.width
        let imageHeight = self.size.height
        let rectWidth = size.width
        let rectHeight = size.height
        
        //Calculate the scale factor
        let scaleFactorX = rectWidth/imageWidth;
        let scaleFactorY = rectHeight/imageHeight;

        let scaleFactor = (scaleFactorX <= scaleFactorY) ? scaleFactorX : scaleFactorY
        
        //Set the SCALE factor for the graphics context
        //All future draw calls will be scaled by this factor
        context?.scaleBy(x: scaleFactor, y: scaleFactor)
        
        // Draw the IMAGE
        let myRect = CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)
        self.draw(in: myRect)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        // Calculate x and y for a center crop
        let refWidth = imageWidth * scaleFactor
        let refHeight = imageHeight * scaleFactor
        let x = (refWidth - rectWidth) / 2.0
        let y = (refHeight - rectHeight) / 2.0
        
        let cropRect = CGRect(x: x, y: y, width: rectWidth, height: rectHeight)
        let imageRef = newImage?.cgImage?.cropping(to: cropRect)
        
        return UIImage(cgImage: imageRef!)
    }
    
    // https://gist.github.com/justinlevi/ee037a4bb63598f6e56f
    func RBSquareImageTo(_ size: CGSize) -> UIImage? {
        return self.RBSquareImage()?.RBResizeImage(size)
    }
    
    func RBSquareImage() -> UIImage? {
        let originalWidth  = self.size.width
        let originalHeight = self.size.height
        
        var edge: CGFloat
        if originalWidth > originalHeight {
            edge = originalHeight
        } else {
            edge = originalWidth
        }
        
        let posX = (originalWidth  - edge) / 2.0
        let posY = (originalHeight - edge) / 2.0
        
        let cropSquare = CGRect(x: posX, y: posY, width: edge, height: edge)
        
        let imageRef = self.cgImage?.cropping(to: cropSquare);
        return UIImage(cgImage: imageRef!, scale: UIScreen.main.scale, orientation: self.imageOrientation)
    }
    
    func RBResizeImage(_ targetSize: CGSize) -> UIImage {
        let size = self.size
        
        let widthRatio  = targetSize.width  / self.size.width
        let heightRatio = targetSize.height / self.size.height
        
        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }
        
        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0) // Ignore scaling of main screen
        self.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
    
    func tintedImage(tintColor: UIColor) -> UIImage {
        var newImage = self.withRenderingMode(.alwaysTemplate)
        UIGraphicsBeginImageContextWithOptions(self.size, false, newImage.scale)
        tintColor.set()
        newImage.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext();
        
        return newImage
    }
}

extension UIView {
    
    /**
     Returns an UIImage of the UIView, within its bounds.
     
     - returns: An UIImage of self, within its bounds
     */
    public func imageOfSelf() -> UIImage {
        assert(self.frame.height > 0 && self.frame.width > 0)
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, self.isOpaque, 0.0)
        self.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
}

extension UIView {

    /**
    Returns the frame of this view in the coordinate space of view's frame,
    so if this view were placed as a sibling of view, with the returned frame,
    its absolute position in the window would remain unchanged.

    - parameter view: to calulcate frame relative to

    - returns: The target frame in the same coordinate space as `view`'s frame
    */
    public func frameRelativeToView(_ view: UIView) -> CGRect {
        assert(view.superview != nil)
        return view.superview!.convert(bounds, from: self)
    }
}

/**
A set of extensions to UIView making CALayer properties @IBInspectable.
These are prefixed to avoid collisions with other classes which may implement
their own `cornerRadius` values
*/
extension UIView {

    @IBInspectable var s_cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
        }
    }

    @IBInspectable var s_borderColor: UIColor? {
        get {
            return layer.borderColor != nil ? UIColor(cgColor: layer.borderColor!) : nil
        }
        set {
            layer.borderColor = newValue?.cgColor
        }
    }

    @IBInspectable var s_borderWidth: CGFloat {
        get {
            return layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
        }
    }
}

extension UIView {
    
    /// Adds constraints to this `UIView` instances `superview` object to make sure this always has the same size as the superview.
    /// Please note that this has no effect if its `superview` is `nil` – add this `UIView` instance as a subview before calling this.
    func bindFrameToSuperview() {
        guard let superview = self.superview else {
            print("Error! `superview` was nil – call `addSubview(view: UIView)` before calling `bindFrameToSuperviewBounds()` to fix this.")
            return
        }
        
        self.translatesAutoresizingMaskIntoConstraints = false
        superview.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[subview]-0-|", options: .directionLeadingToTrailing, metrics: nil, views: ["subview": self]))
        superview.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[subview]-0-|", options: .directionLeadingToTrailing, metrics: nil, views: ["subview": self]))
    }
}

public extension UIColor {

    /**
    Helper for constructing a UIColor from three 8-bit values:
    ``UIColor(red: 229, green: 233, blue: 235)``

    - parameter red: 8 bit red component
    - parameter green: 8 bit red component
    - parameter blue:  8 bit red component
    */
    convenience init(red: UInt8, green: UInt8, blue: UInt8) {
        self.init(red: CGFloat(red)/255.0, green: CGFloat(green)/255.0, blue: CGFloat(blue)/255.0, alpha: 1)
    }

    /// True if this color has an alpha of 0
    var isClear: Bool {
        var alpha: CGFloat = 0
        if getWhite(nil, alpha: &alpha) {
            return alpha == 0
        }
        if getRed(nil, green: nil, blue: nil, alpha: &alpha) {
            return alpha == 0
        }
        return false
    }
}

public extension UILabel {

    /// Sets the line spacing of the text in this label. If the label's
    /// text is not an attributed string, it will be converted to one.
    /// see `NSParagraphStyle.lineSpacing`
    @IBInspectable var sc_lineSpacing: CGFloat {
        set {
            setLineSpacing(self, lineSpacing: newValue)
        }
        get {
            if let paragraphStyle = sc_paragraphStyle {
                return paragraphStyle.lineSpacing
            } else {
                return 1
            }
        }
    }

    /// The line height multiplier used in this label. If the label's
    /// text is not an attributed string, it will be converted to one.
    /// see `NSParagraphStyle.lineHeightMultiple`
    @IBInspectable var sc_lineHeightMultiple: CGFloat {
        set {
            setLineSpacing(self, lineHeightMultiple: newValue)
        }
        get {
            if let paragraphStyle = sc_paragraphStyle {
                return paragraphStyle.lineHeightMultiple
            } else {
                return 0
            }
        }
    }

    /// Returns the NSParagraphStyle associated with this
    /// label's attributedText if it exists
    var sc_paragraphStyle: NSParagraphStyle? {
        return attributedText?.attribute(NSAttributedString.Key.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
    }
}


/**
Sets the underlined attribute on a UIButton's title, keeping its existing font and color.

Buttons with underlined text are used several places in the app, but configuring the title
to be underlined is nontrivial.

- parameter button: The button to style
*/
public func underlineTitle(_ button: UIButton, forState state: UIControl.State = UIControl.State()) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: button.titleLabel!.font,
        .underlineStyle: NSUnderlineStyle.single.rawValue
    ]
    let attributedText = NSAttributedString(
        string: button.title(for: state) ?? button.title(for: UIControl.State())!,
        attributes: attributes)
    button.setAttributedTitle(attributedText, for: state)
}

/**
Constructs an NSParagraphStyle and sets `lineSpacing` and `lineHeightMultiple`
to the provided values, then attaches the paragraph style to `label`'s attributedText
(converting the text to attributedText if necessary)

- parameter label:
- parameter lineSpacing:
- parameter lineHeightMultiple:
*/
public func setLineSpacing(_ label: UILabel, lineSpacing: CGFloat? = nil, lineHeightMultiple: CGFloat? = nil) {
    let paragraphStyle = (label.sc_paragraphStyle ?? NSParagraphStyle.default).mutableCopy() as! NSMutableParagraphStyle

    if let lineSpacing = lineSpacing {
        paragraphStyle.lineSpacing = lineSpacing
    }
    if let lineHeightMultiple = lineHeightMultiple {
        paragraphStyle.lineHeightMultiple = lineHeightMultiple
    }
    paragraphStyle.alignment = label.textAlignment
    
    var attributedString = label.attributedText!.mutableCopy() as? NSMutableAttributedString
    if attributedString == nil {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: label.font,
            .foregroundColor: label.textColor
        ]
        attributedString = NSMutableAttributedString(string: label.text!, attributes: attributes)
    }

    attributedString!.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: NSMakeRange(0, attributedString!.length))
    label.attributedText = attributedString
}

/**
Helper function to create an image drawing context, execute some drawing code,
then return an image of whatever `drawingBlock` performed in the context

- parameter size:         Size of resulting UIImage
- parameter drawingBlock: Block that performs Core Graphics drawing operations on context

- returns: A UIImage of whatever `drawingBlock` drew
*/
public func drawImage(_ size: CGSize, drawingBlock: (CGContext) -> Void) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(size, false, 0)
    drawingBlock(UIGraphicsGetCurrentContext()!)
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image!
}

/**
Converts degrees to radians
*/
public func radians(_ degrees: CGFloat) -> CGFloat {
    return degrees / 180.0 * PI()
}

/**
Linearly interpolates between start and end by the given percentage amount,
e.g. interpolate(1, 5, 0.5) -> 3, because 3 is halfway between 1 and 5.
This uses the accurate algorithm from
http://en.wikipedia.org/wiki/Linear_interpolation#Programming_language_support

- parameter start:  The low number to interpolate between
- parameter end:    The high number to interpolat between
- parameter amount: The distance between the two numbers to interpolate

- returns: A number `amount` percent between `start` and `end`
*/
public func interpolate(_ start: CGFloat, end: CGFloat, amount: CGFloat) -> CGFloat {
    // (1-t)*v0 + t*v1;
    return (1 - amount) * start + (amount * end)
}

/**
Given a value between low and high, returns the position of that value
as a percentage.
e.g. reverse_interpolate(0.5, 1, 0.8) -> 0.6 because 0.8 is 60% of the way from 0.5 to 1

- parameter low:    the low value to position
- parameter high:   the high value to position
- parameter amount: a distance between low and high

- returns: the percentage distance position sits between low and high
*/
public func percent_between(_ low: CGFloat, high: CGFloat, position: CGFloat) -> CGFloat {
    return (position - low) / (high - low)
}

public func PI() -> CGFloat {
    return CGFloat(Float.pi)
}

public func PI() -> Double {
    return Double.pi
}

public func PI() -> Float {
    return Float.pi
}

/**
Gathers all the data defined in `Keyboard Notification User Info Keys` from
a keyboard will/did show/hide `NSNotification` into an easier to use tuple.

- parameter notification: A notification resulting from a keyboard appearance notification,
        e.g. `UIKeyboardWillShowNotification`

- returns: A tuple of data about the keyboard appearance extracted from the notification user info.
*/
public func keyboardInfoFromNotification(_ notification: Notification) -> (beginFrame: CGRect, endFrame: CGRect, animationCurve: UIView.AnimationOptions, animationDuration: Double) {
    let userInfo = (notification as NSNotification).userInfo!
    let beginFrameValue = userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as! NSValue
    let endFrameValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue
    let animationCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as! NSNumber
    let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as! NSNumber

    return (
        beginFrame:         beginFrameValue.cgRectValue,
        endFrame:           endFrameValue.cgRectValue,
        animationCurve:     UIView.AnimationOptions(rawValue: UInt(animationCurve.uintValue << 16)),
        animationDuration:  animationDuration.doubleValue)
}
