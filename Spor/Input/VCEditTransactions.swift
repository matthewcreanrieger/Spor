////////10////////20////////30////////40////////50////////60////////70////////80
import UIKit
import CoreData

class VCEditTransactions: UIViewController, UITextFieldDelegate {
    //Transaction properties and UIPickerViews used to change or sort Transactions
    var prps = ["Amount", "Category", "Date", "Description", "Transaction #"]
    let prpPkr = UIPickerView()
    let sortPkr = UIPickerView()
    
    //used to display alternative input views for "changeToField"
    var prevCtg = 0
    let ctgPkr = UIPickerView()
    var datePkr = UIDatePicker()
    var revenue = false
    
    @IBOutlet weak var sortField: DesignableTextField!
    @IBOutlet weak var changeFromField: DesignableTextField!
    @IBOutlet weak var revenueButton: DesignableButton!
    @IBOutlet weak var expenseButton: DesignableButton!
    @IBOutlet weak var changeToField: DesignableTextField!
    @IBOutlet weak var changeButton: DesignableButton!
    @IBOutlet weak var deleteButton: DesignableButton!
    @IBOutlet weak var transactionsTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UserDefaults.standard.set(title, forKey: "LastScreen")
        
        //"asc:" is set to false mostly so that the most recent Transactions are at top
        fetchTxns(sortBy: "Transaction #", asc: false)
        
        let swipeD = UISwipeGestureRecognizer(
            target: self, action: #selector(respondToSwipeGesture(_:)))
        swipeD.direction = .down
        view.addGestureRecognizer(swipeD)
        
        //the default selected Transaction property that the user can sort by
        sortField.text = "Transaction #"
        sortField.inputView = sortPkr
        //this loop determines what default property is set for "sortField" (in this case, "Transaction #") and sets the selected row of the input view picker to that property
        sortPkr.delegate = self
        for i in 0..<prps.count {
            if sortField.text == prps[i] {
                sortPkr.selectRow(i, inComponent: 0, animated: false)
                break
            }
        }
        
        //the default selected Transaction property that the user can change
        changeFromField.text = "Category"
        changeFromField.inputView = prpPkr
        prpPkr.delegate = self
        //"-1" is used because "Transaction #" is excluding as a Transaction property that the user can change
        for i in 0..<(prps.count-1) {
            if changeFromField.text == prps[i] {
                prpPkr.selectRow(i, inComponent: 0, animated: false)
                break
            }
        }
        
        changeToField.autocapitalizationType = .sentences
        //since the default selected Transaction property is "Category", the input view for "changeToField" must be "ctgPkr" (Category picker)
        changeToField.inputView = ctgPkr
        ctgPkr.delegate = self
        
        let btn = UIBarButtonItem(title: "Close", style: .plain, target: self,
                                  action: #selector(closeButtonAction))
        let toolbar = makeToolbar()
        toolbar.setItems([btn], animated: true)
        for field in [sortField, changeFromField, changeToField] {
            field?.delegate = self
            field?.inputAccessoryView = toolbar
            field?.tintColor = .white
        }
        
        //apply special formatted and reload the data for "transactionsTable"
        refreshTable()
    }
    @objc func closeButtonAction() { view.endEditing(true) }
    @objc func respondToSwipeGesture(_ gesture: UIGestureRecognizer) {
        performSegue(withIdentifier: "NewTransactionD", sender: nil)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
        super.touchesBegan(touches, with: event)
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return false
    }
    
    //respond to the user editing "changeToField"
    @IBAction func editChangeToField(_ sender: DesignableTextField) {
        if changeFromField.text == prps[0] {
            sender.text = sender.text?.currencyFormat()
        }
        highlightButtons()
    }

    //determine whether "changeButton" and/or "deleteButton" can be highlighted based on whether required criteria have been met
    //"deleteButton" is innactive unless the user selects at least one row in "transactionsTable"
    //"changeButton" is innactive unless the user selects at least one row in "transactionsTable" and "changeToField" is not blank
    func highlightButtons() {
        changeToField.backgroundColor = greyDarkest
        if !txns.contains{ $0.selected } {
            deleteButton.backgroundColor = greyDark
            deleteButton.setTitleColor(greyDarker, for: .normal)
            deleteButton.isEnabled = false
            changeButton.backgroundColor = greyDark
        } else {
            deleteButton.backgroundColor = red
            deleteButton.setTitleColor(greyDarkest, for: .normal)
            deleteButton.isEnabled = true
            if changeToField.text != "" { changeButton.backgroundColor = teal }
            else { changeButton.backgroundColor = greyDark }
        }
        
        //these "global" variables are used to return proper sorting and formatting after global functions are called in "InputHelperFunctions.swift" that affect "transactionsTable"
        globalTable = transactionsTable
        globalDeleteButton = deleteButton
        globalChangeButton = changeButton
    }
    
    //reapply special formatting whenever "transactionsTable" is updated
    func refreshTable() {
        transactionsTable.backgroundColor = greyDarkest
        transactionsTable.tintColor = .white
        transactionsTable.reloadData()
        highlightButtons()
    }
    
    //if only 1 Transaction is selected, delete it
    //if more than 1 Transaction is selected, ask the user to confirm that they want to delete them
    @IBAction func tapDeleteTransactions(_ sender: DesignableButton) {
        changeToField.backgroundColor = greyDarkest
        (txns.reduce(0) { $0 + ($1.selected ? 1 : 0) }) > 1 ?
            confirmTxnsDelete(self, "") : deleteTxns(self)
    }
    
    @IBAction func tapChangeTransactions(_ sender: DesignableButton) {
        view.endEditing(true)
        //if the required field is not completed, highlight it red
        if changeToField.text == "" { changeToField.backgroundColor = red }
        //otherwise, determine which property the user wants to change and change that property to the value of "changeToField" for all selected Transactions
        else {
            for txn in txns {
                if txn.selected {
                    switch changeFromField.text {
                    case prps[0]:
                        let amt = changeToField.text ?? ""
                        let amtStr = String(amt.suffix(amt.count - 1))
                        let amtVal = Double(amtStr.replacingOccurrences(
                            of: ",", with: "", options: .literal, range: nil))
                        txn.amount = (revenue ? 1 : -1) * (amtVal ?? 0)
                        txn.sign = revenue
                    case prps[1]:
                        txn.category =
                            changeToField.text ?? ctgs.first?.title ?? ""
                    case prps[2]:
                        txn.date =
                            (changeToField.text ?? Date().toString()).toDate()
                    case prps[3]:
                        txn.title = changeToField.text ?? "(no description)"
                    default: break
                    }
                    txn.selected = false
                    let upd: [AnyHashable: Any] = [
                        "Amount":   txn.amount,
                        "Category": txn.category,
                        "Date":     txn.date.toString(),
                        "Index":    txn.index,
                        "Selected": txn.selected,
                        "Sign":     txn.sign,
                        "Title":    txn.title
                    ]
                    let chl = String(format: "Transaction%06d", txn.index)
                    dbr?.child("Transactions").child(chl).updateChildValues(upd)
                }
            }
            PersistenceService.saveContext()
            
            //do not fetch Transactions before refreshing the table because fetching will resort the Transactions which will move anything the user just changed to a new location on the table, likely out of view, which is bad UX
            refreshTable()
        }
    }
    
    //reverse the order by which the Transactions are displayed
    @IBAction func tapReverse(_ sender: DesignableButton) {
        fetchTxns(sortBy: sortField.text ?? "Transaction #", asc: !globalAscending)
        refreshTable()
    }
    
    @IBAction func tapSign(_ sender: DesignableButton) {
        revenue = !revenue
        if revenue {
            expenseButton.borderColor = greyLighter
            expenseButton.setTitleColor(greyLighter, for: .normal)
            revenueButton.borderColor = teal
            revenueButton.setTitleColor(.white, for: .normal)
        } else {
            expenseButton.borderColor = red
            expenseButton.setTitleColor(.white, for: .normal)
            revenueButton.borderColor = greyLighter
            revenueButton.setTitleColor(greyLighter, for: .normal)
        }
    }
    
    //"tapDashboards" here is different than the matching function in "VCNewTransaction.swift" because it first checks if any Categories are missing before segueing to "Dashboards"
    //the reason for this is that "EditTransactions" does NOT check for missing categories at any point because it is the destination View Controller for users who choose to "Re-Categorize" Transactions that are identified as belonging to a missing Category
    //therefore, before the user is allowed to leave "EditTransactions" to go to a "Dashboard", verify that the user has actually re-categorized all problematic Transactions
    //if the user goes to "Settings" or "NewTransaction" instead of "Dashboards", this check is unecessary because those View Controllers will check for missing Categories at "viewDidLoad(...)"
    @IBAction func tapDashboards(_ sender: UIButton) {
        var ctgMissing = false
        for txn in txns {
            if ctgs.first(where: { $0.title == txn.category } ) == nil {
                ctgMissing = true
                break
            }
        }
        if ctgMissing { checkCtgMissing(self) }
        else {
            fetchTxns(sortBy: "Date", asc: true)
            let dsh = UserDefaults.standard.string(forKey: "LastDashboard")
            performSegue(withIdentifier: (dsh ?? "Summary") + "D", sender: nil)
        }
    }

    //create the picker used by "changeToField" any "prpPkr" is set to "Date"
    //called multiple times to ensure that the special color formatting sticks
    func createdatePkr() {
        datePkr = UIDatePicker()
        datePkr.addTarget(self, action: #selector(dateChanged(datePkr:)),
                          for: .valueChanged)
        datePkr.backgroundColor = greyDarkest
        datePkr.datePickerMode = .date
        var dateComponents = DateComponents()
        dateComponents.year = -1
        let yrAgo = Calendar.current.date(byAdding: dateComponents, to: Date())
        let start = UserDefaults.standard.string(forKey: "StartDate")?.toDate()
        datePkr.minimumDate = min(yrAgo ?? Date(), start ?? Date())
        datePkr.setValue(UIColor.white, forKey: "textColor")
    }
    @objc func dateChanged(datePkr: UIDatePicker) {
        changeToField.text = datePkr.date.toString()
        highlightButtons()
    }
}

extension VCEditTransactions:
    UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate
{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int)
        -> Int
        { return txns.count }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
        -> UITableViewCell
    {
        let c = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        c.backgroundColor = .clear
        c.textLabel?.textColor = .white
        c.textLabel?.font = UIFont(name: "Metropolis-ExtraBold", size: 17)
        c.detailTextLabel?.textColor = offWhite
        c.detailTextLabel?.font = UIFont(name: "Metropolis-Regular", size: 14)
        
        let sign = txns[indexPath.row].sign ? "+" : "-"
        let amt = String(format:"%.02f", abs(txns[indexPath.row].amount))
        let ctg = String(txns[indexPath.row].category)
        c.textLabel?.text = sign + amt.currencyFormat() + " for " + ctg
        
        let idx = String(txns[indexPath.row].index)
        let ttl = txns[indexPath.row].title
        let date = txns[indexPath.row].date.toString()
        c.detailTextLabel?.text = "#" + idx + ": " + ttl + " on " + date
        
        return c
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) { createCheckmarks() }

    //"didSelectRowAt" and "didDeselectRowAt" do the same thing:
    //reload "transactionTable", which clears all checkmarks, then flip selected for the selected Transaction, highlight/unhighlight the add and delete buttons, and create all checkmarks again
    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath)
    {
        tableView.reloadData()
        txns[indexPath.row].selected = !txns[indexPath.row].selected
        highlightButtons()
        createCheckmarks()
    }
    
    func tableView(_ tableView: UITableView,
                   didDeselectRowAt indexPath: IndexPath)
    {
        tableView.reloadData()
        txns[indexPath.row].selected = !txns[indexPath.row].selected
        highlightButtons()
        createCheckmarks()
    }

    func createCheckmarks() {
        for i in 0..<txns.count {
            if txns[i].selected {
                if let cell = transactionsTable.cellForRow(
                    at: IndexPath(row: i, section: 0))
                {
                    cell.contentView.superview?.backgroundColor = greyDarker
                    cell.accessoryType = .checkmark
                    cell.selectionStyle = .none
                }
            }
        }
    }
    
    //same as what is in "VCNewTransaction.swift" but also calls "highlightButtons(...)"
    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath)
    {
        if editingStyle == .delete {
            let c = String(format: "Transaction%06d", txns[indexPath.row].index)
            dbr?.child("Transactions").child(c).removeValue()
            PersistenceService.context.delete(txns[indexPath.row])
            txns.remove(at: indexPath.row)
            PersistenceService.saveContext()
            tableView.beginUpdates()
            tableView.deleteRows(at: [indexPath], with: .automatic)
            tableView.endUpdates()
            firebasePushTxns()
            highlightButtons()
        }
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt
        indexPath: IndexPath) -> [UITableViewRowAction]?
    {
        let deleteButton =
            UITableViewRowAction(style: .default, title: "Delete") {
                (action, indexPath) in
                tableView.dataSource?.tableView?(tableView,
                                                 commit: .delete,
                                                 forRowAt: indexPath)
                return
        }
        deleteButton.backgroundColor = red
        return [deleteButton]
    }
}

//there are 3 different pickers that the user may be interacted with
//appropriate actions are determined via switches that identify the active picker
extension VCEditTransactions: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { return 1 }
    
    func pickerView(_ pickerView: UIPickerView,
                    numberOfRowsInComponent component: Int) -> Int
    {
        pickerView.backgroundColor = greyDarkest
        switch pickerView {
        case ctgPkr:
            if changeToField.text == "" {
                changeToField.text = ctgs[prevCtg].title
            }
            highlightButtons()
            return ctgs.count
        case prpPkr:  return prps.count - 1
        case sortPkr: return prps.count
        default:      return 0
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int,
                    forComponent component: Int) -> String?
    {
        switch pickerView {
        case prpPkr:  return prps[row]
        case ctgPkr:  return ctgs[row].title
        case sortPkr: return prps[row]
        default:      return ""
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int,
                    inComponent component: Int)
    {
        switch pickerView {
        case prpPkr:
            //set "changeFromField" to the currently selected Transaction property
            changeFromField.text = prps[row]
            
            //erase whatever may be set for "changeToField"
            changeToField.text = ""
            
            //hide these buttons unless the selected Transaction property is "Amount"
            revenueButton.isHidden = true
            expenseButton.isHidden = true
            
            //remove any special input views unless the selected Transaction property is "Date" or "Category"
            changeToField.inputView = nil
            
            switch changeFromField.text {
            case prps[0]:
                changeToField.keyboardType = UIKeyboardType.numberPad
                changeToField.keyboardAppearance = UIKeyboardAppearance.dark
                revenueButton.isHidden = false
                expenseButton.isHidden = false
            case prps[1]:
                changeToField.inputView = ctgPkr
                changeToField.text = ctgs[prevCtg].title
            case prps[2]:
                createdatePkr()
                changeToField.inputView = datePkr
                changeToField.text = Date().toString()
            case prps[3]:
                changeToField.keyboardType = UIKeyboardType.default
                changeToField.keyboardAppearance = UIKeyboardAppearance.dark
            default: break
            }
            
            //check if the buttons should be highlighted since "Category" and "Date" auto-populate "changeToField"
            highlightButtons()
            
        case ctgPkr:
            prevCtg = row
            changeToField.text = ctgs[prevCtg].title
            highlightButtons()
        case sortPkr:
            sortField.text = prps[row]
            //"asc:" is set to false mostly so that the most recent Transactions are at top
            fetchTxns(sortBy: prps[row], asc: false)
            refreshTable()
        default: break
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int,
        forComponent component: Int, reusing view: UIView?) -> UIView
    {
        let label = UILabel()
        label.backgroundColor = greyDarkest
        label.font = UIFont(name: "Menlo", size: 25)
        label.textAlignment = .center
        label.textColor = .white
        switch pickerView {
        case prpPkr:  label.text = prps[row]
        case ctgPkr:  label.text = ctgs[row].title
        case sortPkr: label.text = prps[row]
        default:      label.text = ""
        }
        return label
    }
}
////////10////////20////////30////////40////////50////////60////////70////////80
