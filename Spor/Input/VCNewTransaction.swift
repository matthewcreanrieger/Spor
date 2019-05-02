////////10////////20////////30////////40////////50////////60////////70////////80
import UIKit
import CoreData
import Firebase

class VCNewTransaction: UIViewController, UITextFieldDelegate {
    
    let ctgPkr = UIPickerView()
    var datePkr = UIDatePicker()
    var revenue = false
    
    @IBOutlet weak var entriesOutlineView: DesignableView!
    @IBOutlet weak var revenueButton: DesignableButton!
    @IBOutlet weak var expenseButton: DesignableButton!
    @IBOutlet weak var amountField: DesignableTextField!
    @IBOutlet weak var titleField: DesignableTextField!
    @IBOutlet weak var categoryField: DesignableTextField!
    @IBOutlet weak var dateField: DesignableTextField!
    @IBOutlet weak var addToLedgerButton: DesignableButton!
    @IBOutlet weak var transactionsTable: UITableView!
    @IBOutlet weak var activityIndicatorView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //enables user to return to this screen after exiting "Settings"
        UserDefaults.standard.set(title, forKey: "LastScreen")
        
        //after the login workflow is complete...
        //if the user did not log in, set the status of fetching info from the data store to complete
        let userID = UserDefaults.standard.string(forKey: "UserID")
        if userID == nil {
            UserDefaults.standard.set(true, forKey: "FirebaseFetched")
        }
        //if the user did log in and the database reference is not already configured, configure it
        else if dbr == nil {
            dbr = Database.database().reference().child(userID!)
        }
        
        //set all required UserDefaults values
        setDefaults()
        
        //fetch existing Transactions and Categories
        let dbFetched = UserDefaults.standard.bool(forKey: "FirebaseFetched")
        if dbFetched {
            //Categories don't need to be fetched as often as Transactions; only fetch them here if there are none already, which should only happen after the Login workflow or at Launch
            //if it's after a succesful login, this will be skipped in favor of "firebasePull(...)" because "dbFetched" will be false at this point
            if ctgs.count == 0 { fetchCtgs() }
            
            //if there are still no Categories after a fetch attempt, create default Categories
            if ctgs.count == 0 { setDefaultCtgs() }
            
            //Transactions are always fetched because they need to be sorted for "transactionsTable"
            //"asc:" is set to false mostly so that the most recent Transactions are at top
            fetchTxns(sortBy: "Date", asc: false)
        }
        //if the user just logged in, there will be no local transactions or categories and these should instead be pulled from the data store using "firebasePull(...)"
        else { firebasePull() }

        //configure swipe recognizers
        let swipeD = UISwipeGestureRecognizer(
            target: self, action: #selector(respondToSwipeGesture(_:)))
        let swipeU = UISwipeGestureRecognizer(
            target: self, action: #selector(respondToSwipeGesture(_:)))
        swipeD.direction = .down
        swipeU.direction = .up
        view.addGestureRecognizer(swipeD)
        view.addGestureRecognizer(swipeU)
        
        //configure text fields
        let ccy = UserDefaults.standard.string(forKey: "Currency") ?? "$"
        amountField.attributedPlaceholder = NSAttributedString(
            string: ccy + "0.00",
            attributes: [NSAttributedString.Key.foregroundColor: greyDark]
        )
        
        titleField.attributedPlaceholder = NSAttributedString(
            string: "Short description",
            attributes: [NSAttributedString.Key.foregroundColor: greyDark]
        )
        
        categoryField.attributedPlaceholder = NSAttributedString(
            string: "Select a Category",
            attributes: [NSAttributedString.Key.foregroundColor: greyDark]
        )
        categoryField.inputView = ctgPkr
        ctgPkr.delegate = self
        
        //create and assign date picker for "dateField"
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
        dateField.inputView = datePkr
        dateField.text = Date().toString()
        
        //create "Close" button for each UITextField and configure them to close when the user taps outside of the input view
        let btn = UIBarButtonItem(title: "Close", style: .plain, target: self,
                                  action: #selector(closeButtonAction))
        let toolbar = makeToolbar()
        toolbar.setItems([btn], animated: true)
        for field in [amountField, categoryField, dateField, titleField] {
            field?.delegate = self
            field?.inputAccessoryView = toolbar
            field?.tintColor = .white
        }
        
        //configure the appearance of "transactionsTable"
        transactionsTable.backgroundColor = greyDarkest
        transactionsTable.tintColor = .white
        transactionsTable.reloadData()
    }
    @objc func closeButtonAction() { view.endEditing(true) }
    @objc func dateChanged(datePkr: UIDatePicker) {
        dateField.text = datePkr.date.toString()
    }
    @objc func respondToSwipeGesture(_ gesture: UIGestureRecognizer)  {
        if let swipe = gesture as? UISwipeGestureRecognizer {
            if swipe.direction == .up {
                performSegue(withIdentifier: "EditTransactionsU", sender: nil)
            } else {
                fetchTxns(sortBy: "Date", asc: true)
                let id = UserDefaults.standard.string(forKey: "LastDashboard")
                performSegue(withIdentifier: (id ?? "Summary") + "D",
                             sender: nil)
            }
        }
    }
    
    //checking for missing categories must be done in "viewDidAppear(...)" because alerts cannot display in "viewDidLoad(...)"
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //check for missing categories only if the user has already synced with their data store post-login
        let dbFetched = UserDefaults.standard.bool(forKey: "FirebaseFetched")
        if dbFetched {  checkCtgMissing(self) }
    }
    
    //close open input views if touch occurs outside of input view or user hits "Return"
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
        super.touchesBegan(touches, with: event)
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return false
    }

    //immediately after login, pull existing Transactions and Categories from user's data store
    func firebasePull() {
        //disable inputs while data is loading
        activityIndicatorView.isHidden = false
        view.isUserInteractionEnabled = false
        
        //based on the structure of the data store, loop through all children of all Categories and, depending on which item in the Category object is being read ("i"), set that to a value ("val") as a specific data type to build Categories ("ctg") to add to "ctgs"
        dbr?.child("Categories").observeSingleEvent(of: .value, with: { snap in
            if snap.exists() {
                for obj in snap.children.allObjects as! [DataSnapshot] {
                    var i = 0
                    let ctg = Category(context: PersistenceService.context)
                    for obj in obj.children.allObjects as! [DataSnapshot] {
                        switch i {
                        case 0:
                            if let val = obj.value as? Double {
                                ctg.budget = val
                            }
                        case 1:
                            if let val = obj.value as? Double {
                                ctg.proportion = val
                            }
                        case 2: ctg.selected = false
                        case 3: ctg.sign = true
                        case 4:
                            if let val = obj.value as? String {
                                ctg.title = val
                            }
                        default: break
                        }
                        i += 1
                    }
                    ctgs.append(ctg)
                    let bdg = UserDefaults.standard.double(forKey: "Budget")
                    UserDefaults.standard.set(bdg + ctg.budget,
                                              forKey: "Budget")
                }
            }
            
            //once all Categories have finished being pulled, start pulling Transactions
            let key = dbr?.child("Transactions")
            key?.observeSingleEvent(of: .value, with: { snap in
                if snap.exists() {
                    for obj in snap.children.allObjects as! [DataSnapshot] {
                        var i = 0
                        let txn =
                            Transaction(context: PersistenceService.context)
                        for obj in obj.children.allObjects as! [DataSnapshot] {
                            switch i {
                            case 0:
                                if let val = obj.value as? Double {
                                    txn.amount = val
                                }
                            case 1:
                                if let val = obj.value as? String {
                                    txn.category = val
                                }
                            case 2:
                                if let val = obj.value as? String {
                                    txn.date = val.toDate()
                                }
                            case 3:
                                if let val = obj.value as? Int {
                                    txn.index = Int32(val)
                                }
                            case 4: txn.selected = false
                            case 5:
                                if let val = obj.value as? Bool {
                                    txn.sign = val
                                }
                            case 6:
                                if let val = obj.value as? String {
                                    txn.title = val
                                }
                            default: break
                            }
                            i += 1
                        }
                        txns.append(txn)
                    }
                }
                
                //fetch Transactions in order to sort them properly and check to make sure no Categories are missing
                fetchCtgs()
                if ctgs.count == 0 { setDefaultCtgs() }
                fetchTxns(sortBy: "Date", asc: false)
                checkCtgMissing(self)
                self.transactionsTable.reloadData()
                
                //mark "FirebaseFetched" as true once all pulls have completed and return control to the user
                UserDefaults.standard.set(true, forKey: "FirebaseFetched")
                self.activityIndicatorView.isHidden = true
                self.view.isUserInteractionEnabled = true
            })
        })
    }
    
    //handle when user taps "addToLedgerButton"
    @IBAction func tapAddTransaction(_ sender: DesignableButton) {
        //close all open input views
        view.endEditing(true)
        
        //if "titleField" is blank, auto-populate it; this field is not required
        if titleField.text == "" { titleField.text = "(no description)" }
        
        //if a required field is empty, highlight it red
        let amt = amountField.text ?? ""
        let ctg = categoryField.text ?? ""
        if amt == "" || ctg == "" {
            amountField.backgroundColor   = amt == "" ? red : greyDarkest
            categoryField.backgroundColor = ctg == "" ? red : greyDarkest
        }
        //if no required fields are empty, add the supplied details as a Transaction to "txns"
        else {
            let txn = Transaction(context: PersistenceService.context)
            
            //the formatting elements of "amountField" must be removed before it can be formatted as a and saved as a Double
            let amtStr = String(amt.suffix(amt.count - 1))
            let amtVal = Double(amtStr.replacingOccurrences(
                of: ",", with: "", options: .literal, range: nil))
            txn.amount = (revenue ? 1 : -1) * (amtVal ?? 0)
            txn.sign = revenue
            
            //index should be one higher than the highest already in "txns"
            let maxIndex = txns.max(by: { $0.index < $1.index })?.index ?? 0
            txn.index = Int32(1) + maxIndex
            
            txn.category = categoryField.text ?? ctgs.first?.title ?? ""
            txn.date = (dateField.text ?? Date().toString()).toDate()
            txn.title = titleField.text ?? "(no description)"
            txn.selected = false
            
            //once all elements of "txn" are populated, put it at the start of "txns" even if it's not chronologically appropriate so that it appears at the top of "transactionsTable" and provides feedback to the user
            txns.insert(txn, at: 0)
            PersistenceService.saveContext()
            transactionsTable.reloadData()
            
            //save the details of "txn" to a Hashable to updated the user's data store and update the store's counters
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
            firebasePushTxns()
            
            //reset the text fields and unhighlight "addToLedgerButton"
            amountField.backgroundColor = greyDarkest
            categoryField.backgroundColor = greyDarkest
            amountField.text = ""
            categoryField.text = ""
            titleField.text = ""
            highlightAddButton()
        }
    }

    //highlight "addToLedgerButton" "teal" if required fields have been completed
    func highlightAddButton() {
        if amountField.text == "" || categoryField.text == "" {
            addToLedgerButton.backgroundColor = greyDark
            addToLedgerButton.borderColor = greyDarker
            entriesOutlineView.borderColor = greyDarker
        } else {
            addToLedgerButton.backgroundColor = teal
            addToLedgerButton.borderColor = teal
            entriesOutlineView.borderColor = teal
        }
    }
    
    //change which button is highlighted, "expenseButton" or "revenueButton"
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
    
    //format inputs as currency and check if "addToLedgerButton" can be highlighted
    @IBAction func editMoneyField(_ sender: DesignableTextField) {
        sender.backgroundColor = greyDarkest
        sender.text = sender.text?.currencyFormat()
        highlightAddButton()
    }
    
    //remove the placeholder text that is auto-populated if a user tries to add a transaction without "titleField" populated
    @IBAction func editTitleField(_ sender: DesignableTextField) {
        if sender.text == "(no description)" { sender.text = "" }
    }
    
    //fetch categories sorted by date for use in "Dashboards" and segue to the last "Dashboard" visited by the user
    @IBAction func tapDashboards(_ sender: UIButton) {
        fetchTxns(sortBy: "Date", asc: true)
        let dsh = UserDefaults.standard.string(forKey: "LastDashboard")
        performSegue(withIdentifier: (dsh ?? "Summary") + "D", sender: nil)
    }
}

//mostly just formatting for "transactionsTable"
extension VCNewTransaction: UITableViewDataSource, UITableViewDelegate {
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

    //enable users to swipe left on a cell to delete the association Transaction
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

//mostly just formatting for "categoryField"'s input picker view
extension VCNewTransaction: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { return 1 }
    
    //when the user taps "categoryField", set the default value of "categoryField" to the first Category available in the picker view, check to see if "addToLedgerButton" can be highlighted, and remove the red background from "categoryField" that may exist if the user tapped "addToLedgerButton" before completing "categoryField"
    func pickerView(_ pickerView: UIPickerView,
                    numberOfRowsInComponent component: Int) -> Int
    {
        pickerView.backgroundColor = greyDarkest
        categoryField.backgroundColor = greyDarkest
        if categoryField.text == "" { categoryField.text = ctgs.first?.title }
        highlightAddButton()
        return ctgs.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int,
                    forComponent component: Int) -> String?
        { return ctgs[row].title }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int,
                    inComponent component: Int)
        { categoryField.text = ctgs[row].title }

    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int,
        forComponent component: Int, reusing view: UIView?) -> UIView
    {
        let label = UILabel()
        label.backgroundColor = greyDarkest
        label.font = UIFont(name: "Menlo", size: 25)
        label.textAlignment = .center
        label.textColor = .white
        label.text = ctgs[row].title
        return label
    }
}
////////10////////20////////30////////40////////50////////60////////70////////80
