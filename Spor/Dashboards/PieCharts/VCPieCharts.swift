////////////////////////////////////////////////////////////////////////////////
import UIKit

class VCPieCharts: UIViewController, PieChartDelegate {
    @IBOutlet weak var currentPie: PieChart!
    @IBOutlet weak var targetPie: PieChart!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //disable user interaction until animations are complete in order to prevent unexpected behavior
        view.isUserInteractionEnabled = false
        
        UserDefaults.standard.set(title, forKey: "LastScreen")
        UserDefaults.standard.set(title, forKey: "LastDashboard")
        
        fetchTransactions(sortBy: "Date", ascending: true)
        
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
                performSegue(withIdentifier: "BreakdownR", sender: nil)
            case .left:
                performSegue(withIdentifier: "LineChartAmountL", sender: nil)
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
    
    //determine the color and value of each pie slice
    func finishAppear() {
        pies = []
        var sliceModelsCurrent = [PieSliceModel]()
        var sliceModelsTarget = [PieSliceModel]()

        //because clicking on one pie's slice expands the matching slice in the other pie, slices cannot be excluded from a pie's slice model just because their values are 0 or we would create index-out-of-range exceptions
        //instead, empty slices are just hidden so that expanding them displays nothing to the user
        //therefore, since empty slices cannot be excluded from each pie's slice model, whether or not a pie is "empty" needs to be decided by determining if ALL slices are empty
        //"empty" for "currentPie" means that every slice is 0.0, but "targetPie" needs to be evaluated differently because every slice will always add up to 100%, so simply checking for non-zero values doesn't work
        //this is why "currentPieEmpty" and "targetPieEmpty" are used to filter out empty pies
        var currentPieEmpty = true
        var targetPieEmpty = true
        for cat in categories {
            var cumulSpend = 0.0
            for tra in transactions {
                if tra.date > Date() { break }
                else if tra.category == cat.title { cumulSpend -= tra.amount }
            }
            if cumulSpend > 0 { currentPieEmpty = false }
            sliceModelsCurrent.append(PieSliceModel(
                value: max(cumulSpend, 0),
                description: cat.title,
                color: colors[categories.firstIndex(of: cat)!]
            ))
            if cat.budget > 0 { targetPieEmpty = false }
            sliceModelsTarget.append(PieSliceModel(
                value: cat.proportion,
                description: cat.title,
                color: colors[categories.firstIndex(of: cat)!]
            ))
        }
        if !currentPieEmpty { pies.append(currentPie) }
        if !targetPieEmpty { pies.append(targetPie) }
        
        //format and display the pies
        for pie in pies {
            pie.outerRadius = pie.bounds.height * 0.5
            pie.innerRadius = pie.outerRadius * 0.35
            pie.layers = [PiePlainTextLayer(), PieLineTextLayer()]
            pie.delegate = self
            
            //this needs to be done within the "for..." loop because it prevents empty pies from having their slice models displayed
            if pie == currentPie { currentPie.models = sliceModelsCurrent }
            if pie == targetPie { targetPie.models  = sliceModelsTarget }
        }
        
        //after a short delay, select/expand the first slice in each pie to indicate to users that they can click on slices to expand them
        //both pies first slices need to be selected even if one isn't displayed because otherwise the function that ensures matching slices get selected/unselected does not function properly
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
            self.currentPie.slices.first?.view.selected = true
            self.targetPie.slices.first?.view.selected = true
            self.view.isUserInteractionEnabled = true
        })
    }
}
////////////////////////////////////////////////////////////////////////////////
