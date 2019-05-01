//WORK IN PROGRESS
import UIKit
import CoreData
import Firebase

//used by most classes
func fetchTransactions(sortBy: String, ascending: Bool) {
    globalSortBy = sortBy
    globalAscending = ascending
    let transactionsFetch: NSFetchRequest<Transaction> = Transaction.fetchRequest()
    switch sortBy {
    case "Amount":        transactionsFetch.sortDescriptors = [NSSortDescriptor(key: #keyPath(Transaction.amount),   ascending: ascending)]
    case "Category":      transactionsFetch.sortDescriptors = [NSSortDescriptor(key: #keyPath(Transaction.category), ascending: ascending)]
    case "Date":          transactionsFetch.sortDescriptors = [NSSortDescriptor(key: #keyPath(Transaction.date),     ascending: ascending)]
    case "Description":   transactionsFetch.sortDescriptors = [NSSortDescriptor(key: #keyPath(Transaction.title),    ascending: ascending)]
    case "Transaction #": transactionsFetch.sortDescriptors = [NSSortDescriptor(key: #keyPath(Transaction.index),    ascending: ascending)]
    default:              break
    }
    do {
        transactions = try PersistenceService.context.fetch(transactionsFetch)
        if sortBy == "Date" && ascending {
            UserDefaults.standard.set(min(Date(), transactions.first?.date ?? Date()).toString(), forKey: "StartDate")
        }
        for transaction in transactions { transaction.selected = false }
        PersistenceService.saveContext()
    } catch {}
}

func createDefaults() {
    if UserDefaults.standard.object(forKey: "Period") == nil {
        if UserDefaults.standard.string(forKey: "UserID") == nil { UserDefaults.standard.set("Monthly", forKey: "Period") }
        else {
            firebaseReference?.child("Settings").child("Period").observeSingleEvent(of: .value, with: { snapshot in
                if snapshot.exists() {
                    if let val = snapshot.value as? String { UserDefaults.standard.set(val, forKey: "Period") }
                } else {
                    UserDefaults.standard.set("Monthly", forKey: "Period")
                    firebaseReference?.child("Settings").updateChildValues([ "Period": "Monthly" ])
                }
            })
        }
    }
    if UserDefaults.standard.object(forKey: "Budget")      == nil                            { UserDefaults.standard.set(0.0, forKey: "Budget") }
    if UserDefaults.standard.object(forKey: "ChartPeriod") == nil                            { UserDefaults.standard.set("M", forKey: "ChartPeriod") }
    if UserDefaults.standard.object(forKey: "Currency")    == nil                            { UserDefaults.standard.set("$", forKey: "Currency") }
    if UserDefaults.standard.object(forKey: "StartDate")   == nil || transactions.count == 0 { UserDefaults.standard.set(Date().toString(), forKey: "StartDate") }
}

func addCategories(_ budgets: [Double], _ proportions: [Double], _ selected: [Bool], _ poss: [Bool], _ titles: [String]) {
    for i in 0..<titles.count {
        let category = Category(context: PersistenceService.context)
        category.budget = UserDefaults.standard.double(forKey: "Budget") + budgets[i] > 999999.99 ? 999999.99 - UserDefaults.standard.double(forKey: "Budget") : budgets[i]
        category.proportion = proportions[i]
        category.selected = selected[i]
        category.sign = poss[i]
        category.title = titles[i].trimmingCharacters(in: .whitespacesAndNewlines).capitalized
        categories.append(category)
        UserDefaults.standard.set(UserDefaults.standard.double(forKey: "Budget") + category.budget, forKey: "Budget")
    }
    fetchCategories()
    refreshTable()
}

func createDefaultCategories() {
    let titles = [
        "Eating Out",
        "Entertainment",
        "Gifts",
        "Groceries",
        "Household",
        "Housekeeping",
        "Misc.",
        "Personal Care",
        "Transportation",
        "Travel"
    ]
    var budgets = [Double]()
    var proportions = [Double]()
    var selected = [Bool]()
    var sign = [Bool]()
    for i in 0..<titles.count {
        budgets.append(100.0)
        proportions.append(budgets[i] / (Double(titles.count) * budgets[i]))
        selected.append(false)
        sign.append(true)
    }
    addCategories(budgets, proportions, selected, sign, titles)
}

func fetchCategories() {
    PersistenceService.saveContext()
    let categoriesFetch: NSFetchRequest<Category> = Category.fetchRequest()
    categoriesFetch.sortDescriptors = [NSSortDescriptor(key: #keyPath(Category.title), ascending: true)]
    do {
        categories = try PersistenceService.context.fetch(categoriesFetch)
        for category in categories {
            if UserDefaults.standard.double(forKey: "Budget") != 0 {
                category.proportion = category.budget / UserDefaults.standard.double(forKey: "Budget")
            }
            category.selected = false
        }
        PersistenceService.saveContext()
    } catch {}
}

func checkForMissingCategories(_ vc: UIViewController) {
    var categoryMissing = ""
    var categoryTitles = [String]()
    for category in categories { categoryTitles.append(category.title) }
    for transaction in transactions {
        if categoryTitles.firstIndex(of: transaction.category) == nil {
            categoryMissing = transaction.category
            break
        }
    }
    if categories.count == 0 && transactions.count == 0 { createDefaultCategories() }
    else if categoryMissing != "" {
        var count = 0
        for transaction in transactions {
            if transaction.category == categoryMissing {
                count += 1
                transaction.selected = true
            }
        }
        let alert = UIAlertController(title: "Category Missing", message: String(count) + (count > 1 ? " transactions" : " transaction") + " in the Ledger " + (count > 1 ? "are" : "is") + " categorized as " + categoryMissing + ", which has been deleted. Please take one of the following actions to continue:", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Re-add \"" + categoryMissing + "\" as a Category", style: .default, handler: {
            action in
            addCategories(
                [categories.count > 0 ? UserDefaults.standard.double(forKey: "Budget") / Double(categories.count) : 100.0],
                [1.0 / Double(categories.count + 1)],
                [false],
                [true],
                [categoryMissing]
            )
            checkForMissingCategories(vc)
        }))
        alert.addAction(UIAlertAction(
            title: "Recategorize " + (count > 1 ? "These Transactions..." : "This Transaction..."),
            style: .default,
            handler: { action in
                vc.performSegue(withIdentifier: "EditTransactions" + (vc.title == "Settings" ? "" : "U"), sender: nil)
            }
        ))
        alert.addAction(UIAlertAction(
            title: "Delete " + (count > 1 ? "These Transactions" : "This Transaction"),
            style: .destructive,
            handler: { action in
                count > 1 ? deleteTransactionsConfirm(vc, categoryMissing) : deleteTransactions(vc)
            }
        ))
        vc.present(alert, animated: true, completion: nil)
    }
}

func deleteTransactions(_ vc: UIViewController) {
    for transaction in transactions.reversed() {
        if transaction.selected {
            if firebaseReference != nil { firebaseReference!.child("Transactions").child(String(format: "Transaction%06d", transaction.index)).removeValue() }
            PersistenceService.context.delete(transaction)
        }
    }
    PersistenceService.saveContext()
    if vc.title == "NewTransaction" { fetchTransactions(sortBy: "Date", ascending: false) }
    else if vc.title == "EditTransactions" {
        fetchTransactions(sortBy: globalSortBy, ascending: globalAscending)
        refreshTable()
    }
    if firebaseReference != nil { firebaseUpdateCounters() }
    checkForMissingCategories(vc)
}

func deleteTransactionsConfirm(_ vc: UIViewController, _ categoryMissing: String) {
    var transactionCount = 0
    for transaction in transactions { if transaction.selected { transactionCount += 1 } }
    let numberFormatter = NumberFormatter()
    numberFormatter.numberStyle = .decimal
    let message = "All " + numberFormatter.string(from: NSNumber(value: transactionCount))! + (categoryMissing == "" ? " Selected Transactions?" : " Transactions Categorized As \"" + categoryMissing + "\"?")
    let alert = UIAlertController(title: "Are You Sure You Want To Delete " + message, message: "This action cannot be undone.", preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Delete Transactions", style: .destructive, handler: { action in deleteTransactions(vc)        }))
    alert.addAction(UIAlertAction(title: "Cancel",              style: .cancel,      handler: { action in checkForMissingCategories(vc) }))
    vc.present(alert, animated: true, completion: nil)
}

func firebaseUpdateCounters() {
    let updates: [AnyHashable: Any] = [
        "Count": transactions.count,
        "MaxIndex": transactions.max(by: { $0.index < $1.index })?.index ?? 0
    ]
    firebaseReference!.child("TransactionCounters").updateChildValues(updates)
    firebasePush()
}
func firebasePush() {
    firebaseReference!.child("TransactionCounters").child("Count").observeSingleEvent(of: .value, with: { snapshot in
        if let count = snapshot.value as? Int {
            firebaseReference!.child("TransactionCounters").child("MaxIndex").observeSingleEvent(of: .value, with: { snapshot in
                if let maxIndex = snapshot.value as? Int {
                    let maxIndexMismatch = maxIndex != transactions.max(by: { $0.index < $1.index })?.index ?? 0
                    let countMismatch = count != transactions.count
                    if (maxIndexMismatch || countMismatch) {
                        firebaseReference!.child("Transactions").removeValue()
                        for transaction in transactions {
                            let updates: [AnyHashable: Any] = [
                                "Amount":   transaction.amount,
                                "Category": transaction.category,
                                "Date":     transaction.date.toString(),
                                "Index":    transaction.index,
                                "Selected": transaction.selected,
                                "Sign":     transaction.sign,
                                "Title":    transaction.title
                            ]
                            firebaseReference!.child("Transactions").child(String(format: "Transaction%06d", transaction.index)).updateChildValues(updates)
                        }
                        firebaseUpdateCounters()
                    }
                }
            })
        }
    })
    for i in 0..<20 {
        let id = String(format: "Category%02d", i + 1)
        let updates: [AnyHashable: Any] = [
            "Budget":     i < categories.count ? categories[i].budget : 0.0,
            "Proportion": i < categories.count ? categories[i].proportion : 0.05,
            "Selected":   i < categories.count ? categories[i].selected : false,
            "Sign":       i < categories.count ? categories[i].sign : true,
            "Title":      i < categories.count ? categories[i].title : id
        ]
        firebaseReference!.child("Categories").child(id).updateChildValues(updates)
    }
}

func refreshTable() {
    globalTable.backgroundColor = greyDarkest
    globalTable.tintColor = .white
    globalTable.reloadData()
    globalDeleteButton.backgroundColor = greyDark
    globalDeleteButton.setTitleColor(greyDarker, for: .normal)
    globalDeleteButton.isEnabled = false
    globalChangeButton.backgroundColor = greyDark
    globalBudgetField.text = String(format:"%.02f", UserDefaults.standard.double(forKey: "Budget")).currencyFormat()
}
