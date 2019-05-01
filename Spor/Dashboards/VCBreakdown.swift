////////////////////////////////////////////////////////////////////////////////
import UIKit

//"VCBreakdown" displays four columns that contain the following pieces of information:
//1. category #
//2. category title
//3. current amount over/under budget for that category
//4. current percent over/under budget for that category
class VCBreakdown: UIViewController {
    @IBOutlet weak var HeaderA: DesignableButton!
    @IBOutlet weak var HeaderB: DesignableButton!
    @IBOutlet weak var HeaderC: DesignableButton!
    @IBOutlet weak var HeaderD: DesignableButton!
    var columnA = [(Int, Double, UILabel)]()
    var columnB = [(Int, Double, UILabel)]()
    var columnC = [(Int, Double, UILabel)]()
    var columnD = [(Int, Double, UILabel)]()
    var breakdownLabels = [UILabel]()
    var asc = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UserDefaults.standard.set(title, forKey: "LastScreen")
        UserDefaults.standard.set(title, forKey: "LastDashboard")
        
        fetchTransactions(sortBy: "Date", ascending: true)

        //"HeaderC" and "HeaderD" are configured pre-"viewDidAppear(...)" so that their updates are less obvious
        let currency = UserDefaults.standard.string(forKey: "Currency") ?? "$"
        HeaderC.setTitle(currency + " Over\nBudget", for: .normal)
        HeaderC.titleLabel?.numberOfLines = 2
        HeaderD.titleLabel?.numberOfLines = 2
        
        let swipeL = UISwipeGestureRecognizer(
            target: self, action: #selector(respondToSwipeGesture(_:)))
        let swipeR = UISwipeGestureRecognizer(
            target: self, action: #selector(respondToSwipeGesture(_:)))
        let swipeU = UISwipeGestureRecognizer(
            target: self, action: #selector(respondToSwipeGesture(_:)))
        swipeL.direction = .left
        swipeR.direction = .right
        swipeU.direction = .up
        view.addGestureRecognizer(swipeL)
        view.addGestureRecognizer(swipeR)
        view.addGestureRecognizer(swipeU)
    }
    @objc func respondToSwipeGesture(_ gesture: UIGestureRecognizer)  {
        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            switch swipeGesture.direction {
            case .right:
                performSegue(withIdentifier: "SummaryR", sender: nil)
            case .left:
                performSegue(withIdentifier: "PieChartsL", sender: nil)
            case .up:
                performSegue(withIdentifier: "NewTransactionU", sender: nil)
            default: break
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(301),
                                      execute: { self.finishAppear() })
    }
    
    func finishAppear() {
        //determine budget per day ("budgetPerDay") based on the the number of days in the user's selected budgeting period
        var budgDiv = 1.0
        switch UserDefaults.standard.string(forKey: "Period") {
            case "Weekly":   budgDiv = 7.0
            case "Biweekly": budgDiv = 14.0
            case "Monthly":  budgDiv = 30.436875
            case "Yearly":   budgDiv = 365.24219
            default: break
        }
        
        let now = Date()
        let start = UserDefaults.standard.string(forKey: "StartDate")
        let daysSinceStart =
            now.timeIntervalSince((start ?? now.toString()).toDate()) / 86400
        
        //"labelHeight" is the height of each individual label in "columnA" - "columnD" based on the total amount of vertical space allocated to "columnA" - "columnD"
        //the "0.58" is hard-coded based on constraints that were set in the Storyboard, which should probably be optimized in the future
        //if there are too few categories, "labelHeight" becomes too large and 1/20th of the screen height is used instead
        let lblHT = min(view.frame.height * 0.58 / CGFloat(categories.count),
                        view.frame.height * 0.05)

        //for each category, "columnA" - "columnD" is populated with an index, a value used for sorting, and a UILabel that can be added to "view.subviews" dynamically
        for i in 0..<categories.count {
            let cumulBudg = daysSinceStart * categories[i].budget / budgDiv
            var cumulSpend = 0.0
            for tra in transactions {
                if tra.date <= now && tra.category == categories[i].title {
                    cumulSpend -= tra.amount
                } else { break }
            }
            
            for header in [HeaderA, HeaderB, HeaderC, HeaderD] {
                let label = UILabel(frame: CGRect(
                    x: 0, y: 0,
                    width: header?.frame.width ?? (view.frame.width / 4),
                    height: lblHT
                ))
                
                //the x position of each label will always equal their respective "header" x position; y position needs to be set dynamically in "sortBreakdown(...)"
                label.center.x = header?.center.x ?? 0
                
                label.adjustsFontSizeToFitWidth = true
                label.backgroundColor = colors[i].darker(by: 50)
                label.layer.cornerRadius = 5
                label.layer.masksToBounds = true
                label.textAlignment = .center
                label.textColor = .white
                
                //depending on which header is being looped through, add the label and an appropriate value to its corresponding column
                //"label.text" is what is actually displayed
                switch header {
                //category #
                case HeaderA:
                    label.text = "#" + String(i + 1)
                    columnA.append((i, Double(i), label))
                //category title
                case HeaderB:
                    label.text = categories[i].title
                    columnB.append((i, Double(i), label))
                //current amount over/under budget for that category
                case HeaderC:
                    let value = cumulSpend - cumulBudg
                    let tx = String(format:"%.02f", value).currencyFormat()
                    label.text = cumulSpend > cumulBudg ? tx : ("(" + tx + ")")
                    columnC.append((i, value, label))
                //current percent over/under budget for that category
                case HeaderD:
                    let value = cumulSpend / cumulBudg * 100 - 100
                    label.text = cumulBudg == 0 ?
                        "n/a" : String(format:"%.02f%%", value)
                    //using "-100.1" as an alternative value in the event of "isNaN" allows for predicatable sorting because -100.0 is the otherwise lowest possible value
                    columnD.append((i, cumulBudg == 0 ? -100.1 : value, label))
                default: break
                }
            }
        }

        //"sortBreakdown" is what actually displays the labels created; it needs to be a seperate function because it is called any time the user re-sorts the columns
        sortBreakdown(columnA)
    }
    
    @IBAction func tapHeader(_ sender: DesignableButton) {
        switch sender {
            case HeaderC: sortBreakdown(columnC)
            case HeaderD: sortBreakdown(columnD)
            default:      sortBreakdown(columnA)
        }
    }
    
    func sortBreakdown(_ sortByColumn: [(Int, Double, UILabel)]) {
        //determine whether the sort order should be ascending or descending
        //"4" is hard-coded because we only care about the first four labels, i.e. the top row
        //"breakdownLabels.count" is considered by "min" to prevent the first call of this function in "animateBreakdown(...)" from causing an index-out-of-range exception
        for i in 0..<min(4, breakdownLabels.count) {
            if let topRow =
                sortByColumn.first(where: { $0.2 == breakdownLabels[i] } )
            {
                //if the value of "topRow" equals the minimum value of all rows in the chosen "sortByColumn", then sort direction ("asc") should be descending ("false")
                if topRow.1 == sortByColumn.min(by: { $0.1 < $1.1 } )?.1 {
                    asc = false
                }
                //if the value of "topRow" equals the maximum value of all rows in the chosen "sortByColumn", then sort direction ("asc") should be ascending ("true")
                else if topRow.1 == sortByColumn.max(by: { $0.1 < $1.1 } )?.1 {
                    asc = true
                }
                //otherwise, just flip sort direction
                else { asc = !asc  }
                break
            }
        }

        //remove any existing "breakdownLabels" from the Superview before displaying new ones
        for label in breakdownLabels { label.removeFromSuperview() }
        
        //wipe "breakdownLabels"; "breakdownLabels" needs to be declared outside of "sortBreakdown(...)" so that its value can be used at the beginning of "sortBreakdown(...)"
        breakdownLabels = []
        
        //set a y position for each row and then add the row to "breakdownLabels" before adding every label in "breakdownLabels" to "view.subviews"
        var rowIndex = 1
        let cols = [columnA, columnB, columnC, columnD]
        for sortedRow in
            sortByColumn.sorted(by: { asc ? $0.1 < $1.1 : $0.1 > $1.1})
        {
            for i in 0..<4 {
                if let rowX = cols[i].first(where:{$0.0 == sortedRow.0}) {
                    rowX.2.center.y = HeaderA.center.y + 5 +
                        rowX.2.frame.height * 1.2 * CGFloat(rowIndex)
                    breakdownLabels.append(rowX.2)
                }
            }
            rowIndex += 1
        }
        for label in breakdownLabels { view.addSubview(label) }
    }
}
////////////////////////////////////////////////////////////////////////////////
