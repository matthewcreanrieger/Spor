////////10////////20////////30////////40////////50////////60////////70////////80
import UIKit
import CoreData

//most functions/methods here have already been explained via comments in "VCNewTransaction.swift" and/or "EditTransactions.swift" and have not been re-explained here

class VCSettings: UIViewController, UITextFieldDelegate {
    //Category properties
    var prps = ["Amount", "Title"]
    let prpPkr = UIPickerView()
    
    //currencies
    var ccys = [
        "$", "€", "¥", "£", "₫", "฿", "₽", "₹", "₠", "₿",
        "¤", "₵", "₡", "₳", "₢", "৳", "₯", "₣", "₲", "₴",
        "₭", "₥", "₦", "₧", "₱", "₰", "₨", "₪", "₮", "₩"
    ]
    let ccyPkr = UIPickerView()
    
    //periods
    var prds = ["Weekly", "Biweekly", "Monthly", "Yearly"]
    let prdPkr = UIPickerView()
    
    @IBOutlet weak var authenticationLabel: UILabel!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var loginButton: DesignableButton!
    @IBOutlet weak var signOutButton: DesignableButton!
    @IBOutlet weak var periodField: DesignableTextField!
    @IBOutlet weak var budgetLabel: UILabel!
    @IBOutlet weak var budgetField: DesignableTextField!
    @IBOutlet weak var currencyField: DesignableTextField!
    @IBOutlet weak var changeFromField: DesignableTextField!
    @IBOutlet weak var changeToField: DesignableTextField!
    @IBOutlet weak var changeButton: DesignableButton!
    @IBOutlet weak var deleteButton: DesignableButton!
    @IBOutlet weak var categoriesTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //done to re-sort "categoriesTable"
        fetchCtgs()
        
        //switches what authentication options are available depending if the user is logged in
        let username = UserDefaults.standard.string(forKey: "Username")
        if username == nil {
            authenticationLabel.isHidden = true
            signOutButton.isHidden = true
            usernameLabel.isHidden = true
            loginButton.isHidden = false
        } else { usernameLabel.text = username }
        
        budgetField.layer.borderWidth = 2.0
        budgetField.attributedPlaceholder = NSAttributedString(string:
            (UserDefaults.standard.string(forKey: "Currency") ?? "$") + "0.00",
            attributes: [NSAttributedString.Key.foregroundColor: greyDark]
        )
        let prd = UserDefaults.standard.string(forKey: "Period") ?? "Monthly"
        budgetLabel.text = prd.uppercased() + " BUDGET"
        
        changeFromField.text = prps[0]
        changeFromField.inputView = prpPkr
        prpPkr.delegate = self
        
        currencyField.text = UserDefaults.standard.string(forKey: "Currency")
        currencyField.inputView = ccyPkr
        ccyPkr.delegate = self
        for i in 0..<ccys.count {
            if currencyField.text == ccys[i] {
                ccyPkr.selectRow(i, inComponent: 0, animated: false)
                break
            }
        }
        
        periodField.text = prd
        periodField.inputView = prdPkr
        prdPkr.delegate = self
        for i in 0..<prds.count {
            if periodField.text == prds[i] {
                prdPkr.selectRow(i, inComponent: 0, animated: false)
                break
            }
        }
        
        let btn = UIBarButtonItem(title: "Close", style: .plain, target: self,
                                  action: #selector(closeButtonAction))
        let toolbar = makeToolbar()
        toolbar.setItems([btn], animated: true)
        for field in [budgetField, changeToField, changeFromField,
                      periodField, currencyField]
        {
            field?.delegate = self
            field?.inputAccessoryView = toolbar
            field?.tintColor = .white
        }
        
        refreshTable()
    }
    @objc func closeButtonAction() { view.endEditing(true) }
    
    //checking for missing categories can be done regardless of whether the user has already synced to their data store (as is the case in "VCNewTransaction.swift") because that is guaranteed to have already happened if the user made it to "Settings"
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkCtgMissing(self)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
        super.touchesBegan(touches, with: event)
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return false
    }
    
    @IBAction func editChangeToField(_ sender: DesignableTextField) {
        if changeFromField.text == "Amount" {
            sender.text = sender.text?.currencyFormat()
        }
        highlightButtons()
    }
    
    func highlightButtons() {
        changeToField.backgroundColor = greyDarkest
        if !ctgs.contains{ $0.selected } {
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
        
        globalTable = categoriesTable
        globalDeleteButton = deleteButton
        globalChangeButton = changeButton
        //only item that is different from "VCEditTransactions"'s matching function
        globalBudgetField = budgetField
    }

    func refreshTable() {
        budgetField.text = String(format:"%.02f",
            UserDefaults.standard.double(forKey: "Budget")).currencyFormat()
        categoriesTable.backgroundColor = greyDarkest
        categoriesTable.tintColor = .white
        categoriesTable.reloadData()
        highlightButtons()
    }
    
    @IBAction func tapDeleteCategories(_ sender: DesignableButton) {
        changeToField.backgroundColor = greyDarkest
        (ctgs.reduce(0) { $0 + ($1.selected ? 1 : 0) }) > 1 ?
            confirmCtgsDelete() : deleteCtgs()
    }
    
    //if the user decides to delete more than 1 Category at once, this function is used to confirm that choice
    func confirmCtgsDelete() {
        var ctgCt = 0
        var txnCt = 0
        for ctg in ctgs {
            if ctg.selected {
                ctgCt += 1
                for txn in txns { if txn.category == ctg.title {
                    txnCt += 1 }
                }
            }
        }
        if txnCt > 0 && ctgCt > 1 {
            let alert = UIAlertController(
                title: "Are You Sure You Want To Delete All " +
                    String(ctgCt) + " Selected Categories?",
                message: String(txnCt) + " Transaction" +
                    (txnCt > 1 ? "s" : "") + " associated with these " +
                    "categories will need to be deleted or recategorized.",
                preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(
                title: "Delete Categories", style: .destructive,
                handler: { action in self.deleteCtgs() }
            ))
            alert.addAction(UIAlertAction(
                title: "Cancel", style: .cancel, handler: nil
            ))
            present(alert, animated: true, completion: nil)
        }
        else { deleteCtgs() }
    }
    
    //if the user only attempted to delete 1 category or has confirmed that they want to delete more than 1, this function is called
    func deleteCtgs() {
        for ctg in ctgs.reversed() {
            if ctg.selected {
                //Categories are pushed to and overwrite what is stored in the data store often, so it is not necessary to do so here
                let b = UserDefaults.standard.double(forKey: "Budget")
                UserDefaults.standard.set(ctgs.count == 1 ? 0 : b - ctg.budget,
                                          forKey: "Budget")
                PersistenceService.context.delete(ctg)
            }
        }
        fetchCtgs()
        refreshTable()
        checkCtgMissing(self)
    }

    @IBAction func tapChangeCategories(_ sender: DesignableButton) {
        view.endEditing(true)
        if changeToField.text == "" { changeToField.backgroundColor = red }
        else {
            for ctg in ctgs {
                if ctg.selected {
                    switch changeFromField.text {
                    case "Amount":
                        let amt = changeToField.text ?? ""
                        let amtStr = String(amt.suffix(amt.count - 1))
                        var amtVal = Double(amtStr.replacingOccurrences(of: ",",
                            with: "", options: .literal, range: nil)) ?? 0
                        let bdg = UserDefaults.standard.double(forKey: "Budget")
                        
                        //prevent users from creating a budget greater than 999,999.99 by taking the difference between the what the projected budget would have been and 999,999.99 and subtracting that from the value the user wanted to input
                        //this will result in "Budget" equaling 999,999.99 and the budget for the category being adjusted to 999,999.99 - whatever the old budget was before the change
                        let projBudg = bdg - ctg.budget + amtVal
                        if projBudg > 999999.99 {
                            amtVal = amtVal - (projBudg - 999999.99)
                        }
                        UserDefaults.standard.set(bdg - ctg.budget + amtVal,
                                                  forKey: "Budget")
                        ctg.budget = amtVal
                    case "Title":
                        //prevent duplicate Category names by appending incrementing numbers ("num") to duplicates being added
                        var t = (changeToField.text ?? "New Category")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .capitalized
                        if ctg.title != t {
                            var num = 2
                            if ctgs.first(where: { $0.title == t } ) != nil {
                                t += String(num)
                            }
                            while ctgs.first(where: { $0.title == t } ) != nil {
                                num += 1
                                t = t.prefix(t.count - 1) + String(num)
                            }
                            ctg.title = t
                        }
                    default: break
                    }
                }
            }
            fetchCtgs()
            refreshTable()
            checkCtgMissing(self)
        }
    }
    
    //called when the user hits the plus button above "categoriesTable"
    @IBAction func tapAddCategory(_ sender: UIButton) {
        //only allow 20 Categories to be created
        if ctgs.count < 20 {
            //give new Categories the lowest ## in "Category##" possible between 1 and 20 that is greater than the current count of Categories
            //i.e., if there are 16 categories and category #16 is called "Category19", the new Category being added should be called "Category17", NOT "Category20"
            var num = ctgs.count + 1
            var ttl = "Category #" + String(num)
            var existingTtl = true
            while existingTtl == true {
                existingTtl = false
                for ctg in ctgs.reversed() {
                    if ctg.title == title {
                        num -= 1
                        ttl = "Category #" + String(num)
                        existingTtl = true
                        break
                    }
                }
            }
            
            //if there are no existing Categories, this new Category will have a default value of 100.0
            //otherwise, its budget will be directly proportional to the total number of Categories
            let bdg = UserDefaults.standard.double(forKey: "Budget")
            addCtgs(
                [ctgs.count > 0 ? bdg / Double(ctgs.count) : 100.0],
                [1.0 / Double(ctgs.count + 1)],
                [ttl]
            )
        } else {
            let alert = UIAlertController(
                title: "Too Many Categories",
                message: "Only 20 categories are allowed. You can swipe " +
                    "left on specific categories to delete them.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(
                title: "Roger, Roger", style: .cancel, handler: nil
            ))
            present(alert, animated: true, completion: nil)
        }
    }

    //if the user edits their budget, Categories are re-fetched and "categoriesTable" is updated
    @IBAction func editMoneyField(_ sender: DesignableTextField) {
        if sender.text != "" {
            let fmt = sender.text?.currencyFormat() ?? "$0.00"
            sender.text = fmt
            let reFmt = String(fmt.suffix(fmt.count - 1))
            let value = Double(reFmt.replacingOccurrences(
                of: ",", with: "", options: .literal, range: nil)) ?? 0
            UserDefaults.standard.set(value, forKey: "Budget")
            for ctg in ctgs { ctg.budget = ctg.proportion * value }
            fetchCtgs()
            refreshTable()
        }
    }
    
    @IBAction func tapSignOut(_ sender: DesignableButton) {
        //reset all senstive CoreData and UserDefaults
        dbr = nil
        UserDefaults.standard.set(false, forKey: "SkipLogin")
        UserDefaults.standard.removeObject(forKey: "UserID")
        UserDefaults.standard.removeObject(forKey: "Username")
        UserDefaults.standard.removeObject(forKey: "Budget")
        UserDefaults.standard.removeObject(forKey: "FirebaseFetched")
        for ctg in ctgs { PersistenceService.context.delete(ctg) }
        for txn in txns { PersistenceService.context.delete(txn) }
        ctgs = []
        txns = []
        PersistenceService.saveContext()
        
        //set new default UserDefaults and Categories
        setDefaults()
        setDefaultCtgs()
        refreshTable()
        
        //switch which authentication type is visible in "Settings"
        authenticationLabel.isHidden = true
        signOutButton.isHidden = true
        usernameLabel.isHidden = true
        loginButton.isHidden = false
    }
    
    //transition the user to the last screen they were on before "Settings"
    @IBAction func tapBack(_ sender: UIButton) {
        //don't allow the user to leave "Settings" with no Categories
        if ctgs.count == 0 { setDefaultCtgs() }
        
        //reset "StartDate" and sort Transactions correctly in case "LastScreen" is a "Dashboard"
        fetchTxns(sortBy: "Date", asc: true)
        
        let id = UserDefaults.standard.string(forKey: "LastScreen")
        performSegue(withIdentifier: (id ?? "NewTransaction"), sender: nil)
    }
}

extension VCSettings:
    UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate
{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int)
        -> Int
        { return ctgs.count }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
        -> UITableViewCell
    {
        let c = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        c.backgroundColor = .clear
        c.textLabel?.textColor = .white
        c.textLabel?.font = UIFont(name: "Metropolis-ExtraBold", size: 17)
        c.detailTextLabel?.textColor = offWhite
        c.detailTextLabel?.font = UIFont(name: "Metropolis-Regular", size: 14)
        c.textLabel?.text = ctgs[indexPath.row].title
        
        let bdg = ctgs[indexPath.row].budget
        let bdgFmt = String(format:"%.02f", bdg).currencyFormat()
        let prt = ctgs[indexPath.row].proportion * 100.0
        let prtFmt = String(format:"%.02f%% of Budget", prt)
        c.detailTextLabel?.text = "Allowance: " + bdgFmt + "; " + prtFmt
        
        return c
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) { createCheckmarks() }
    
    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath)
    {
        tableView.reloadData()
        ctgs[indexPath.row].selected = !ctgs[indexPath.row].selected
        highlightButtons()
        createCheckmarks()
    }
    
    func tableView(_ tableView: UITableView,
                   didDeselectRowAt indexPath: IndexPath)
    {
        tableView.reloadData()
        ctgs[indexPath.row].selected = !ctgs[indexPath.row].selected
        highlightButtons()
        createCheckmarks()
    }
    
    func createCheckmarks() {
        for i in 0..<ctgs.count {
            if ctgs[i].selected {
                if let cell = categoriesTable.cellForRow(
                    at: IndexPath(row: i, section: 0))
                {
                    cell.contentView.superview?.backgroundColor = greyDarker
                    cell.accessoryType = .checkmark
                    cell.selectionStyle = .none
                }
            }
        }
    }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath)
    {
        if editingStyle == .delete {
            //revelauate "Budget"
            let bdg = UserDefaults.standard.double(forKey: "Budget")
            let bdgNew = ctgs.count == 1 ? 0 : bdg - ctgs[indexPath.row].budget
            UserDefaults.standard.set(bdgNew, forKey: "Budget")
            budgetField.text = String(format:"%.02f", bdgNew).currencyFormat()
            
            //delete selected Category, highlight change and delete buttons, and check for missing Categories
            PersistenceService.context.delete(ctgs[indexPath.row])
            ctgs.remove(at: indexPath.row)
            PersistenceService.saveContext()
            tableView.beginUpdates()
            tableView.deleteRows(at: [indexPath], with: .automatic)
            tableView.endUpdates()
            highlightButtons()
            checkCtgMissing(self)
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

extension VCSettings: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { return 1 }
    
    func pickerView(_ pickerView: UIPickerView,
                    numberOfRowsInComponent component: Int) -> Int
    {
        pickerView.backgroundColor = greyDarkest
        switch pickerView {
        case prpPkr: return prps.count
        case ccyPkr: return ccys.count
        case prdPkr: return prds.count
        default:     return 0
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int,
                    forComponent component: Int) -> String?
    {
        switch pickerView {
        case prpPkr: return prps[row]
        case ccyPkr: return ccys[row]
        case prdPkr: return prds[row]
        default:     return ""
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int,
                    inComponent component: Int) {
        switch pickerView {
        case prpPkr:
            changeFromField.text = prps[row]
            if changeFromField.text == "Amount" {
                changeToField.keyboardType = UIKeyboardType.numberPad }
            else { changeToField.keyboardType = UIKeyboardType.default }
            changeToField.keyboardAppearance = UIKeyboardAppearance.dark
            changeToField.text = ""
            highlightButtons()
        case ccyPkr:
            currencyField.text = ccys[row]
            UserDefaults.standard.set(ccys[row], forKey: "Currency")
            refreshTable()
        case prdPkr:
            periodField.text = prds[row]
            UserDefaults.standard.set(prds[row], forKey: "Period")
            budgetLabel.text = prds[row].uppercased() + " BUDGET"
            dbr?.child("Settings").updateChildValues(["Period": prds[row]])
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
        case prpPkr: label.text = prps[row]
        case ccyPkr: label.text = ccys[row]
        case prdPkr: label.text = prds[row]
        default:     label.text = ""
        }
        return label
    }
}
////////10////////20////////30////////40////////50////////60////////70////////80
