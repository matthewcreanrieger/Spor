//COMMENTING IN PROGRESS
////////10////////20////////30////////40////////50////////60////////70////////80
import UIKit

open class PiePlainTextLayerSettings {
    public var viewRadius: CGFloat?
    public var hideOnOverflow = false
    public init() {}
    public var label: PieChartLabelSettings = PieChartLabelSettings()
}

public protocol PieViewLayerAnimator {
    func animate(_ view: UIView)
}
public struct AlphaPieViewLayerAnimator: PieViewLayerAnimator {
    public var duration = TimeInterval(0.3)
    public func animate(_ view: UIView) {
        view.alpha = 0
        UIView.animate(withDuration: duration) { view.alpha = 1 }
    }
}

open class PiePlainTextLayer: PieChartLayer {
    public weak var chart: PieChart?
    public var settings: PiePlainTextLayerSettings = PiePlainTextLayerSettings()
    public var onNotEnoughSpace: ((UILabel, CGSize) -> Void)?
    fileprivate var sliceViews = [PieSlice: UILabel]()
    public var animator: PieViewLayerAnimator = AlphaPieViewLayerAnimator()
    public init() {}
    public func onEndAnimation(slice: PieSlice) { addItems(slice: slice) }
    
    public func addItems(slice: PieSlice) {
        guard sliceViews[slice] == nil else { return }
        let label: UILabel = settings.label.labelGenerator?(slice) ?? {
            let label = UILabel()
            label.backgroundColor = settings.label.bgColor
            label.textColor = settings.label.textColor
            label.font = UIFont.boldSystemFont(ofSize: 11)
            return label
        }()
        let text = slice.data.model.value == 0 ? "" : String(format: "  %.02f%% ", slice.data.percentage * 100)
        let size = (text as NSString).size(withAttributes: [ .font: settings.label.font])
        let center = settings.viewRadius.map{slice.view.midPoint(radius: $0)} ?? slice.view.arcCenter
        let availableSize = CGSize(width: slice.view.maxRectWidth(center: center, height: size.height), height: size.height)
        
        if !settings.hideOnOverflow || availableSize.contains(size) {
            label.text = text
            label.backgroundColor = slice.data.model.color.darker(by: 45)
            label.sizeToFit()
        } else { onNotEnoughSpace?(label, availableSize) }
        
        label.center = center
        chart?.addSubview(label)
        animator.animate(label)
        sliceViews[slice] = label
    }
    
    public func onSelected(slice: PieSlice, selected: Bool) {
        guard let label = sliceViews[slice] else { return }
        let p = slice.view.calculatePosition(angle: slice.view.midAngle, p: label.center, offset: selected ? slice.view.selectedOffset : -slice.view.selectedOffset)
        UIView.animate(withDuration: 0.15) { label.center = p }
    }
    
    public func clear() {
        for (_, view) in sliceViews { view.removeFromSuperview() }
        sliceViews.removeAll()
    }
}
////////10////////20////////30////////40////////50////////60////////70////////80
