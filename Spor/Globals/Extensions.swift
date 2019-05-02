////////10////////20////////30////////40////////50////////60////////70////////80
import UIKit

extension CGPoint {
    init(_ x: CGFloat, _ y: CGFloat) { self.init(x: x, y: y) }
    func distance(p: CGPoint) -> CGFloat {
        return sqrt(((p.x - x) * (p.x - x)) + ((p.y - y) * (p.y - y)))
    }
}

extension CGRect {
    init(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) {
        self.init(x: x, y: y, width: width, height: height)
    }
    var center: CGPoint {
        return CGPoint(x: origin.x + width / 2, y: origin.y + height / 2)
    }
}

extension CGSize{
    init(_ width: CGFloat, _ height: CGFloat) {
        self.init(width: width, height: height)
    }
    func contains(_ size: CGSize) -> Bool {
        return width >= size.width && height >= size.height
    }
}

extension Date {
    func toString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter.string(from: self)
    }
}

extension FloatingPoint {
    var degreesToRadians: Self { return self * .pi / 180 }
    var radiansToDegrees: Self { return self * 180 / .pi }
    func truncate(_ fractions: Self) -> Self {
        return Darwin.round(self * fractions) / fractions
    }
}

extension Int {
    var degreesToRadians: Double { return Double(self) * .pi / 180 }
    var radiansToDegrees: Double { return Double(self) * 180 / .pi }
}

extension String {
    func currencyFormat() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currencyAccounting
        formatter.currencySymbol =
            UserDefaults.standard.string(forKey: "Currency")
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2

        let regex = try! NSRegularExpression(
            pattern: "[^0-9]",
            options: .caseInsensitive
        )
        
        let entry =
            regex.stringByReplacingMatches(
                in: self,
                options: NSRegularExpression.MatchingOptions(rawValue: 0),
                range: NSMakeRange(0, self.count),
                withTemplate: ""
            ) as NSString
        
        return formatter.string(from: min(entry.doubleValue / 100, 999999.99)
            as NSNumber) ?? ""
    }
    func toDate() -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter.date(from: self) ?? Date()
    }
}

extension UIColor {
    func lighter(by percentage: CGFloat = 30.0) -> UIColor? {
        return self.adjust(by: abs(percentage))
    }
    func darker (by percentage: CGFloat = 30.0) -> UIColor? {
        return self.adjust(by: abs(percentage) * -1)
    }
    func adjust (by percentage: CGFloat = 30.0) -> UIColor? {
        var r = CGFloat(0), g = CGFloat(0), b = CGFloat(0), a = CGFloat(0)
        if self.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return UIColor(
                red:   min(r + percentage / 100, 1.0),
                green: min(g + percentage / 100, 1.0),
                blue:  min(b + percentage / 100, 1.0),
                alpha: a
            )
        } else { return nil }
    }
}

extension UILabel {
    func getFontSizeForLabel() -> CGFloat {
        let text = self.attributedText == nil ?
            NSMutableAttributedString() :
            NSMutableAttributedString(attributedString: self.attributedText!)
        text.setAttributes(
            [NSAttributedString.Key.font: self.font],
            range: NSMakeRange(0, text.length)
        )
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = self.minimumScaleFactor
        text.boundingRect(
            with: self.frame.size,
            options: NSStringDrawingOptions.usesLineFragmentOrigin,
            context: context
        )
        return self.font.pointSize * context.actualScaleFactor
    }
}
////////10////////20////////30////////40////////50////////60////////70////////80
