//WORK IN PROGRESS
import UIKit

public struct PieLineTextLayerSettings {
    public var label: PieChartLabelSettings = PieChartLabelSettings()
    public init() {}
}

open class PieLineTextLayer: PieChartLayer {
    public weak var chart: PieChart?
    public var settings: PieLineTextLayerSettings = PieLineTextLayerSettings()
    fileprivate var sliceViews = [PieSlice: (CALayer, UILabel)]()
    public var animator: PieLineTextLayerAnimator = AlphaPieLineTextLayerAnimator()
    public init() {}
    public func onEndAnimation(slice: PieSlice) { addItems(slice: slice) }
    
    public func addItems(slice: PieSlice) {
        guard sliceViews[slice] == nil else { return }
        let angle = slice.view.midAngle.truncatingRemainder(dividingBy: (CGFloat.pi * 2))
        var isLeftSide = angle >= 0 && angle <= (CGFloat.pi / 2) || (angle > (CGFloat.pi * 3 / 2) && angle <= CGFloat.pi * 2)
        var p1Angle = slice.view.midAngle
        if slice.data.percentage > 0.5833 {
            isLeftSide = true
            p1Angle = slice.view.referenceAngle + 20
        }
        let p1 = slice.view.calculatePosition(angle: p1Angle, p: slice.view.center, offset: slice.view.outerRadius + 5)
        let p2 = CGPoint(p1.x + (p1.x - slice.view.center.x) / 4, slice.view.center.y - slice.view.outerRadius - 15 - pies[0].selectedOffset + slice.view.selectedOffset)
        let segment1Length = p1.distance(p: p2)
        let segment2Length = sqrt(segment1Length * segment1Length - (p2.y - p1.y) * (p2.y - p1.y))
        let p3 = CGPoint(x: p2.x + (isLeftSide ? -segment2Length : segment2Length), y: p2.y)
        
        let lineLayer = slice.data.model.value == 0 ? createLine(p1: CGPoint(x: 0, y: 0), p2: CGPoint(x: 0, y: 0), p3: CGPoint(x: 0, y: 0)) : createLine(p1: p1, p2: p2, p3: p3)
        let label = createLabel(slice: slice, isLeftSide: isLeftSide, referencePoint: p3)
        
        chart?.container.addSublayer(lineLayer)
        animator.animate(lineLayer)
        chart?.addSubview(label)
        animator.animate(label)
        sliceViews[slice] = (lineLayer, label)
    }
    
    public func createLine(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CALayer {
        let path = UIBezierPath()
        path.move(to: p1)
        path.addLine(to: p2)
        path.addLine(to: p3)
        
        let layer = CAShapeLayer()
        layer.path = path.cgPath
        layer.strokeColor = UIColor.white.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.borderWidth = 1
        layer.isHidden = true
        
        return layer
    }
    
    public func createLabel(slice: PieSlice, isLeftSide: Bool, referencePoint: CGPoint) -> UILabel {
        let label: UILabel = settings.label.labelGenerator?(slice) ?? {
            let label = UILabel()
            label.backgroundColor = settings.label.bgColor
            label.textColor = settings.label.textColor
            label.font = settings.label.font
            return label
        }()
        label.text = slice.data.model.value == 0 ? "" : slice.data.model.description
        label.sizeToFit()
        label.frame.origin = CGPoint(x: referencePoint.x - (isLeftSide ? label.frame.width : 0) + ((isLeftSide ? -1 : 1) * 5), y: referencePoint.y - label.frame.height / 2)
        label.isHidden = true
        return label
    }
    
    public func onSelected(slice: PieSlice, selected: Bool) {
        guard let (layer, label) = sliceViews[slice] else { return }
        let offset = selected ? slice.view.selectedOffset : -slice.view.selectedOffset
        layer.isHidden = false
        label.isHidden = false
        UIView.animate(withDuration: 0.15) { label.center = slice.view.calculatePosition(angle: slice.view.midAngle, p: label.center, offset: offset) }
        layer.position = slice.view.calculatePosition(angle: slice.view.midAngle, p: layer.position, offset: offset)
    }
    
    public func clear() {
        for (_, layerView) in sliceViews {
            layerView.0.removeFromSuperlayer()
            layerView.1.removeFromSuperview()
        }
        sliceViews.removeAll()
    }
}

public protocol PieLineTextLayerAnimator {
    func animate(_ layer: CALayer)
    func animate(_ label: UILabel)
}
public struct AlphaPieLineTextLayerAnimator: PieLineTextLayerAnimator {
    public var duration: TimeInterval = 0.3
    public func animate(_ layer: CALayer) {
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 0
        anim.toValue = 1
        anim.duration = duration
        layer.add(anim, forKey: "alphaAnim")
    }
    public func animate(_ label: UILabel) {
        label.alpha = 0
        UIView.animate(withDuration: duration) { label.alpha = 1 }
    }
}
