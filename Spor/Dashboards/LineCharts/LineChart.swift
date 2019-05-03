//COMMENTING IN PROGRESS
////////10////////20////////30////////40////////50////////60////////70////////80
import UIKit

public protocol ChartDelegate: class {
    func didTouchChart(_ chart: Chart, indexes: [Int?], x: Double, left: Double)
    func didEndTouchingChart(_ chart: Chart)
}

typealias ChartPoint = (x: Double, y: Double)

@IBDesignable open class Chart: UIControl {
    @IBInspectable open var axesColor = UIColor.white
    @IBInspectable open var gridColor = UIColor.gray.withAlphaComponent(0.3)
    @IBInspectable open var identifier: String?
    @IBInspectable open var labelColor = UIColor.white
    @IBInspectable open var lineWidth = CGFloat(2)
    
    open var areaAlphaComponent = CGFloat(0.1)
    open var bottomInset = 20.0
    open var hideHighlightLineOnTouchEnd = false
    open var highlightLineColor = UIColor.gray
    open var highlightLineWidth = CGFloat(0.5)
    open var labelFont = UIFont(name: "Menlo", size: 12)
    open var maxX: Double?
    open var maxY: Double?
    open var minX: Double?
    open var minY: Double?
    open var series: [ChartSeries] = [] { didSet { DispatchQueue.main.async { self.setNeedsDisplay() }}}
    open var showXLabelsAndGrid = true
    open var showYLabelsAndGrid = true
    open var topInset = 20.0
    open var xLabels: [Double]?
    open var xLabelsFormatter = { (labelIndex: Int, labelValue: Double) -> String in String(Int(labelValue)) }
    open var xLabelsSkipLast = true
    open var xLabelsTextAlignment = NSTextAlignment.left
    open var yLabels: [Double]?
    open var yLabelsFormatter = { (labelIndex: Int, labelValue: Double) -> String in String(Int(labelValue)) }
    open var yLabelsOnRightSide = false
    
    weak open var delegate: ChartDelegate?
    
    fileprivate var drawingHeight: Double!
    fileprivate var drawingWidth: Double!
    fileprivate var highlightShapeLayer: CAShapeLayer!
    fileprivate var layerStore: [CAShapeLayer] = []
    fileprivate var min: ChartPoint!
    fileprivate var max: ChartPoint!
    
    typealias ChartLineSegment = [ChartPoint]
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    convenience public init() {
        self.init(frame: .zero)
        commonInit()
    }
    private func commonInit() {
        backgroundColor = UIColor.clear
        contentMode = .redraw
    }
    
    override open func draw(_ rect: CGRect) {
        let minMax = getMinMax()
        min = minMax.min
        max = minMax.max
        drawingHeight = Double(bounds.height) - bottomInset - topInset
        drawingWidth = Double(bounds.width)
        highlightShapeLayer = nil
        
        for view in self.subviews { view.removeFromSuperview() }
        for layer in layerStore { layer.removeFromSuperlayer() }
        layerStore.removeAll()
        
        for (index, series) in self.series.enumerated() {
            let segments = Chart.segmentLine(series.data, zeroLevel: series.colors.zeroLevel)
            segments.forEach({ segment in
                let scaledXValues = scaleValuesOnXAxis( segment.map { $0.x } )
                let scaledYValues = scaleValuesOnYAxis( segment.map { $0.y } )
                if series.line { drawLine(scaledXValues, yValues: scaledYValues, seriesIndex: index) }
                if series.area { drawArea(scaledXValues, yValues: scaledYValues, seriesIndex: index) }
            })
        }
        
        drawAxes()
        if showXLabelsAndGrid && (xLabels != nil || series.count > 0) { drawLabelsAndGridOnXAxis() }
        if showYLabelsAndGrid && (yLabels != nil || series.count > 0) { drawLabelsAndGridOnYAxis() }
    }
    
    open func add(_ series: ChartSeries) { self.series.append(series) }
    open func add(_ series: [ChartSeries]) { for s in series { add(s) } }
    open func removeSeriesAt(_ index: Int) { series.remove(at: index) }
    open func removeAllSeries() { series = [] }
    open func valueForSeries(_ seriesIndex: Int, atIndex dataIndex: Int?) -> Double? {
        return dataIndex ?? -1 >= 0 ? self.series[seriesIndex].data[dataIndex!].y : nil
    }
    
    fileprivate func getMinMax() -> (min: ChartPoint, max: ChartPoint) {
        var min = (x: minX, y: minY)
        var max = (x: maxX, y: maxY)
        for series in self.series {
            let xValues =  series.data.map { $0.x }
            let yValues =  series.data.map { $0.y }
            let newMinX = xValues.min() ?? 0
            let newMinY = yValues.min() ?? 0
            let newMaxX = xValues.max() ?? 0
            let newMaxY = yValues.max() ?? 0
            if min.x == nil || newMinX < min.x! { min.x = newMinX }
            if min.y == nil || newMinY < min.y! { min.y = newMinY }
            if max.x == nil || newMaxX > max.x! { max.x = newMaxX }
            if max.y == nil || newMaxY > max.y! { max.y = newMaxY }
        }
        if let xLabels = self.xLabels {
            let newMinX = xLabels.min() ?? 0
            let newMaxX = xLabels.max() ?? 0
            if min.x == nil || newMinX < min.x! { min.x = newMinX }
            if max.x == nil || newMaxX > max.x! { max.x = newMaxX }
        }
        if let yLabels = self.yLabels {
            let newMinY = yLabels.min() ?? 0
            let newMaxY = yLabels.max() ?? 0
            if min.y == nil || newMinY < min.y! { min.y = newMinY }
            if max.y == nil || newMaxY > max.y! { max.y = newMaxY }
        }
        return (min: (x: min.x ?? 0, y: min.y ?? 0), max: (x: max.x ?? 0, max.y ?? 0))
    }
    
    fileprivate func scaleValuesOnXAxis(_ values: [Double]) -> [Double] {
        let factor = (max.x - min.x == 0) ? 0 : Double(drawingWidth) / (max.x - min.x)
        return values.map { factor * ($0 - self.min.x) }
    }
    fileprivate func scaleValuesOnYAxis(_ values: [Double]) -> [Double] {
        let factor = (max.y - min.y == 0) ? 0 : Double(drawingHeight) / (max.y - min.y)
        return values.map { Double(self.topInset) + Double(drawingHeight) - factor * ($0 - min.y) }
    }
    
    fileprivate func getZeroValueOnYAxis(zeroLevel: Double) -> Double {
        return scaleValuesOnYAxis(min.y > zeroLevel ? [min.y] : [zeroLevel])[0]
    }
    
    fileprivate func drawLine(_ xValues: [Double], yValues: [Double], seriesIndex: Int) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: CGFloat(xValues.first!), y: CGFloat(yValues.first!)))
        for i in 1..<yValues.count { path.addLine(to: CGPoint(x: CGFloat(xValues[i]), y: CGFloat(yValues[i]))) }
        
        let sublayer = CAShapeLayer()
        sublayer.frame = self.bounds
        sublayer.path = path
        sublayer.fillColor = nil
        sublayer.lineWidth = lineWidth
        sublayer.lineJoin = CAShapeLayerLineJoin.round
        sublayer.strokeColor = yValues.max()! <= self.scaleValuesOnYAxis([series[seriesIndex].colors.zeroLevel])[0] ? series[seriesIndex].colors.above.cgColor : series[seriesIndex].colors.below.cgColor
        self.layer.addSublayer(sublayer)
        layerStore.append(sublayer)
    }
    
    fileprivate func drawArea(_ xValues: [Double], yValues: [Double], seriesIndex: Int) {
        let area = CGMutablePath()
        let zero = CGFloat(getZeroValueOnYAxis(zeroLevel: series[seriesIndex].colors.zeroLevel))
        area.move(to: CGPoint(x: CGFloat(xValues[0]), y: zero))
        for i in 0..<xValues.count {
            area.addLine(to: CGPoint(x: CGFloat(xValues[i]), y: CGFloat(yValues[i])))
        }
        area.addLine(to: CGPoint(x: CGFloat(xValues.last!), y: zero))
        
        let sublayer = CAShapeLayer()
        sublayer.frame = self.bounds
        sublayer.path = area
        sublayer.strokeColor = nil
        sublayer.lineWidth = 0
        sublayer.fillColor = (yValues.max()! <= self.scaleValuesOnYAxis([series[seriesIndex].colors.zeroLevel])[0] ? series[seriesIndex].colors.above : series[seriesIndex].colors.below).withAlphaComponent(areaAlphaComponent).cgColor
        self.layer.addSublayer(sublayer)
        layerStore.append(sublayer)
    }
    
    fileprivate func drawAxes() {
        let context = UIGraphicsGetCurrentContext()!
        context.setStrokeColor(axesColor.cgColor)
        context.setLineWidth(0.5)
        
        //horizontal axis; top, bottom, middle
        context.move(to: CGPoint(x: 0, y: drawingHeight + topInset))
        context.addLine(to: CGPoint(x: drawingWidth, y: drawingHeight + topInset))
        context.strokePath()
        context.move(to: CGPoint(x: 0, y: 0))
        context.addLine(to: CGPoint(x: drawingWidth, y: 0))
        context.strokePath()
        if min.y < 0 && max.y > 0 {
            let y = getZeroValueOnYAxis(zeroLevel: 0)
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: drawingWidth, y: y))
            context.strokePath()
        }
        
        // vertical axis; left, right
        context.move(to: CGPoint(x: 0, y: 0))
        context.addLine(to: CGPoint(x: 0, y: drawingHeight + topInset))
        context.strokePath()
        context.move(to: CGPoint(x: CGFloat(drawingWidth), y: CGFloat(0)))
        context.addLine(to: CGPoint(x: drawingWidth, y: drawingHeight + topInset))
        context.strokePath()
    }
    
    fileprivate func drawLabelsAndGridOnXAxis() {
        let labels = xLabels == nil ? series[0].data.map({ (point: ChartPoint) -> Double in return point.x }) : xLabels!
        let padding = 5.0
        
        let context = UIGraphicsGetCurrentContext()!
        context.setStrokeColor(gridColor.cgColor)
        context.setLineWidth(0.5)
        
        scaleValuesOnXAxis(labels).enumerated().forEach { (i, value) in
            if value != 0 && value != drawingWidth {
                context.move(to: CGPoint(x: value, y: 0))
                context.addLine(to: CGPoint(x: value, y: Double(bounds.height)))
                context.strokePath()
            }
            
            if xLabelsSkipLast && value == drawingWidth { return }
            
            let label = UILabel(frame: CGRect(x: value, y: drawingHeight, width: 0, height: 0))
            label.font = labelFont
            label.text = xLabelsFormatter(i, labels[i])
            label.textColor = labelColor
            label.sizeToFit()
            label.frame.origin.y += CGFloat(topInset)
            label.frame.origin.y -= (label.frame.height - CGFloat(bottomInset)) / 2
            label.frame.origin.x += CGFloat(padding)
            label.frame.size.width = CGFloat(drawingWidth / Double(labels.count) - padding * 2)
            label.textAlignment = xLabelsTextAlignment
            self.addSubview(label)
        }
    }
    
    fileprivate func drawLabelsAndGridOnYAxis() {
        var labels: [Double]
        if yLabels == nil {
            labels = [(min.y + max.y) / 2, max.y]
            if yLabelsOnRightSide || min.y != 0 { labels.insert(min.y, at: 0) }
        } else {
            labels = yLabels!
        }
        let padding = 5.0
        let context = UIGraphicsGetCurrentContext()!
        context.setStrokeColor(gridColor.cgColor)
        context.setLineWidth(0.5)
        
        scaleValuesOnYAxis(labels).enumerated().forEach { (i, value) in
            if value != drawingHeight + topInset && value != getZeroValueOnYAxis(zeroLevel: -500) {
                context.move(to: CGPoint(x: 0, y: value))
                context.addLine(to: CGPoint(x: self.bounds.width, y: CGFloat(value)))
                if labels[i] != 0 { context.setLineDash(phase: CGFloat(0), lengths: [CGFloat(5)]) }
                else { context.setLineDash(phase: CGFloat(0), lengths: []) }
                context.strokePath()
            }
            
            let label = UILabel(frame: CGRect(x: padding, y: value, width: 0, height: 0))
            label.font = labelFont
            label.text = yLabelsFormatter(i, labels[i])
            label.textColor = labelColor
            label.sizeToFit()
            if yLabelsOnRightSide {
                label.frame.origin.x = CGFloat(drawingWidth)
                label.frame.origin.x -= label.frame.width + CGFloat(padding)
            }
            label.frame.origin.y -= label.frame.height
            self.addSubview(label)
        }
        UIGraphicsEndImageContext()
    }
    
    fileprivate func drawHighlightLineFromLeftPosition(_ left: Double) {
        if highlightShapeLayer != nil { highlightShapeLayer.removeFromSuperlayer() }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: left, y: 0))
        path.addLine(to: CGPoint(x: left, y: drawingHeight + topInset))
        let shapeLayer = CAShapeLayer()
        shapeLayer.frame = self.bounds
        shapeLayer.path = path
        shapeLayer.strokeColor = highlightLineColor.cgColor
        shapeLayer.fillColor = nil
        shapeLayer.lineWidth = highlightLineWidth
        highlightShapeLayer = shapeLayer
        layer.addSublayer(shapeLayer)
        layerStore.append(shapeLayer)
    }
    
    func handleTouchEvents(_ touches: Set<UITouch>, event: UIEvent!) {
        let left = Double(touches.first!.location(in: self).x)
        let x = (max.x-min.x) / drawingWidth * left + min.x
        
        if left < 0 || left > drawingWidth {
            if let shapeLayer = highlightShapeLayer { shapeLayer.path = nil }
            return
        }
        drawHighlightLineFromLeftPosition(left)
        
        if delegate == nil { return }
        var indexes: [Int?] = []
        for series in self.series {
            let closest = Chart.findClosestInValues(series.data.map({ (point: ChartPoint) -> Double in
                return point.x }), forValue: x)
            if closest.lowestIndex != nil && closest.highestIndex != nil { indexes.append(closest.lowestIndex) }
        }
        delegate!.didTouchChart(self, indexes: indexes, x: x, left: left)
    }
    
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouchEvents(touches, event: event)
    }
    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouchEvents(touches, event: event)
    }
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouchEvents(touches, event: event)
        if self.hideHighlightLineOnTouchEnd {
            if let shapeLayer = highlightShapeLayer { shapeLayer.path = nil }
        }
        delegate?.didEndTouchingChart(self)
    }
    
    fileprivate class func findClosestInValues(
        _ values: [Double],
        forValue value: Double
        ) -> (
        lowestValue: Double?,
        highestValue: Double?,
        lowestIndex: Int?,
        highestIndex: Int?
        ) {
            var lowestValue: Double?, highestValue: Double?, lowestIndex: Int?, highestIndex: Int?
            values.enumerated().forEach { (i, currentValue) in
                if currentValue <= value && (lowestValue == nil || lowestValue! < currentValue) {
                    lowestValue = currentValue
                    lowestIndex = i
                }
                if currentValue >= value && (highestValue == nil || highestValue! > currentValue) {
                    highestValue = currentValue
                    highestIndex = i
                }
            }
            return (
                lowestValue: lowestValue,
                highestValue: highestValue,
                lowestIndex: lowestIndex,
                highestIndex: highestIndex
            )
    }
    
    fileprivate class func segmentLine(_ line: ChartLineSegment, zeroLevel: Double) -> [ChartLineSegment] {
        var segments: [ChartLineSegment] = []
        var segment: ChartLineSegment = []
        
        line.enumerated().forEach { (i, point) in
            segment.append(point)
            if i < line.count - 1 {
                let nextPoint = line[i+1]
                if point.y >= zeroLevel && nextPoint.y < zeroLevel || point.y < zeroLevel && nextPoint.y >= zeroLevel {
                    let closingPoint = Chart.intersectionWithLevel(point, and: nextPoint, level: zeroLevel)
                    segment.append(closingPoint)
                    segments.append(segment)
                    segment = [closingPoint]
                }
            } else {
                segments.append(segment)
            }
        }
        return segments
    }
    
    fileprivate class func intersectionWithLevel(_ p1: ChartPoint, and p2: ChartPoint, level: Double) -> ChartPoint {
        let dy1 = level - p1.y
        let dy2 = level - p2.y
        return (x: (p2.x * dy1 - p1.x * dy2) / (dy1 - dy2), y: level)
    }
}

open class ChartSeries {
    open var data: [(x: Double, y: Double)]
    open var line = true
    open var area = false
    open var color = teal { didSet { colors = (above: color, below: color, 0) } }
    open var colors = (above: red, below: teal, zeroLevel: 0.00001)
    
    public init(_ data: [Double]) {
        self.data = []
        data.enumerated().forEach { (x, y) in
            let point: (x: Double, y: Double) = (x: Double(x), y: y)
            self.data.append(point)
        }
    }
    public init(data: [(x: Double, y: Double)]) { self.data = data }
    public init(data: [(x: Int,    y: Double)]) { self.data = data.map { (Double($0.x), Double($0.y)) } }
    public init(data: [(x: Float,  y: Float )]) { self.data = data.map { (Double($0.x), Double($0.y)) } }
}
////////10////////20////////30////////40////////50////////60////////70////////80
