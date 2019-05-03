////////10////////20////////30////////40////////50////////60////////70////////80
import UIKit

class VCSummary: UIViewController {
    //most of these variables are defined here in order to dynamically change their font size so that they are all the same size
    @IBOutlet weak var cover: UIView!
    @IBOutlet weak var budgetIsLabel: UILabel!
    @IBOutlet weak var budgPerDayLabel: UILabel!
    @IBOutlet weak var currentlyLabel: UILabel!
    @IBOutlet weak var overUnderLabel: UILabel!
    @IBOutlet weak var byLabel: UILabel!
    @IBOutlet weak var overUnderAmountLabel: UILabel!
    @IBOutlet weak var overUnderPercentLabel: UILabel!
    @IBOutlet weak var spendNothingLabel: UILabel!
    @IBOutlet weak var breakEvenLabel: UILabel!
    @IBOutlet weak var outstandingCategoryLabel: UILabel!
    @IBOutlet weak var outstandingCategoryAmountLabel: UILabel!
    @IBOutlet weak var outstandingCategoryPercentLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        UserDefaults.standard.set(title, forKey: "LastScreen")
        //allows user to return to this screen after exiting "NewTransaction" or "EditTransactions"
        UserDefaults.standard.set(title, forKey: "LastDashboard")
        
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
                performSegue(withIdentifier: "LineChartPercentR", sender: nil)
            case .left:
                performSegue(withIdentifier: "BreakdownL", sender: nil)
            case .up:
                performSegue(withIdentifier: "NewTransactionU", sender: nil)
            default: break
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        //the delay prevents screen flashing caused by the same steps being carried out twice within the duration of "Segues.swift"'s animations
        //"finishAppear(...)" is called as a seperate function so that all variables don't need to be prefaced with "self."
        super.viewDidAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(301),
                                      execute: { self.finishAppear() }
        )
    }
    
    //for "Summary" at "viewDidAppear(...)", set the "text" and "textColor" properties of all UILabels in "Summary" with dynamic sizes and content
    //the size-related aspects of this function cannot be called at "viewDidLoad(...)" because they rely on fetching the font sizes that are set automatically at "viewDidAppear(...)"
    //since all of the UILabels in "Summary" are covered by "cover" until the end of "animateSummary(...)", it is not necessary that they be set at "viewDidLoad(...)"
    func finishAppear() {
        //determine budget per day ("budgPerDay") based on the the number of days in the user's selected budgeting period
        var budgDiv = 1.0
        var budgPerDay = 1.0
        switch UserDefaults.standard.string(forKey: "Period") {
        case "Weekly":   budgDiv = 7.0
        case "Biweekly": budgDiv = 14.0
        case "Monthly":  budgDiv = 30.436875
        case "Yearly":   budgDiv = 365.24219
        default: break
        }
        budgPerDay = UserDefaults.standard.double(forKey: "Budget") /  budgDiv

        let now = Date()
        let start = UserDefaults.standard.string(forKey: "StartDate")
        let daysSinceStart =
            now.timeIntervalSince((start ?? now.toString()).toDate()) / 86400
        
        let cumulBudg = daysSinceStart * budgPerDay
        //calculate the total amount of all transactions on or before today
        var cumulSpend = 0.0
        for txn in txns {
            if txn.date <= now { cumulSpend -= txn.amount }
            else { break }
        }

        //"dateFormatted" is used to extract "currentHour" and "currentMinute" from the date at the time "Summary" is loaded
        //"currentHour" and "currentMinute" are used to calculate the components that make up "breakEvenLabel"
        //"breakEvenLabel" displays either the date since when users have been under budget or, if they are over budget, the date that they will break even on after spending nothing for the amount of days they are over budget by
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy HH:mm"
        let dateFormatted = dateFormatter.string(from: now)
        let currentHour = Double(dateFormatted.suffix(5).prefix(2)) ?? 0.0
        let currentMinute = Int(dateFormatted.suffix(2)) ?? 0
        
        //"daysOverUnder" is a Double that represents the amount of days that a user is over or under budget
        //"abs" is used so that the individual components of "day", "hour", and "minute" over/under budget can be extracted using the "floor" function
        //"day", "hour", and "minute" are either added or subtracted from "currentHour" and "currentMinute" later in order to calculate the componenets that make up "breakEvenLabel"
        let daysOverUnder = abs((cumulSpend - cumulBudg) / budgPerDay)
        var day = floor(daysOverUnder)
        var hour = floor((daysOverUnder - day) * 24)
        var minute = Int(((daysOverUnder - day) * 24 - hour) * 60)

        //"ctgDiffsAmount" and "ctgDiffsPercent" are used to identify the category by which a user is most over or under budget and to display each amount over or under budget for that category
        var ctgDiffsAmount = [Double]()
        var ctgDiffsPercent = [Double]()
        for ctg in ctgs {
            let cumulCtgBudg = daysSinceStart * ctg.budget / budgDiv
            var cumulCtgSpend = 0.0
            for txn in txns {
                if txn.date <= now {
                    if txn.category == ctg.title {cumulCtgSpend -= txn.amount}
                }
                else { break }
            }
            ctgDiffsAmount.append(cumulCtgSpend - cumulCtgBudg)
            ctgDiffsPercent.append(cumulCtgSpend / cumulCtgBudg * 100 - 100)
        }

        //after calculating all of the above variables, begin populating the ".text" and ".textColor" properties of the "Summary" labels based on whether or not the user is over or under budget
        //the budget per day and amount over/under budget will be the same whether or not a user is over or under budget and therefore are set outside of the "cumulSpend > cumulBudg" conditional
        budgPerDayLabel.text =
            String(format:"%.02f", budgPerDay).currencyFormat() + " Per Day"
        overUnderAmountLabel.text =
            String(format:"%.02f", cumulSpend - cumulBudg).currencyFormat()

        //if the user is over budget...
        if cumulSpend > cumulBudg {
            let pct1 = cumulBudg == 0 ?
                999999.9 : cumulSpend / cumulBudg * 100 - 100
            overUnderPercentLabel.text = String(pct1.twoDecimals()) + "%"
            overUnderLabel.text = "OVER"
            overUnderLabel.textColor = red
            breakEvenLabel.textColor = red

            //identify the index for the maximum value contained in "ctgDiffsAmount" and use this index to identify the category that the following labels should represent
            let i = ctgDiffsAmount.index(of: ctgDiffsAmount.max() ?? 0) ?? 0
            outstandingCategoryLabel.text = "The category most over budget is "
                + ctgs[i].title + " by:"
            outstandingCategoryAmountLabel.text = String(format: "%.02f",
                ctgDiffsAmount[i]).currencyFormat()
            let pct2 = ctgDiffsPercent[i].isNaN ? 999999.99 : ctgDiffsPercent[i]
            outstandingCategoryPercentLabel.text =
                String(pct2.twoDecimals()) + "%"
            
            //"minute" and "hour" are added to their respective "current" variables, then...
            //...if "minute" is greater than or equal to 60, 60 minutes need to be subtracted from "minute" and added as 1 hour to "hour"
            //...if "hour" is greater than or equal to 24, 24 hours need to be subtracted from "hour" and added as 1 day to "day"
            minute = currentMinute + minute
            hour = currentHour + hour
            if minute >= 60 {
                minute -= 60
                hour += 1
            }
            if hour >= 24 {
                hour -= 24
                day += 1
            }

            spendNothingLabel.text = String(format:
                "If you spend nothing for %.02f days, you will break even on:",
                daysOverUnder
            )
        }
        //if a user is under budget, do the opposite of everything above
        else {
            //values need to be negative because "you are under budget by -12.34%" is a double negative statement
            let pct1 = cumulBudg == 0 ?
                100.0 : -(cumulSpend / cumulBudg * 100 - 100)
            overUnderPercentLabel.text = String(pct1.twoDecimals()) + "%"
            overUnderLabel.text = "UNDER"
            overUnderLabel.textColor = teal
            breakEvenLabel.textColor = teal

            //".min" in "ctgDiffsAmount" is used instead of ".max"
            let index = ctgDiffsAmount.index(of: ctgDiffsAmount.min() ?? 0) ?? 0
            outstandingCategoryLabel.text = "The category most under budget is "
                + ctgs[index].title + " by:"
            outstandingCategoryAmountLabel.text = String(format: "%.02f",
                ctgDiffsAmount[index]).currencyFormat()
            let pct2 =
                ctgDiffsPercent[index].isNaN ? 100.0 : -ctgDiffsPercent[index]
            outstandingCategoryPercentLabel.text =
                String(pct2.twoDecimals()) + "%"
            
            //day needs to be made negative because the date component of "breakEvenLabel" is determined using "byAdding" in "Calendar.current.date(...)"; there isn't just a String that is set to equal "day" like there is for "minute" and "hour"
            //"minute" and "hour" are subtracted from their respective "current" variables, then...
            //...if "minute" is less than or equal to 0, 1 hour needs to be subtracted from "hour" and added as 60 minutes to "minute"
            //...if "hour" is less than or equal to 0, 1 day needs to be subtracted from "day" and added as 24 hours to "hour"
            minute = currentMinute - minute
            hour = currentHour - hour
            day = -day
            if minute < 0 {
                minute += 60
                hour -= 1
            }
            if hour < 0 {
                hour += 24
                day -= 1
            }
            spendNothingLabel.text = String(format:
                "Congrats! You have been under budget for %.02f days, since:",
                daysOverUnder
            )
        }
        let d = Calendar.current.date(byAdding: .day, value: Int(day), to: now)
        breakEvenLabel.text = (d ?? now).toString()
            + String(format: " at %02d:%02d", Int(hour), minute)

        //ensure all UILabels in Summary have the same font size as the smallest font size in their group
        func formatLabelFont( _ font: String, _ labels: [UILabel]) {
            var minSize = labels.first?.getFontSizeForLabel() ?? 15
            for l in labels { minSize = min(minSize, l.getFontSizeForLabel()) }
            for l in labels { l.font = UIFont(name: font, size: minSize) }
        }
        formatLabelFont("Metropolis-Regular", [
            budgetIsLabel,
            byLabel,
            currentlyLabel,
            spendNothingLabel,
            overUnderLabel,
            outstandingCategoryLabel
        ])
        formatLabelFont("Metropolis-ExtraBold", [
            overUnderAmountLabel,
            breakEvenLabel,
            budgPerDayLabel,
            overUnderPercentLabel,
            outstandingCategoryAmountLabel,
            outstandingCategoryPercentLabel
        ])
        
        //"overUnderLabel" is unique in that it has the same font size as the first group of labels and the same font family as the second group
        overUnderLabel.font = UIFont(
            name: "Metropolis-ExtraBold",
            size: overUnderLabel.getFontSizeForLabel()
        )
        
        //in order to prevent the user from seeing the UILabels updating, a UIView ("cover") with the same color as the background of "Summary" covers all of the dynamic UILabels until they have finished updating, at which point it is hidden from view
        cover.isHidden = true
    }
}
////////10////////20////////30////////40////////50////////60////////70////////80
