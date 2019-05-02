//COMMENTING IN PROGRESS
////////10////////20////////30////////40////////50////////60////////70////////80
import UIKit

@IBDesignable open class PieChart: UIView {
    @IBInspectable public var innerRadius = CGFloat(20)
    @IBInspectable public var outerRadius = CGFloat(90)
    @IBInspectable public var strokeColor = UIColor.black
    @IBInspectable public var strokeWidth = CGFloat(0)
    @IBInspectable public var selectedOffset = UIScreen.main.bounds.height * 0.03
    @IBInspectable public var animDuration = 0.5
    @IBInspectable public var referenceAngle = CGFloat(240) {
        didSet {
            for layer in layers { layer.clear() }
            let delta = (referenceAngle - oldValue).degreesToRadians
            for slice in slices {
                slice.view.angles = (slice.view.startAngle + delta, slice.view.endAngle + delta)
            }
            for slice in slices { slice.view.present(animated: false) }
        }
    }
    
    var animated: Bool { return animDuration > 0 }
    var selectedSlice: PieSlice?
    
    public fileprivate(set) var container = CALayer()
    public fileprivate(set) var slices: [PieSlice] = []
    
    public var models: [PieSliceModel] = [] {
        didSet {
            if oldValue.isEmpty {
                slices = generateSlices(models)
                showSlices()
            }
        }
    }
    
    public weak var delegate: PieChartDelegate?
    
    public var layers: [PieChartLayer] = [] {
        didSet { for layer in layers { layer.chart = self } }
    }
    
    public var totalValue: Double { return models.reduce(0){$0 + $1.value} }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(container)
        container.frame = bounds
    }
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        layer.addSublayer(container)
        container.frame = bounds
    }
    
    fileprivate func generateSlices(_ models: [PieSliceModel]) -> [PieSlice] {
        var slices: [PieSlice] = []
        var lastEndAngle = CGFloat(0)
        for (index, model) in models.enumerated() {
            let (newEndAngle, slice) = generateSlice(model: model, index: index, lastEndAngle: lastEndAngle, totalValue: totalValue)
            slices.append(slice)
            lastEndAngle = newEndAngle
        }
        return slices
    }
    
    fileprivate func generateSlice(model: PieSliceModel, index: Int, lastEndAngle: CGFloat, totalValue: Double) -> (CGFloat, PieSlice) {
        let percentage = 1 / (totalValue / model.value)
        let newEndAngle = lastEndAngle + CGFloat((.pi * 2) * percentage)
        let data = PieSliceData(model: model, id: index, percentage: percentage)
        let slice = PieSlice(data: data, view: PieSliceLayer(color: model.color, startAngle: lastEndAngle, endAngle: newEndAngle, animDelay: 0, center: bounds.center))
        
        slice.view.frame = bounds
        slice.view.sliceData = data
        slice.view.innerRadius = innerRadius
        slice.view.outerRadius = outerRadius
        slice.view.selectedOffset = percentage > 0.5 ? CGFloat(0) : selectedOffset
        slice.view.animDuration = animDuration
        slice.view.strokeColor = strokeColor
        slice.view.strokeWidth = strokeWidth
        slice.view.referenceAngle = referenceAngle.degreesToRadians
        slice.view.sliceDelegate = self
        
        return (newEndAngle, slice)
    }
    
    fileprivate func showSlices() {
        for slice in slices {
            container.addSublayer(slice.view)
            slice.view.rotate(angle: slice.view.referenceAngle)
            slice.view.present(animated: animated)
        }
    }
    
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        var index = 0
        if let touch = touches.first {
            let point = touch.location(in: self)
            if let slice = (slices.filter{$0.view.contains(point)}).first {
                for i in 0..<slices.count { if slices[i] == slice { index = i } }
                for pie in pies {
                    pie.slices[index].view.selected = !pie.slices[index].view.selected
                    var selectedList : [Bool] = []
                    for slice in pie.slices {
                        selectedList.append(slice.view.selected)
                        if slice.view.selected {slice.view.selected = false}
                    }
                    var sliceStartAngle = pie.referenceAngle + pie.slices[index].view.startAngle.radiansToDegrees
                    if sliceStartAngle >= 360   { sliceStartAngle -= 360 }
                    if sliceStartAngle < 0      { sliceStartAngle += 360 }
                    var newReferenceAngle = 2 * pie.referenceAngle - sliceStartAngle
                    if newReferenceAngle >= 360 { newReferenceAngle -= 360 }
                    if newReferenceAngle < 0    { newReferenceAngle += 360 }
                    pie.referenceAngle = newReferenceAngle
                    for i in 0..<pie.slices.count {
                        if pie.slices[i].view.selected != selectedList[i] {
                            pie.slices[i].view.selected = selectedList[i]
                        }
                    }
                }
            }
        }
    }
    
    public func insertSlice(index: Int, model: PieSliceModel) {
        guard index < slices.count else { return }
        for layer in layers { layer.clear() }
        
        func wrap(_ angle: CGFloat) -> CGFloat { return angle.truncatingRemainder(dividingBy: CGFloat.pi * 2) }
        
        let newSlicePercentage = 1 / ((totalValue + model.value) / model.value)
        let currentSliceAtIndexEndAngle = index == 0 ? 0 : wrap(slices[index - 1].view.endAngle)
        let currentSliceAfterIndeStartAngle = index == 0 ? 0 : wrap(slices[index].view.startAngle)
        
        var offset = CGFloat.pi * 2 * CGFloat(newSlicePercentage)
        var lastEndAngle = currentSliceAfterIndeStartAngle + offset
        
        let (_, slice) = generateSlice(model: model, index: index, lastEndAngle: currentSliceAtIndexEndAngle, totalValue: model.value + totalValue)
        
        container.addSublayer(slice.view)
        slice.view.rotate(angle: slice.view.referenceAngle)
        slice.view.presentEndAngle(angle: slice.view.startAngle, animated: false)
        slice.view.present(animated: animated)
        
        let slicesToAdjust = Array(slices[index..<slices.count]) + Array(slices[0..<index])
        
        models.insert(model, at: index)
        slices.insert(slice, at: index)
        
        for (index, slice) in slices.enumerated() { slice.data.id = index }
        
        for slice in slicesToAdjust {
            let currentAngle = slice.view.endAngle - slice.view.startAngle
            offset = offset + currentAngle * CGFloat(1 - newSlicePercentage) - currentAngle
            var end = slice.view.endAngle + offset
            end = end.truncate(10000000) < slice.view.endAngle.truncate(10000000) ? CGFloat.pi * 2 + end : end
            slice.view.angles = (lastEndAngle < slice.view.startAngle ? CGFloat.pi * 2 : 0 + lastEndAngle, end)
            lastEndAngle = wrap(end)
            slice.data.percentage = 1 / (totalValue / slice.data.model.value)
        }
    }
    
    public func removeSlices() {
        for slice in slices { slice.view.removeFromSuperlayer() }
        slices = []
    }
    
    public func clear() {
        for layer in layers { layer.clear() }
        layers = []
        models = []
        removeSlices()
    }
    
    open override func prepareForInterfaceBuilder() {
        animDuration = 0
        strokeWidth = 1
        strokeColor = UIColor.lightGray
        models = (0..<6).map {_ in PieSliceModel(value: 2, description: "", color: UIColor.clear) }
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        container.frame = bounds
    }
}

extension PieChart: PieSliceDelegate {
    public func onStartAnimation(slice: PieSlice) {
        for layer in layers { layer.onStartAnimation(slice: slice) }
        delegate?.onStartAnimation(slice: slice)
    }
    public func onEndAnimation(slice: PieSlice) {
        for layer in layers { layer.onEndAnimation(slice: slice) }
        delegate?.onEndAnimation(slice: slice)
    }
    public func onSelected(slice: PieSlice, selected: Bool) {
        let isPreviousSliceOpen = selectedSlice?.view.selected ?? false
        if (selected && isPreviousSliceOpen) { selectedSlice?.view.selected = false }
        selectedSlice = selected ? slice : nil
        for layer in layers { layer.onSelected(slice: slice, selected: selected) }
        delegate?.onSelected(slice: slice, selected: selected)
    }
}

public protocol PieChartDelegate: class {
    func onStartAnimation(slice: PieSlice)
    func onEndAnimation(slice: PieSlice)
    func onSelected(slice: PieSlice, selected: Bool)
}

public protocol PieChartLayer: PieChartDelegate {
    var chart: PieChart? {get set}
    func onEndAnimation(slice: PieSlice)
    func addItems(slice: PieSlice)
    func clear()
}

extension PieChartDelegate {
    public func onStartAnimation(slice: PieSlice) {}
    public func onEndAnimation(slice: PieSlice) {}
    public func onSelected(slice: PieSlice, selected: Bool) {}
}

public class PieChartLabelSettings {
    // Optional custom label - when this is set presentations settings (textColor, etc.) are ignored
    public var labelGenerator: ((PieSlice) -> UILabel)?
    public var textColor: UIColor = UIColor.white
    public var bgColor: UIColor = UIColor.clear
    public var font: UIFont = UIFont.boldSystemFont(ofSize: 15)
}
////////10////////20////////30////////40////////50////////60////////70////////80
