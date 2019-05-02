////////10////////20////////30////////40////////50////////60////////70////////80
import UIKit
import CoreData
import Firebase

class VCLineCharts: UIViewController, ChartDelegate {
    @IBOutlet weak var budgetLabel: UILabel!
    @IBOutlet weak var budgetField: DesignableTextField!
    @IBOutlet weak var lineChart: Chart!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var chartPeriodWButton: DesignableButton!
    @IBOutlet weak var chartPeriod2WButton: DesignableButton!
    @IBOutlet weak var chartPeriodMButton: DesignableButton!
    @IBOutlet weak var chartPeriodQButton: DesignableButton!
    @IBOutlet weak var chartPeriodYButton: DesignableButton!
    @IBOutlet weak var chartPeriodAllButton: DesignableButton!
    
    var lineChartValueLabel =
        UILabel(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
    var budgDiv = 1.0
    var budgPerDay = 1.0
    var swipeL = UISwipeGestureRecognizer(target: self, action: nil)
    var swipeR = UISwipeGestureRecognizer(target: self, action: nil)
    var swipeU = UISwipeGestureRecognizer(target: self, action: nil)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //allows user to return to this screen after exiting "Settings"
        UserDefaults.standard.set(title, forKey: "LastScreen")
        //allows user to return to this screen after exiting "NewTransaction" or "EditTransactions"
        UserDefaults.standard.set(title, forKey: "LastDashboard")
        
        //"swipeL", "swipeR", and "swipeU" are defined outside of "viewDidLoad(...)" because they are used in multiple functions
        swipeL = UISwipeGestureRecognizer(
            target: self, action: #selector(respondToSwipeGesture(_:)))
        swipeR = UISwipeGestureRecognizer(
            target: self, action: #selector(respondToSwipeGesture(_:)))
        swipeU = UISwipeGestureRecognizer(
            target: self, action: #selector(respondToSwipeGesture(_:)))
        swipeL.direction = .left
        swipeR.direction = .right
        swipeU.direction = .up
        view.addGestureRecognizer(swipeL)
        view.addGestureRecognizer(swipeR)
        view.addGestureRecognizer(swipeU)
        
        //"budgDiv" and "budgPerDay" are defined outside of "viewDidLoad(...)" because they are used in multiple functions
        let prd = UserDefaults.standard.string(forKey: "Period") ?? "Monthly"
        switch prd {
            case "Weekly":   budgDiv = 7.0
            case "Biweekly": budgDiv = 14.0
            case "Monthly":  budgDiv = 30.436875
            case "Yearly":   budgDiv = 365.24219
            default: break
        }
        budgPerDay = UserDefaults.standard.double(forKey: "Budget") /  budgDiv
        budgetLabel.text = prd.uppercased() + " BUDGET"

        let btn = UIBarButtonItem(title: "Close", style: .plain, target: self,
                                  action: #selector(closeButtonAction))
        let toolbar = makeToolbar()
        toolbar.setItems([btn], animated: true)
        budgetField.inputAccessoryView = toolbar

        budgetField.attributedPlaceholder = NSAttributedString(string:
            (UserDefaults.standard.string(forKey: "Currency") ?? "$") + "0.00",
            attributes: [NSAttributedString.Key.foregroundColor: greyDark]
        )
        budgetField.font = UIFont(name: "Menlo", size: 20)
        budgetField.layer.borderWidth = 2.0
        budgetField.text = String(format:"%.02f",
            UserDefaults.standard.double(forKey: "Budget")).currencyFormat()
        budgetField.tintColor = .white
        
        lineChart.delegate = self
    }
    @objc func closeButtonAction() { view.endEditing(true) }
    @objc func respondToSwipeGesture(_ gesture: UIGestureRecognizer)  {
        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            switch swipeGesture.direction {
                case .right:
                    performSegue(withIdentifier: title == "LineChartPercent" ?
                        "LineChartAmountR" : "PieChartsR", sender: nil)
                case .left:
                    performSegue(withIdentifier: title == "LineChartPercent" ?
                        "SummaryL" : "LineChartPercentL", sender: nil)
                case .up:
                    performSegue(withIdentifier: "NewTransactionU", sender: nil)
                default: break
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
        super.touchesBegan(touches, with: event)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(301),
                                      execute: {
            switch UserDefaults.standard.string(forKey: "ChartPeriod") {
                case "W":  self.highlightChartPeriod(self.chartPeriodWButton)
                case "2W": self.highlightChartPeriod(self.chartPeriod2WButton)
                case "M":  self.highlightChartPeriod(self.chartPeriodMButton)
                case "Q":  self.highlightChartPeriod(self.chartPeriodQButton)
                case "Y":  self.highlightChartPeriod(self.chartPeriodYButton)
                case "∞":  self.highlightChartPeriod(self.chartPeriodAllButton)
                default:   self.highlightChartPeriod(self.chartPeriodMButton)
            }
        })
    }
    
    @IBAction func tapChartPeriod(_ sender: DesignableButton) {
        highlightChartPeriod(sender)
    }
    
    //"highlightChartPeriod(...)" highlights the appropriate chart period button in the UI and then calls "refreshChart(...)", which is what actually displays the data in "lineChart"
    func highlightChartPeriod(_ button: DesignableButton) {
        let buttons = [
            chartPeriodWButton,
            chartPeriod2WButton,
            chartPeriodMButton,
            chartPeriodQButton,
            chartPeriodYButton,
            chartPeriodAllButton
        ]
        for button in buttons {
            button?.borderColor = greyLighter
            button?.setTitleColor(greyLighter, for: .normal)
        }
        button.borderColor = teal
        button.setTitleColor(.white, for: .normal)
        UserDefaults.standard.set(button.currentTitle, forKey: "ChartPeriod")
        
        //"refreshChart(...)" needs to be a seperate function because it is called any time the user changes "Budget" via "budgetField"
        refreshChart()
    }

    //if the user edits "budgetField", set "Budget" to the input value, update Firebase with new category budget values, and refresh "lineChart" to reflect the new value
    @IBAction func editBudgetField(_ sender: DesignableTextField) {
        let fmt = sender.text?.currencyFormat() ?? "$0.00"
        sender.text = fmt
        let reFmt = String(fmt.suffix(fmt.count - 1))
        let value = Double(reFmt.replacingOccurrences(
            of: ",", with: "", options: .literal, range: nil)) ?? 0
        UserDefaults.standard.set(value, forKey: "Budget")
        for ctg in ctgs { ctg.budget = ctg.proportion * value }
        fetchCtgs()
        refreshChart()
    }
    
    func refreshChart() {
        //show the activity indicator while the chart loads to prevent confusion for the user
        //this probably isn't necessary anymore because the caluclations in "refreshChart(...)" are much quicker now than they were during user testing
        activityIndicator.startAnimating()
        
        //remove all existing labels and series from "lineChart"
        lineChartValueLabel.removeFromSuperview()
        lineChart.removeAllSeries()

        //calculate "scope", "day1", and the number of days between "StartDate" and "day1" ("pre1"), which will all be used to calculate the data points in "lineChart"
        //if the selected scope exceeds the time since "StartDate", set "scope" to "daysSinceStart", rounded up
        let now = Date()
        let start = UserDefaults.standard.string(forKey: "StartDate") ??
            now.toString()
        let daysSinceStart = now.timeIntervalSince(start.toDate()) / 86400
        var scope = 31
        switch UserDefaults.standard.string(forKey: "ChartPeriod") {
            case "W":  scope = 7
            case "2W": scope = 14
            case "M":  scope = 31
            case "Q":  scope = 91
            case "Y":  scope = 365
            case "∞":  scope = Int(ceil(daysSinceStart))
            default:   break
        }

        let day1 = max(start.toDate(), Calendar.current.date(byAdding: .day,
            value: -scope + 1, to: now.toString().toDate()) ?? now)
        let pre1 = Int(ceil(day1.timeIntervalSince(start.toDate()) / 86400.0))
        if pre1 == 0 { scope = Int(ceil(daysSinceStart)) }
        
        //create array of ChartSeries (lines) to be added to "lineChart"
        var series = [ChartSeries]()
        
        //create zero line data set
        var zeroLine = [(x: Int, y: Double)]()
        for i in 1...(scope + 1) { zeroLine.append((x: i, y: 0)) }
        
        //create over/under budget data set
        var overUnderLine = [(x: Int, y: Double)]()
        
        //each data point in "overUnderLine" is based on the user's cumulative spend for each day in scope; therefore, the first thing that needs to be done is to determine the cumulative spend up until "day1" so that the first data point accurately reflects the amount over/under budget at that time
        var yValue = 0.0
        var t = 0
        for txn in txns {
            if txn.date <= day1 {
                yValue -= txn.amount
                t += 1
            }
            else { break }
        }

        //for each day in scope, add "i" and a cumulative calculation of "yValue" to "overUnderLine"
        var i = 1
        while i <= scope {
            //if "t" is valid and the date of the transaction associated with "t" ("txn") matches the date associated with "i" ("match"), add the amount of that transaction to the cumulative "yValue" and increment "t"
            let txn = txns.count > t ? txns[t].date.toString() : nil
            let match = (Calendar.current.date(byAdding: .day, value: -scope
                + i, to: now.toString().toDate()) ?? now).toString()
            if txn == match {
                yValue -= txns[t].amount
                t += 1
            }
            //otherwise, supply "overUnderLine" with i for "x:" and a y value calculated based on "yValue" appropriate for the specific chart (percent vs. amount over budget)
            //then, increment i
            else {
                var newY = yValue - budgPerDay * Double(pre1 + i)
                if title == "LineChartPercent" {
                    //format yValue as percentage
                    newY = yValue / (budgPerDay * Double(pre1 + i)) * 100 - 100
                    //prevent early outliers (first 31 days) from skewing the range of the y-axis for long-term views (greater than 91 days); this is bound to happen early on when individual transactions have a much greater effect on percentage over/under budget
                    if (newY.isNaN ||
                        newY.isInfinite ||
                        (scope > 91 && i <= 31 && abs(newY) > 50))
                    {
                        newY = 0
                    }
                }
                overUnderLine.append((x: i, y: newY))
                i += 1
                
                //add an extra data point to show a flat line for today
                if i > scope { overUnderLine.append((x: i, y: newY)) }
            }
        }

        series.append(ChartSeries(data: zeroLine))
        series.append(ChartSeries(data: overUnderLine))
        series.first?.color = .white
        lineChart.add(series)
        
        //show a maximum of 7 labels on the x-axis and format these labels
        var xLabels = [Double]()
        if scope < 8 {
            for i in 1...scope {
                xLabels.append(Double(i))
            }
        } else {
            for i in 0...5 {
                xLabels.append(1 + Double(i) / 6.0 * Double(scope - 1))
            }
        }
        lineChart.xLabels = xLabels
        lineChart.xLabelsFormatter = {
            (labelIndex: Int, labelValue: Double) -> String in
                let formatter = DateFormatter()
                formatter.dateFormat = scope < 11 ? "EEEEE" : "M/d"
                return formatter.string(from: Calendar.current.date(
                    byAdding: .day,
                    value: -scope + Int(labelValue),
                    to: now.toString().toDate()) ?? now)
        }

        //the y-axis labels are determined by the maximum and minimum y-values in "overUnderLine"
        //"max(...)" and "min(...)" are used to ensure that min is never above zero and max is never below zero, which is necessary for the calculations to carry out properly
        let yMin = min(0, overUnderLine.min(by: { $0.y < $1.y })?.y ?? 0)
        let yMax = max(0, overUnderLine.max(by: { $0.y < $1.y })?.y ?? 0)
        
        //"dividerDecider" is the y-value in "overUnderLine" furthest away from 0; this value is used to determine what value should be set for "divider"
        let dividerDecider = max(abs(yMin), abs(yMax))
        
        //if "dividerDecider" is 500.0 or less, then up to 11 unique ticks will be created with "divider" used as the distance between these ticks
        //"max(...)" and "min(...)" are used to ensure that there is not unecessary empty space on the chart either above or below the axis
        //for example, if "yMin" is -300 but "yMax" is only 1, the range used for the y-axis will be -400 through 100
        if dividerDecider <= 500.0 {
            //"divider" is used to determine the interval between ticks on the y-axis and is based on how wide the range is of y-values in "overUnderLine"
            var divider = 10.0
            if      dividerDecider > 200 { divider = 100.0 }
            else if dividerDecider > 100 { divider = 50.0  }
            else if dividerDecider > 50  { divider = 20.0  }
            
            //the upper and lower bounds of the y-axis are the nearest values above and below "yMax" and "yMin" divisable by "divider", respectively
            let yAxisMin = ((yMin / divider).rounded(.towardZero) - 1) * divider
            let yAxisMax = ((yMax / divider).rounded(.towardZero) + 1) * divider
            
            lineChart.yLabels = [
                max(-divider * 5, yAxisMin),
                max(-divider * 4, yAxisMin),
                max(-divider * 3, yAxisMin),
                max(-divider * 2, yAxisMin),
                max(-divider, yAxisMin),
                0.0,
                min(divider, yAxisMax),
                min(divider * 2, yAxisMax),
                min(divider * 3, yAxisMax),
                min(divider * 4, yAxisMax),
                min(divider * 5, yAxisMax)
            ]
        }
        //if "dividerDecider" is 500 or more, then up to 9 unique ticks will be created that are all equidistant from one another
        else {
            //the distance between the ticks is 1/4 of "dividerDecider" rounded up to the nearest 200th
            let divider = ((dividerDecider / 200).rounded(.towardZero) + 1) * 50
            let yAxisMin = ((yMin / divider).rounded(.towardZero) - 1) * divider
            let yAxisMax = ((yMax / divider).rounded(.towardZero) + 1) * divider

            lineChart.yLabels = [
                max(-divider * 4, yAxisMin),
                max(-divider * 3, yAxisMin),
                max(-divider * 2, yAxisMin),
                max(-divider, yAxisMin),
                0.0,
                min(divider, yAxisMax),
                min(divider * 2, yAxisMax),
                min(divider * 3, yAxisMax),
                min(divider * 4, yAxisMax)
            ]
        }
        if title == "LineChartPercent" {
            lineChart.yLabelsFormatter = {
                (labelIndex: Int, labelValue: Double) -> String in
                    String(Int(labelValue)) + "%"
            }
        } else {
            let ccy = UserDefaults.standard.string(forKey: "Currency") ?? "$"
            lineChart.yLabelsFormatter = {
                (labelIndex: Int, labelValue: Double) -> String in
                    (labelValue < 0 ? "(" : "")
                        + ccy + String(Int(abs(labelValue)))
                        + (labelValue < 0 ? ")" : "")
            }
        }
        
        //remove the activity indicator to indicate that "lineChart" has finished refreshing
        activityIndicator.stopAnimating()
    }

    //if a user touches "lineChart", remove any existing "lineChartValueLabel" and create a new one
    func didTouchChart(_ chart: Chart, indexes: [Int?], x: Double, left: Double)
    {
        //swipes are disabled while the user is touching "lineChart" to prevent accidental screen transitions
        view.removeGestureRecognizer(swipeL)
        view.removeGestureRecognizer(swipeR)
        view.removeGestureRecognizer(swipeU)
        view.endEditing(true)
        
        lineChartValueLabel.removeFromSuperview()
        
        //the value of series 1 ("overUnderLine") at the point nearest to where the user touched ("x") is what is displayed next to the line
        let value = chart.valueForSeries(1, atIndex: Int(x)-1) ?? 0
        
        //whether or not the value is positive and whether "lineChart" is an amount or percentage chart determines the format of the information presented
        let underBudget = value < 0
        let percentChart = (title ?? "").suffix(7) == "Percent"
        
        //"width" is used to determine whether the value of "lineChartValueLabel" should display on the right or left side of the line
        let width = Double(view.frame.width)
        let screenHeight = Double(UIScreen.main.bounds.height)
        lineChartValueLabel = UILabel(frame: CGRect(
            //if the touch point is in the rightmost 25% of the screen, display the label on the left, otherwise display on the right
            x: left - width / 2 + ((left < width * 0.75) ? 50.0 : -30.0),
            //the height of the chart is about half the height of the screen for all displays, so this y-position ensures the label always displays close to the top of the chart area
            y: Double(chart.frame.minY) - screenHeight / 2.0 + 20.0,
            width: width,
            height: screenHeight
        ))
        let lbl = percentChart ?
            String(format: "%.02f%%", value) :
            String(format: "%.02f", value).currencyFormat()
        lineChartValueLabel.text =
            underBudget && !percentChart ? "(" + lbl + ")" : lbl
        lineChartValueLabel.textAlignment = .center
        lineChartValueLabel.textColor = underBudget ? teal : red
        chart.highlightLineColor = underBudget ? teal : red
        view.addSubview(lineChartValueLabel)
    }
    func didEndTouchingChart(_ chart: Chart) {
        view.addGestureRecognizer(swipeL)
        view.addGestureRecognizer(swipeR)
        view.addGestureRecognizer(swipeU)
    }
}
////////10////////20////////30////////40////////50////////60////////70////////80
