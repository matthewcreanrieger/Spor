//WORK IN PROGRESS
import UIKit
import CoreData
import Firebase

class VCEditTransactions: UIViewController, UITextFieldDelegate {
    var attributesTransaction = ["Amount", "Category", "Date", "Description", "Transaction #"]
    let changeFromTransactionsPicker = UIPickerView()
    let sortPicker = UIPickerView()
    @IBOutlet weak var sortField: DesignableTextField!
    
    var datePicker = UIDatePicker()
    var lastCategoryPicked = 0
    @IBOutlet weak var expenseButton: DesignableButton!
    @IBOutlet weak var revenueButton: DesignableButton!
    @IBOutlet weak var transactionsTable: UITableView!
    
    
    let changeToPicker = UIPickerView()
    @IBOutlet weak var changeButton: DesignableButton!
    @IBOutlet weak var changeFromField: DesignableTextField!
    @IBOutlet weak var changeToField: DesignableTextField!
    @IBOutlet weak var deleteButton: DesignableButton!
    
    var positive = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UserDefaults.standard.set(title, forKey: "LastScreen")
        lastCategoryPicked = 0
        
        fetchTransactions(sortBy: "Transaction #", ascending: true)
        fetchCategories()
        
        let swipeD = UISwipeGestureRecognizer(target: self, action: #selector(respondToSwipeGesture(_:)))
        swipeD.direction = .down
        view.addGestureRecognizer(swipeD)
        
        changeFromField.inputView = changeFromTransactionsPicker
        changeFromField.text = "Category"
        changeFromTransactionsPicker.delegate = self
        for i in 0...(attributesTransaction.count-2) {
            if changeFromField.text == attributesTransaction[i] {
                changeFromTransactionsPicker.selectRow(i, inComponent: 0, animated: false)
                break
            }
        }
        
        changeToField.autocapitalizationType = .sentences
        changeToField.inputView = changeToPicker
        changeToPicker.delegate = self
        
        sortField.inputView = sortPicker
        sortField.text = "Transaction #"
        sortPicker.delegate = self
        for i in 0..<attributesTransaction.count {
            if sortField.text == attributesTransaction[i] {
                sortPicker.selectRow(i, inComponent: 0, animated: false)
                break
            }
        }
        refreshTransactionsTable()
        createToolbars([sortField, changeFromField, changeToField])
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
        super.touchesBegan(touches, with: event)
    }
    
    @objc func respondToSwipeGesture(_ gesture: UIGestureRecognizer)  {
        performSegue(withIdentifier: "NewTransactionD", sender: nil)
    }
    
    func createDatePicker() {
        datePicker = UIDatePicker()
        datePicker.addTarget(self, action: #selector(dateChanged(datePicker:)), for: .valueChanged)
        datePicker.backgroundColor = greyDarkest
        datePicker.datePickerMode = .date
        var dateComponents = DateComponents()
        dateComponents.year = -1
        datePicker.minimumDate = min(Calendar.current.date(byAdding: dateComponents, to: Date())!, (UserDefaults.standard.string(forKey: "StartDate")?.toDate() ?? Date()))
        datePicker.setValue(UIColor.white, forKey: "textColor")
    }
    @objc func dateChanged(datePicker: UIDatePicker) {
        changeToField.text = datePicker.date.toString()
        highlightChangeAndDeleteButtons()
    }
    
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
    
    func refreshTransactionsTable() {
        transactionsTable.backgroundColor = greyDarkest
        transactionsTable.tintColor = .white
        transactionsTable.reloadData()
        highlightChangeAndDeleteButtons()
    }
    
    func highlightChangeAndDeleteButtons() {
        changeToField.backgroundColor = greyDarkest
        if !transactions.contains{ $0.selected } {
            deleteButton.backgroundColor = greyDark
            deleteButton.setTitleColor(greyDarker, for: .normal)
            deleteButton.isEnabled = false
            changeButton.backgroundColor = greyDark
        } else {
            deleteButton.backgroundColor = red
            deleteButton.setTitleColor(greyDarkest, for: .normal)
            deleteButton.isEnabled = true
            if changeToField.text == "" { changeButton.backgroundColor = greyDark }
            else { changeButton.backgroundColor = teal }
        }
        globalTable = transactionsTable
        globalDeleteButton = deleteButton
        globalChangeButton = changeButton
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return false
    }
    
    @IBAction func editChangeToField(_ sender: DesignableTextField) {
        if changeFromField.text == "Amount" { sender.text = sender.text?.currencyFormat() }
        highlightChangeAndDeleteButtons()
    }
    
    @IBAction func tapChangeTransactions(_ sender: DesignableButton) {
        view.endEditing(true)
        if changeToField.text == "" { changeToField.backgroundColor = red }
        else {
            for transaction in transactions {
                if transaction.selected {
                    switch changeFromField.text {
                    case "Amount":
                        transaction.amount = (positive ? 1 : -1) * Double(String(changeToField.text!.suffix(changeToField.text!.count - 1)).replacingOccurrences(of: ",", with: "", options: String.CompareOptions.literal, range: nil))!
                        transaction.sign = positive
                    case "Category":
                        transaction.category = changeToField.text!
                    case "Date":
                        transaction.date = changeToField.text!.toDate()
                        if (UserDefaults.standard.string(forKey: "StartDate") ?? Date().toString()).toDate() > transaction.date { UserDefaults.standard.set(transaction.date.toString(), forKey: "StartDate") }
                    case "Description":
                        transaction.title = changeToField.text!
                    default:
                        break
                    }
                    transaction.selected = false
                    let updates: [AnyHashable: Any] = [
                        "Amount":   transaction.amount,
                        "Category": transaction.category,
                        "Date":     transaction.date.toString(),
                        "Index":    transaction.index,
                        "Selected": transaction.selected,
                        "Sign":     transaction.sign,
                        "Title":    transaction.title
                    ]
                    if firebaseReference != nil { firebaseReference!.child("Transactions").child(String(format: "Transaction%06d", transaction.index)).updateChildValues(updates) }
                }
            }
            PersistenceService.saveContext()
            fetchTransactions(sortBy: sortField.text!, ascending: globalAscending)
            refreshTransactionsTable()
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
        if categoryMissing {
            checkForMissingCategories(self)
        }
        else { performSegue(withIdentifier: (UserDefaults.standard.string(forKey: "LastDashboard") ?? "Summary") + "D", sender: nil) }
    }
    
    @IBAction func tapDeleteTransactions(_ sender: DesignableButton) {
        changeToField.backgroundColor = greyDarkest
        (transactions.reduce(0) { $0 + ($1.selected ? 1 : 0) }) > 1 ? deleteTransactionsConfirm(self, "") : deleteTransactions(self)
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
    
    @IBAction func tapReverse(_ sender: DesignableButton) {
        fetchTransactions(sortBy: sortField.text ?? "Transaction #", ascending: !globalAscending)
        refreshTransactionsTable()
    }
}

extension VCEditTransactions: UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate {
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
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) { createCheckmarks() }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.reloadData()
        transactions[indexPath.row].selected = !transactions[indexPath.row].selected
        highlightChangeAndDeleteButtons()
        createCheckmarks()
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        tableView.reloadData()
        transactions[indexPath.row].selected = !transactions[indexPath.row].selected
        highlightChangeAndDeleteButtons()
        createCheckmarks()
    }
    
    func createCheckmarks() {
        for i in 0..<transactions.count {
            if transactions[i].selected {
                if let cell = transactionsTable.cellForRow(at: IndexPath(row: i, section: 0)) {
                    cell.contentView.superview!.backgroundColor = greyDarker
                    cell.accessoryType = .checkmark
                    cell.selectionStyle = .none
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if firebaseReference != nil { firebaseReference!.child("Transactions").child(String(format: "Transaction%06d", transactions[indexPath.row].index)).removeValue() }
            PersistenceService.context.delete(transactions[indexPath.row])
            transactions.remove(at: indexPath.row)
            PersistenceService.saveContext()
            tableView.beginUpdates()
            tableView.deleteRows(at: [indexPath], with: .automatic)
            tableView.endUpdates()
            if firebaseReference != nil { firebaseUpdateCounters() }
            highlightChangeAndDeleteButtons()
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

extension VCEditTransactions: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { return 1 }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        pickerView.backgroundColor = greyDarkest
        switch pickerView {
        case changeToPicker:
            if changeToField.text == "" { changeToField.text = categories[lastCategoryPicked].title }
            highlightChangeAndDeleteButtons()
            return categories.count
        case changeFromTransactionsPicker: return attributesTransaction.count - 1
        case sortPicker:                   return attributesTransaction.count
        default:                           return 0
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch pickerView {
        case changeFromTransactionsPicker: return attributesTransaction[row]
        case changeToPicker:               return categories[row].title
        case sortPicker:                   return attributesTransaction[row]
        default:                           return ""
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch pickerView {
        case changeFromTransactionsPicker:
            changeFromField.text = attributesTransaction[row]
            changeToField.text = ""
            revenueButton.isHidden = true
            expenseButton.isHidden = true
            changeToField.inputView = nil
            switch changeFromField.text {
            case "Amount":
                changeToField.keyboardType = UIKeyboardType.numberPad
                changeToField.keyboardAppearance = UIKeyboardAppearance.dark
                revenueButton.isHidden = false
                expenseButton.isHidden = false
            case "Category":
                changeToField.inputView = changeToPicker
                changeToField.text = categories[lastCategoryPicked].title
            case "Date":
                createDatePicker()
                changeToField.inputView = datePicker
                changeToField.text = Date().toString()
            case "Description":
                changeToField.keyboardType = UIKeyboardType.default
                changeToField.keyboardAppearance = UIKeyboardAppearance.dark
            default:
                break
            }
            highlightChangeAndDeleteButtons()
        case changeToPicker:
            changeToField.text = categories[row].title
            lastCategoryPicked = row
            highlightChangeAndDeleteButtons()
        case sortPicker:
            sortField.text = attributesTransaction[row]
            fetchTransactions(sortBy: attributesTransaction[row], ascending: false)
            refreshTransactionsTable()
        default:
            break
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = UILabel()
        label.backgroundColor = greyDarkest
        label.font = UIFont(name: "Menlo", size: 25)
        label.textAlignment = .center
        label.textColor = .white
        switch pickerView {
        case changeFromTransactionsPicker: label.text = attributesTransaction[row]
        case changeToPicker:               label.text = categories[row].title
        case sortPicker:                   label.text = attributesTransaction[row]
        default:                           label.text = ""
        }
        return label
    }
}
