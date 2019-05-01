////////////////////////////////////////////////////////////////////////////////
import UIKit

@IBDesignable class DesignableButton: UIButton {
    @IBInspectable var borderColor = UIColor.clear {
        didSet { layer.borderColor = borderColor.cgColor }
    }
    @IBInspectable var borderWidth = CGFloat(0) {
        didSet { layer.borderWidth = borderWidth }
    }
    @IBInspectable var cornerRadius = CGFloat(0) {
        didSet { layer.cornerRadius = cornerRadius }
    }
    @IBInspectable var adjustsFontSizeToFitWidth = true {
        didSet { titleLabel?.adjustsFontSizeToFitWidth = true }
    }
}

@IBDesignable class DesignableView: UIView {
    @IBInspectable var borderColor = UIColor.clear {
        didSet { layer.borderColor = borderColor.cgColor }
    }
    @IBInspectable var borderWidth = CGFloat(0) {
        didSet { layer.borderWidth = borderWidth }
    }
    @IBInspectable var cornerRadius = CGFloat(0) {
        didSet { layer.cornerRadius = cornerRadius }
    }
}

class DesignableTextField: UITextField {
    var tintedClearImage: UIImage?
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        setupTintColor()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTintColor()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        tintClearImage()
    }
    
    func setupTintColor() {
        textColor = .white
        backgroundColor = greyDarkest
        layer.borderColor = teal.cgColor
        borderStyle = .roundedRect
        layer.borderWidth = 0
        layer.cornerRadius = 5
        layer.masksToBounds = true
    }

    func tintImage(image: UIImage, color: UIColor) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(at: CGPoint.zero, blendMode: CGBlendMode.normal, alpha: 1.0)
        
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(color.cgColor)
        context?.setBlendMode(CGBlendMode.sourceIn)
        context?.setAlpha(1.0)

        UIGraphicsGetCurrentContext()?.fill(CGRect(
            CGPoint.zero.x,
            CGPoint.zero.y,
            image.size.width,
            image.size.height
        ))
        if let tintedImage = UIGraphicsGetImageFromCurrentImageContext() {
            UIGraphicsEndImageContext()
            return tintedImage
        }
        UIGraphicsEndImageContext()
        return UIImage()
    }
    
    private func tintClearImage() {
        for view in subviews {
            if let button = view as? UIButton {
                if let uiImage = button.image(for: .highlighted) {
                    if tintedClearImage == nil {
                        tintedClearImage =
                            tintImage(image: uiImage, color: tintColor)
                    }
                    button.setImage(tintedClearImage, for: .normal)
                    button.setImage(tintedClearImage, for: .highlighted)
                }
            }
        }
    }
}
////////////////////////////////////////////////////////////////////////////////
