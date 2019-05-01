//WORK IN PROGRESS
import UIKit
import CoreData
import Firebase

class VCNewTransaction: UIViewController, UITextFieldDelegate {
    
    let categoryPicker = UIPickerView()
    var swipeU = UISwipeGestureRecognizer(target: self, action: nil)
    @IBOutlet weak var activityIndicatorView: UIView!
    @IBOutlet weak var addToLedgerButton: DesignableButton!
    @IBOutlet weak var amountField: DesignableTextField!
    @IBOutlet weak var categoryField: DesignableTextField!
    @IBOutlet weak var dateField: DesignableTextField!
    @IBOutlet weak var titleField: DesignableTextField!
    @IBOutlet weak var entriesOutlineView: DesignableView!
    
    var datePicker = UIDatePicker()
    var lastCategoryPicked = 0
    var swipeD = UISwipeGestureRecognizer(target: self, action: nil)
    @IBOutlet weak var expenseButton: DesignableButton!
    @IBOutlet weak var revenueButton: DesignableButton!
    @IBOutlet weak var transactionsTable: UITableView!

    var positive = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UserDefaults.standard.set(title, forKey: "LastScreen")
        
        lastCategoryPicked = 0
        if UserDefaults.standard.string(forKey: "UserID") == nil { UserDefaults.standard.set(true, forKey: "FirebaseFetched") }
        else if firebaseReference == nil { firebaseReference = Database.database().reference().child(UserDefaults.standard.string(forKey: "UserID")!) }
        createDefaults()
        createDatePicker()
        fetchTransactions(sortBy: "Date", ascending: false)
        fetchCategories()
        
        swipeD = UISwipeGestureRecognizer(target: self, action: #selector(respondToSwipeGesture(_:)))
        swipeU = UISwipeGestureRecognizer(target: self, action: #selector(respondToSwipeGesture(_:)))
        swipeD.direction = .down
        swipeU.direction = .up
        view.addGestureRecognizer(swipeD)
        view.addGestureRecognizer(swipeU)
        
        if firebaseReference != nil {
            UserDefaults.standard.bool(forKey: "FirebaseFetched") ? firebasePush() : firebasePull()
        }
        
        amountField.attributedPlaceholder = NSAttributedString(string: UserDefaults.standard.string(forKey: "Currency")! + "0.00", attributes: [NSAttributedString.Key.foregroundColor: greyDark])
        amountField.font = UIFont(name: "Menlo", size: 20)
        
        categoryField.attributedPlaceholder = NSAttributedString(string: "Select a Category", attributes: [NSAttributedString.Key.foregroundColor: greyDark])
        categoryField.font = UIFont(name: "Menlo", size: 20)
        categoryField.inputView = categoryPicker
        categoryPicker.delegate = self
        
        dateField.inputView = datePicker
        dateField.text = Date().toString()
        
        titleField.attributedPlaceholder = NSAttributedString(string: "Short description", attributes: [NSAttributedString.Key.foregroundColor: greyDark])
        titleField.autocapitalizationType = .sentences
        titleField.font = UIFont(name: "Menlo", size: 20)
        titleField.layer.borderWidth = 0
        titleField.textColor = .white
        
        createToolbars([amountField, categoryField, dateField, titleField])
        refreshTransactionsTable()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        screenHeight = Double(view.frame.height)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300), execute: {
            checkForMissingCategories(self)
        })
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
        super.touchesBegan(touches, with: event)
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return false
    }
    
    @objc func respondToSwipeGesture(_ gesture: UIGestureRecognizer)  {
        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            performSegue(withIdentifier: swipeGesture.direction == .up ? "EditTransactionsU" : (UserDefaults.standard.string(forKey: "LastDashboard") ?? "Summary") + "D", sender: nil)
        }
    }
    
    func createDatePicker() {
        datePicker.addTarget(self, action: #selector(dateChanged(datePicker:)), for: .valueChanged)
        datePicker.backgroundColor = greyDarkest
        datePicker.datePickerMode = .date
        var dateComponents = DateComponents()
        dateComponents.year = -1
        datePicker.minimumDate = min(Calendar.current.date(byAdding: dateComponents, to: Date())!, (UserDefaults.standard.string(forKey: "StartDate")?.toDate() ?? Date()))
        datePicker.setValue(UIColor.white, forKey: "textColor")
        
    }
    @objc func dateChanged(datePicker: UIDatePicker) { dateField.text = datePicker.date.toString() }
    
    func createToolbars(_ fields: [DesignableTextField]) {
        let toolbar: UIToolbar = UIToolbar(frame: CGRect.init(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 0))
        let closeButton: UIBarButtonItem = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(closeButtonAction))
        toolbar.barStyle = .default
        toolbar.barTintColor = greyDarkest
        toolbar.setItems([closeButton], animated: true)
        toolbar.sizeToFit()
        toolbar.tintColor = .white
        for field in fields {
            field.delegate = self
            field.inputAccessoryView = toolbar
            field.tintColor = .white
        }
    }
    @objc func closeButtonAction() { view.endEditing(true) }
    
    func firebasePull() {
        activityIndicatorView.isHidden = false
        view.isUserInteractionEnabled = false
        firebaseReference!.child("Categories").observeSingleEvent(of: .value, with: { snapshot in
            var empty = true
            if snapshot.exists() {
                for obj in snapshot.children.allObjects as! [DataSnapshot] {
                    var i = 0
                    let category = Category(context: PersistenceService.context)
                    for data in obj.children.allObjects as! [DataSnapshot] {
                        switch i {
                        case 0: if let val = data.value as? Double { category.budget     = val }
                        case 1: if let val = data.value as? Double { category.proportion = val }
                        case 2:                                      category.selected   = false
                        case 3: if let val = data.value as? Bool   { category.sign       = val }
                        case 4: if let val = data.value as? String { category.title      = val }
                        default: break
                        }
                        i += 1
                    }
                    empty = false
                    categories.append(category)
                    PersistenceService.saveContext()
                    UserDefaults.standard.set(UserDefaults.standard.double(forKey: "Budget") + category.budget, forKey: "Budget")
                }
            }
            if empty { createDefaultCategories() }
            firebaseReference!.child("Transactions").observeSingleEvent(of: .value, with: { snapshot in
                if snapshot.exists() {
                    for obj in snapshot.children.allObjects as! [DataSnapshot] {
                        var i = 0
                        let transaction = Transaction(context: PersistenceService.context)
                        for data in obj.children.allObjects as! [DataSnapshot] {
                            switch i {
                            case 0: if let val = data.value as? Double { transaction.amount   = val          }
                            case 1: if let val = data.value as? String { transaction.category = val          }
                            case 2: if let val = data.value as? String { transaction.date     = val.toDate() }
                            case 3: if let val = data.value as? Int    { transaction.index    = Int32(val)   }
                            case 4:                                      transaction.selected = false
                            case 5: if let val = data.value as? Bool   { transaction.sign     = val          }
                            case 6: if let val = data.value as? String { transaction.title    = val          }
                            default: break
                            }
                            i += 1
                        }
                        transactions.append(transaction)
                    }
                    PersistenceService.saveContext()
                }
                UserDefaults.standard.set(true, forKey: "FirebaseFetched")
                fetchTransactions(sortBy: "Date", ascending: false)
                self.refreshTransactionsTable()
                self.activityIndicatorView.isHidden = true
                self.view.isUserInteractionEnabled = true
                checkForMissingCategories(self)
            })
        })
    }
    
    func refreshTransactionsTable() {
        transactionsTable.backgroundColor = greyDarkest
        transactionsTable.tintColor = .white
        transactionsTable.reloadData()
    }
    
    func highlightAddButton(_ color: UIColor) {
        addToLedgerButton.backgroundColor = color == greyDarker ? greyDark : color
        addToLedgerButton.borderColor = color
        entriesOutlineView.borderColor = color
    }
    
    @IBAction func editTitleField(_ sender: DesignableTextField) {
        sender.attributedPlaceholder = NSAttributedString(string: "")
        titleField.attributedPlaceholder = NSAttributedString(string: "Short description", attributes: [NSAttributedString.Key.foregroundColor: greyDark])
        sender.font = UIFont(name: "Menlo", size: 20)
        if sender.text == "(no description)" { sender.text = "" }
    }
    
    //not sure if i need this
    @IBAction func endEditTitleField(_ sender: DesignableTextField) {
        //        if sender.text == "" {
        //            titleField.attributedPlaceholder = NSAttributedString(string: "Short description", attributes: [NSAttributedString.Key.foregroundColor: greyDark])
        //            titleField.font = UIFont(name: "Menlo", size: 20)
        //        }
    }
    
    @IBAction func editMoneyField(_ sender: DesignableTextField) {
        sender.backgroundColor = greyDarkest
        sender.text = sender.text?.currencyFormat()
        sender.font = UIFont(name: "Menlo", size: 20)
        highlightAddButton((sender.text != "" && categoryField.text != "") ? teal : greyDarker)
    }
    
    @IBAction func tapAddTransaction(_ sender: DesignableButton) {
        view.endEditing(true)
        if titleField.text == "" { titleField.text = "(no description)" }
        if amountField.text == "" || categoryField.text == "" {
            amountField.backgroundColor =   amountField.text ==   "" ? red : greyDarkest
            categoryField.backgroundColor = categoryField.text == "" ? red : greyDarkest
        } else {
            UserDefaults.standard.set(1 + (UserDefaults.standard.object(forKey: "TransactionIndex") != nil ? Int(UserDefaults.standard.integer(forKey: "TransactionIndex")) : Int(transactions.max(by: { $0.index < $1.index })?.index ?? 0)), forKey: "TransactionIndex")
            let transaction = Transaction(context: PersistenceService.context)
            transaction.amount = (positive ? 1 : -1) * Double(String(amountField.text!.suffix(amountField.text!.count - 1)).replacingOccurrences(of: ",", with: "", options: String.CompareOptions.literal, range: nil))!
            transaction.category = categoryField.text!
            transaction.date = dateField.text!.toDate()
            transaction.index = Int32(UserDefaults.standard.integer(forKey: "TransactionIndex"))
            transaction.selected = false
            transaction.sign = positive
            transaction.title = titleField.text ?? "(no description)"
            transactions.insert(transaction, at: 0)
            if (UserDefaults.standard.string(forKey: "StartDate") ?? Date().toString()).toDate() > transaction.date { UserDefaults.standard.set(transaction.date.toString(), forKey: "StartDate") }
            PersistenceService.saveContext()
            transactionsTable.reloadData()
            let updates: [AnyHashable: Any] = [
                "Amount":   transaction.amount,
                "Category": transaction.category,
                "Date":     transaction.date.toString(),
                "Index":    transaction.index,
                "Selected": transaction.selected,
                "Sign":     transaction.sign,
                "Title":    transaction.title
            ]
            if firebaseReference != nil {
                firebaseReference!.child("Transactions").child(String(format: "Transaction%06d", transaction.index)).updateChildValues(updates)
                firebaseUpdateCounters()
            }
            
            amountField.backgroundColor = greyDarkest
            amountField.text = ""
            categoryField.backgroundColor = greyDarkest
            categoryField.text = ""
            titleField.text = ""
            highlightAddButton(greyDarker)
        }
    }
    
    @IBAction func tapDashboards(_ sender: UIButton) {
        var categoryMissing = false
        for transaction in transactions {
            if categories.first(where: { $0.title == transaction.category } ) == nil {
                categoryMissing = true
                break
            }
        }
        if categoryMissing { checkForMissingCategories(self) }
        else { performSegue(withIdentifier: (UserDefaults.standard.string(forKey: "LastDashboard") ?? "Summary") + "D", sender: nil) }
    }
    
    @IBAction func tapSign(_ sender: DesignableButton) {
        switch positive {
        case true:
            positive = false
            expenseButton.borderColor = red
            expenseButton.setTitleColor(.white, for: .normal)
            revenueButton.borderColor = greyLighter
            revenueButton.setTitleColor(greyLighter, for: .normal)
        case false:
            positive = true
            expenseButton.borderColor = greyLighter
            expenseButton.setTitleColor(greyLighter, for: .normal)
            revenueButton.borderColor = teal
            revenueButton.setTitleColor(.white, for: .normal)
        }
    }
}

extension VCNewTransaction: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return transactions.count }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = .clear
        cell.textLabel?.textColor = .white
        cell.textLabel?.font = UIFont(name: "Metropolis-ExtraBold", size: 17)
        cell.detailTextLabel?.textColor = offWhite
        cell.detailTextLabel?.font = UIFont(name: "Metropolis-Regular", size: 14)
        cell.textLabel?.text = (transactions[indexPath.row].sign ? "+" : "-") + String(format:"%.02f", abs(transactions[indexPath.row].amount)).currencyFormat() + " for " + String(transactions[indexPath.row].category)
        cell.detailTextLabel?.text = "#" + String(transactions[indexPath.row].index) + ": " + transactions[indexPath.row].title + " on " + transactions[indexPath.row].date.toString()
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            firebaseReference?.child("Transactions").child(String(format: "Transaction%06d", transactions[indexPath.row].index)).removeValue()
            PersistenceService.context.delete(transactions[indexPath.row])
            transactions.remove(at: indexPath.row)
            PersistenceService.saveContext()
            tableView.beginUpdates()
            tableView.deleteRows(at: [indexPath], with: .automatic)
            tableView.endUpdates()
            if firebaseReference != nil { firebaseUpdateCounters() }
        }
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteButton = UITableViewRowAction(style: .default, title: "Delete") { (action, indexPath) in
            tableView.dataSource?.tableView!(tableView, commit: .delete, forRowAt: indexPath)
            return
        }
        deleteButton.backgroundColor = red
        return [deleteButton]
    }
}

extension VCNewTransaction: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { return 1 }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        pickerView.backgroundColor = greyDarkest
        categoryField.backgroundColor = greyDarkest
        categoryField.font = UIFont(name: "Menlo", size: 20)
        if categoryField.text == "" { categoryField.text = categories[lastCategoryPicked].title }
        if amountField.text != "" { highlightAddButton(teal) }
        return categories.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? { return categories[row].title }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        categoryField.text = categories[row].title
        lastCategoryPicked = row
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = UILabel()
        label.backgroundColor = greyDarkest
        label.font = UIFont(name: "Menlo", size: 25)
        label.textAlignment = .center
        label.textColor = .white
        label.text = categories[row].title
        return label
    }
}
