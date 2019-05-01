//WORK IN PROGRESS
import UIKit
import CoreData
import Firebase

class VCSettings: UIViewController, UITextFieldDelegate {
    var attributesCategory = ["Amount", "Title"]
    var currencies = ["$", "€", "¥", "£", "₫", "฿", "₽", "₹", "₠", "₿", "¤", "₵", "₡", "₳", "₢", "৳", "₯", "₣", "₲", "₴", "₭", "₥", "₦", "₧", "₱", "₰", "₨", "₪", "₮", "₩"]
    var periods = ["Weekly", "Biweekly", "Monthly", "Yearly"]
    let changeFromCategoriesPicker = UIPickerView()
    let currencyPicker = UIPickerView()
    let periodPicker = UIPickerView()
    @IBOutlet weak var authenticationLabel: UILabel!
    @IBOutlet weak var budgetField: DesignableTextField!
    @IBOutlet weak var budgetLabel: UILabel!
    @IBOutlet weak var categoriesTable: UITableView!
    @IBOutlet weak var currencyField: DesignableTextField!
    @IBOutlet weak var loginButton: DesignableButton!
    @IBOutlet weak var periodField: DesignableTextField!
    @IBOutlet weak var signOutButton: DesignableButton!
    @IBOutlet weak var usernameLabel: UILabel!
    
    @IBOutlet weak var changeButton: DesignableButton!
    @IBOutlet weak var changeFromField: DesignableTextField!
    @IBOutlet weak var changeToField: DesignableTextField!
    @IBOutlet weak var deleteButton: DesignableButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        fetchTransactions(sortBy: "Date", ascending: true)
        fetchCategories()
        
        if UserDefaults.standard.string(forKey: "Username") == nil {
            authenticationLabel.isHidden = true
            signOutButton.isHidden = true
            usernameLabel.isHidden = true
            loginButton.isHidden = false
        } else { usernameLabel.text = UserDefaults.standard.string(forKey: "Username") }
        
        budgetField.layer.borderWidth = 2.0
        budgetField.attributedPlaceholder = NSAttributedString(string: UserDefaults.standard.string(forKey: "Currency")! + "0.00", attributes: [NSAttributedString.Key.foregroundColor: greyDark])
        budgetLabel.text = UserDefaults.standard.string(forKey: "Period")!.uppercased() + " BUDGET"
        
        changeFromCategoriesPicker.delegate = self
        changeFromField.inputView = changeFromCategoriesPicker
        changeFromField.text = attributesCategory[0]
        changeFromCategoriesPicker.selectRow(0, inComponent: 0, animated: false)
        
        currencyField.inputView = currencyPicker
        currencyField.text = UserDefaults.standard.string(forKey: "Currency")
        currencyPicker.delegate = self
        for i in 0..<currencies.count {
            if currencyField.text == currencies[i] {
                currencyPicker.selectRow(i, inComponent: 0, animated: false)
                break
            }
        }
        
        periodField.inputView = periodPicker
        periodField.text = UserDefaults.standard.string(forKey: "Period")
        periodPicker.delegate = self
        for i in 0..<periods.count {
            if periodField.text == periods[i] {
                periodPicker.selectRow(i, inComponent: 0, animated: false)
                break
            }
        }
        refreshCategoriesTable()
        createToolbars([budgetField, currencyField, periodField, changeFromField, changeToField])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkForMissingCategories(self)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
        super.touchesBegan(touches, with: event)
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
    
    func deleteCategories() {
        for category in categories.reversed() {
            if category.selected {
                UserDefaults.standard.set(categories.count == 1 ? 0.0 : UserDefaults.standard.double(forKey: "Budget") - category.budget, forKey: "Budget")
                PersistenceService.context.delete(category)
            }
        }
        fetchCategories()
        refreshCategoriesTable()
        checkForMissingCategories(self)
    }
    func deleteCategoriesConfirm() {
        var categoryCount = 0
        var transactionCount = 0
        for category in categories {
            if category.selected {
                categoryCount += 1
                for transaction in transactions { if transaction.category == category.title { transactionCount += 1 } }
            }
        }
        if transactionCount > 0 && categoryCount > 1 {
            let alert = UIAlertController(title: "Are You Sure You Want To Delete All " + String(categoryCount) + " Selected Categories?", message: String(transactionCount) + (transactionCount > 1 ? " Transactions" : " Transaction") + " associated with these categories will need to be deleted or recategorized.", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Delete Categories", style: .destructive, handler: { action in self.deleteCategories() }))
            alert.addAction(UIAlertAction(title: "Cancel",            style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }
        else { deleteCategories() }
    }
    
    func refreshCategoriesTable() {
        budgetField.text = String(format:"%.02f", UserDefaults.standard.double(forKey: "Budget")).currencyFormat()
        categoriesTable.backgroundColor = greyDarkest
        categoriesTable.tintColor = .white
        categoriesTable.reloadData()
        highlightChangeAndDeleteButtons()
    }
    
    func highlightChangeAndDeleteButtons() {
        if !categories.contains{ $0.selected } {
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
        globalTable = categoriesTable
        globalDeleteButton = deleteButton
        globalChangeButton = changeButton
        globalBudgetField = budgetField
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return false
    }
    
    @IBAction func editChangeToField(_ sender: DesignableTextField) {
        sender.backgroundColor = greyDarkest
        if changeFromField.text == "Amount" { sender.text = sender.text?.currencyFormat() }
        highlightChangeAndDeleteButtons()
    }
    
    @IBAction func editMoneyField(_ sender: DesignableTextField) {
        if sender.text != "" {
            sender.text = sender.text?.currencyFormat()
            let value = Double(String(sender.text!.suffix(sender.text!.count - 1)).replacingOccurrences(of: ",", with: "", options: String.CompareOptions.literal, range: nil))!
            UserDefaults.standard.set(value, forKey: "Budget")
            for category in categories { category.budget = category.proportion * value }
            fetchCategories()
            refreshCategoriesTable()
        }
    }
    
    @IBAction func tapAddCategory(_ sender: UIButton) {
        if categories.count < 20 {
            var num = categories.count + 1
            var title = "Category #" + String(num)
            var existingTitle = true
            while existingTitle == true {
                existingTitle = false
                for category in categories.reversed() {
                    if category.title == title {
                        num -= 1
                        title = "Category #" + String(num)
                        existingTitle = true
                        break
                    }
                }
            }
            addCategories(
                [categories.count > 0 ? UserDefaults.standard.double(forKey: "Budget") / Double(categories.count) : 100.0],
                [1.0 / Double(categories.count + 1)],
                [false],
                [true],
                [title]
            )
        } else {
            let alert = UIAlertController(title: "Too Many Categories", message: "Only 20 categories are allowed. You can swipe left on specific categories to delete them.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Roger, Roger", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
    
    @IBAction func tapChangeCategories(_ sender: DesignableButton) {
        view.endEditing(true)
        if changeToField.text == "" { changeToField.backgroundColor = red }
        else {
            for category in categories {
                if category.selected {
                    switch changeFromField.text {
                    case "Amount":
                        var input = Double(String(changeToField.text!.suffix(changeToField.text!.count - 1)).replacingOccurrences(of: ",", with: "", options: String.CompareOptions.literal, range: nil))!
                        let projectedValue = UserDefaults.standard.double(forKey: "Budget") - category.budget + input
                        if projectedValue > 999999.99 { input = input - projectedValue + 999999.99 }
                        UserDefaults.standard.set(UserDefaults.standard.double(forKey: "Budget") - category.budget + input, forKey: "Budget")
                        category.budget = input
                        category.sign = true
                    case "Title":
                        var newTitle = (changeToField.text ?? "New Category").trimmingCharacters(in: .whitespacesAndNewlines).capitalized
                        if category.title != newTitle {
                            var number = 2
                            if categories.first(where: { $0.title == newTitle } ) != nil {
                                newTitle += String(number)
                            }
                            while categories.first(where: { $0.title == newTitle } ) != nil {
                                number += 1
                                newTitle = newTitle.prefix(newTitle.count - 1) + String(number)
                            }
                            category.title = newTitle
                        }
                    default:
                        break
                    }
                }
            }
            fetchCategories()
            refreshCategoriesTable()
            changeToField.backgroundColor = greyDarkest
            checkForMissingCategories(self)
        }
    }
    
    @IBAction func tapBack(_ sender: UIButton) {
        if categories.count == 0 { createDefaultCategories() }
        performSegue(withIdentifier: (UserDefaults.standard.string(forKey: "LastScreen") ?? "NewTransaction"), sender: nil)
    }
    
    @IBAction func tapDeleteCategories(_ sender: DesignableButton) {
        changeToField.backgroundColor = greyDarkest
        (categories.reduce(0) { $0 + ($1.selected ? 1 : 0) }) > 1 ? deleteCategoriesConfirm() : deleteCategories()
    }
    
    @IBAction func tapSignOut(_ sender: DesignableButton) {
        for i in categories   { PersistenceService.context.delete(i) }
        for i in transactions { PersistenceService.context.delete(i) }
        categories =   []
        transactions = []
        PersistenceService.saveContext()
        
        firebaseReference = nil
        UserDefaults.standard.set(false, forKey: "SkipLogin")
        UserDefaults.standard.removeObject(forKey: "UserID")
        UserDefaults.standard.removeObject(forKey: "Username")
        UserDefaults.standard.removeObject(forKey: "Budget")
        UserDefaults.standard.removeObject(forKey: "StartDate")
        UserDefaults.standard.removeObject(forKey: "TransactionIndex")
        UserDefaults.standard.removeObject(forKey: "FirebaseFetched")
        
        createDefaults()
        createDefaultCategories()
        
        authenticationLabel.isHidden = true
        signOutButton.isHidden = true
        usernameLabel.isHidden = true
        loginButton.isHidden = false
        refreshCategoriesTable()
    }
}

extension VCSettings: UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return categories.count }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = .clear
        cell.textLabel?.textColor = .white
        cell.textLabel?.font = UIFont(name: "Metropolis-ExtraBold", size: 17)
        cell.detailTextLabel?.textColor = offWhite
        cell.detailTextLabel?.font = UIFont(name: "Metropolis-Regular", size: 14)
        cell.textLabel?.text = categories[indexPath.row].title
        cell.detailTextLabel?.text = "Allowance: " + String(format:"%.02f", categories[indexPath.row].budget).currencyFormat() + "; " + String(format:"%.02f%% of Budget", categories[indexPath.row].proportion * 100.0)
        return cell
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) { createCheckmarks() }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.reloadData()
        categories  [indexPath.row].selected = !categories  [indexPath.row].selected
        highlightChangeAndDeleteButtons()
        createCheckmarks()
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        tableView.reloadData()
        categories  [indexPath.row].selected = !categories  [indexPath.row].selected
        highlightChangeAndDeleteButtons()
        createCheckmarks()
    }
    
    func createCheckmarks() {
        for i in 0..<categories.count {
            if categories[i].selected {
                if let cell = categoriesTable.cellForRow(at: IndexPath(row: i, section: 0)) {
                    cell.contentView.superview!.backgroundColor = greyDarker
                    cell.accessoryType = .checkmark
                    cell.selectionStyle = .none
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            UserDefaults.standard.set(categories.count == 1 ? 0.0 : UserDefaults.standard.double(forKey: "Budget") - categories[indexPath.row].budget, forKey: "Budget")
            budgetField.text = String(format:"%.02f", UserDefaults.standard.double(forKey: "Budget")).currencyFormat()
            PersistenceService.context.delete(categories[indexPath.row])
            categories.remove(at: indexPath.row)
            PersistenceService.saveContext()
            tableView.beginUpdates()
            tableView.deleteRows(at: [indexPath], with: .automatic)
            tableView.endUpdates()
            highlightChangeAndDeleteButtons()
            checkForMissingCategories(self)
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

extension VCSettings: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { return 1 }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        pickerView.backgroundColor = greyDarkest
        switch pickerView {
        case changeFromCategoriesPicker:   return attributesCategory.count
        case currencyPicker:               return currencies.count
        case periodPicker:                 return periods.count
        default:                           return 0
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch pickerView {
        case changeFromCategoriesPicker:   return attributesCategory[row]
        case currencyPicker:               return currencies[row]
        case periodPicker:                 return periods[row]
        default:                           return ""
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch pickerView {
        case changeFromCategoriesPicker:
            changeFromField.text = attributesCategory[row]
            if changeFromField.text == "Amount" { changeToField.keyboardType = UIKeyboardType.numberPad }
            else                                { changeToField.keyboardType = UIKeyboardType.default   }
            changeToField.keyboardAppearance = UIKeyboardAppearance.dark
            changeToField.text = ""
            highlightChangeAndDeleteButtons()
        case currencyPicker:
            currencyField.text = currencies[row]
            UserDefaults.standard.set(currencies[row], forKey: "Currency")
            refreshCategoriesTable()
        case periodPicker:
            periodField.text = periods[row]
            UserDefaults.standard.set(periods[row], forKey: "Period")
            budgetLabel.text = periods[row].uppercased() + " BUDGET"
            firebaseReference?.child("Settings").updateChildValues(["Period": periods[row]])
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
        case changeFromCategoriesPicker:   label.text = attributesCategory[row]
        case currencyPicker:               label.text = currencies[row]
        case periodPicker:                 label.text = periods[row]
        default:                           break
        }
        return label
    }
}
