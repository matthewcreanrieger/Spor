////////10////////20////////30////////40////////50////////60////////70////////80
import UIKit
import CoreData
import Firebase

//each of the following functions are shared by "VCNewTransaction", "VCEditTransactions", and/or "VCSettings" to complete universal "Input" tasks
//generally, these tasks involve setting appropriate UserDefault values, deleting or adding Transactions or Categories locally (via CoreData), and/or syncing updates with the user's data store (via Firebase)

//create default values for most UserDefault variables if they don't already exist
func setDefaults() {
    //"Period" should be monthly unless it's already configured for the user in the Firebase data store
    if UserDefaults.standard.object(forKey: "Period") == nil {
        UserDefaults.standard.set("Monthly", forKey: "Period")
        let key = dbr?.child("Settings").child("Period")
        key?.observeSingleEvent(of: .value, with: { snap in
            if snap.exists() {
                if let val = snap.value as? String {
                    UserDefaults.standard.set(val, forKey: "Period")
                }
            } else {
                dbr?.child("Settings").updateChildValues(["Period": "Monthly"])
            }
        })
    }
    if UserDefaults.standard.object(forKey: "Budget") == nil {
        UserDefaults.standard.set(0.0, forKey: "Budget")
    }
    if UserDefaults.standard.object(forKey: "ChartPeriod") == nil {
        UserDefaults.standard.set("M", forKey: "ChartPeriod")
    }
    if UserDefaults.standard.object(forKey: "Currency") == nil {
        UserDefaults.standard.set("$", forKey: "Currency")
    }
    if UserDefaults.standard.object(forKey: "StartDate") == nil {
        UserDefaults.standard.set(Date().toString(), forKey: "StartDate")
    }
}

//creates default Categories; called if no categories exist
func setDefaultCtgs() {
    let ttls = [
        "Travel",
        "Transportation",
        "Personal Care",
        "Misc.",
        "Housekeeping",
        "Household",
        "Groceries",
        "Gifts",
        "Entertainment",
        "Eating Out"
    ]
    var bdgs = [Double]()
    var prts = [Double]()
    for i in 0..<ttls.count {
        bdgs.append(100.0)
        prts.append(bdgs[i] / (Double(ttls.count) * bdgs[i]))
    }
    addCtgs(bdgs, prts, ttls)
}

//create new Categories based on provided inputs then call "refreshSpecialFormatting(...)" in case "categoriesTable" is in view and needs updating
func addCtgs(_ bdgs: [Double], _ prts: [Double], _ ttls: [String]) {
    for i in 0..<ttls.count {
        let ctg = Category(context: PersistenceService.context)
        let bdg = UserDefaults.standard.double(forKey: "Budget")
        ctg.budget = bdg + bdgs[i] > 999999.99 ? 999999.99 - bdg : bdgs[i]
        ctg.proportion = prts[i]
        ctg.selected = false
        ctg.sign = true
        ctg.title =
            ttls[i].trimmingCharacters(in: .whitespacesAndNewlines).capitalized
        //inserted at top of list so that the user can clearly see the update
        ctgs.insert(ctg, at: 0)
        UserDefaults.standard.set(bdg + ctg.budget, forKey: "Budget")
    }
    for ctg in ctgs { ctg.selected = false }
    PersistenceService.saveContext()
    refreshSpecialFormatting()
    firebasePushCtgs()
}

//use global references to either...
//1. "VCSettings"'s "categoriesTable", "deleteButton", "changeButton", and "budgetField"...
//2. "VCEditTransactions"'s "transactionsTable", "deleteButton", and "changeButton"...
//...in order to apply appropriate special formatting when CoreData changes are made to "ctgs" or "txns"
func refreshSpecialFormatting() {
    globalTable.backgroundColor = greyDarkest
    globalTable.tintColor = .white
    globalTable.reloadData()
    globalDeleteButton.backgroundColor = greyDark
    globalDeleteButton.setTitleColor(greyDarker, for: .normal)
    globalDeleteButton.isEnabled = false
    globalChangeButton.backgroundColor = greyDark
    let bdg = UserDefaults.standard.double(forKey: "Budget")
    globalBudgetField.text = String(format:"%.02f", bdg).currencyFormat()
}

//called often to check that all Transactions have matching Categories
//if a Category is identified as missing, present the user with the following options
//1. Re-add the Category (which actually just creates a new Category with the same name and an automatically-calculated budget)
//2. Delete all Transactions associated with that Category
//3. Re-categorize the problematic Transactions (which just transitions the user to "EditTransactions")
func checkCtgMissing(_ vc: UIViewController) {
    var ctgMiss = ""
    var ctgTtls = [String]()
    for ctg in ctgs { ctgTtls.append(ctg.title) }
    for txn in txns {
        if ctgTtls.firstIndex(of: txn.category) == nil {
            ctgMiss = txn.category
            break
        }
    }
    //create new default Categories if there are no Transactions and therefore no possibility of "ctgMiss" equaling anything but ""
    //there must be Categories at all times or most core functionality is lost
    if ctgs.count == 0 && txns.count == 0 && vc.title != "Settings" {
        setDefaultCtgs()
    }
    else if ctgMiss != "" {
        var ct = 0
        for txn in txns {
            if txn.category == ctgMiss {
                ct += 1
                txn.selected = true
            }
        }
        let plr = ct > 1
        let bdg = UserDefaults.standard.double(forKey: "Budget")
        let alert = UIAlertController(
            title: "Category Missing",
            message: String(ct) + (plr ? " transactions" : " transaction") +
                " in the Ledger " + (plr ? "are" : "is") + " categorized as " +
                "\"" + ctgMiss + "\", which has been deleted. Please take " +
                "one of the following actions to continue:",
            preferredStyle: .alert
        )
////////////////////////////////////////////////////////////////////////////////
        alert.addAction(UIAlertAction(
            title: "Re-add \"" + ctgMiss + "\" as a Category",
            style: .default,
            handler: {
                action in
                addCtgs(
                    [ctgs.count > 0 ? bdg / Double(ctgs.count) : 100.0],
                    [1.0 / Double(ctgs.count + 1)], [ctgMiss]
                )
                
                //"checkCtgMissing(...)" is called repeatedly until there are no missing Categories, essentially blocking user input until discrepencies are resolved
                checkCtgMissing(vc)
        }
        ))
        alert.addAction(UIAlertAction(
            title: "Recategorize Th" +
                (plr ? "ese Transactions..." : "is Transaction..."),
            style: .default,
            handler: { action in
                vc.performSegue(withIdentifier: "EditTransactions" +
                    (vc.title == "Settings" ? "" : "U"), sender: nil)
        }
        ))
        alert.addAction(UIAlertAction(
            title: "Delete Th" + (plr ? "ese Transactions" : "is Transaction"),
            style: .destructive,
            handler: { action in
                plr ? confirmTxnsDelete(vc, ctgMiss) : deleteTxns(vc)
        }
        ))
        vc.present(alert, animated: true, completion: nil)
    }
}

//if the user decides to delete more than 1 Transaction at once, this function is used to confirm that choice
func confirmTxnsDelete(_ vc: UIViewController, _ ctgMissing: String) {
    var ct = 0
    for txn in txns { if txn.selected { ct += 1 } }
    let fmt = NumberFormatter()
    fmt.numberStyle = .decimal
    let nmb = fmt.string(from: NSNumber(value: ct)) ?? ""
    let ttl = ctgMissing == "" ? " Selected Transactions?" :
        " Transactions Categorized As \"" + ctgMissing + "\"?"
    let alert = UIAlertController(
        title: "Are You Sure You Want To Delete All " + nmb + ttl,
        message: "This action cannot be undone.",
        preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(
        title: "Delete Transactions",
        style: .destructive,
        handler: { action in deleteTxns(vc) }
    ))
    alert.addAction(UIAlertAction(
        title: "Cancel",
        style: .cancel,
        handler: { action in checkCtgMissing(vc) }
    ))
    vc.present(alert, animated: true, completion: nil)
}

//if the user only attempted to delete 1 transaction or has confirmed that they want to delete more than 1, this function is called
func deleteTxns(_ vc: UIViewController) {
    for txn in txns.reversed() {
        if txn.selected {
            //delete the matching Transaction in the data store
            let child = String(format: "Transaction%06d", txn.index)
            dbr?.child("Transactions").child(child).removeValue()
            PersistenceService.context.delete(txn)
        }
    }
    PersistenceService.saveContext()
    
    //if the user is on "EditTransactions", the data for "transactionsTable" must be refreshed in the same order as they initially chose it to appear for better UX
    if vc.title == "EditTransactions" {
        fetchTxns(sortBy: globalSortBy, asc: globalAscending)
        refreshSpecialFormatting()
    } else { fetchTxns(sortBy: "Date", asc: false) }
    firebasePushTxns()
    
    //"checkCtgMissing(...)" is called repeatedly until there are no missing Categories, essentially blocking user input until discrepencies are resolved
    checkCtgMissing(vc)
}

//fetch and sort local (CoreData) Categories
//there are no sort options for the user to choose from; therefore, since Categories never need to be re-sorted, this is called considerably less often than the similar "fetchTxns(...)"
func fetchCtgs() {
    PersistenceService.saveContext()
    let ctgFR: NSFetchRequest<Category> = Category.fetchRequest()
    ctgFR.sortDescriptors =
        [NSSortDescriptor(key: #keyPath(Category.title), ascending: true)]
    do {
        ctgs = try PersistenceService.context.fetch(ctgFR)
        let bdg = UserDefaults.standard.double(forKey: "Budget")
        for ctg in ctgs {
            if bdg != 0 { ctg.proportion = ctg.budget / bdg }
            ctg.selected = false
        }
        PersistenceService.saveContext()
    } catch {}
    firebasePushCtgs()
}

//whenever Categories are changed, this function is called to update counters in the user's data store and resolve any discrepencies between online and offline Transactions
//this is called every time Categories are fetched because Categories are only fetched during the same kind of changes, whereas Transactions are fetched more often in order to sort them
func firebasePushCtgs() {
    for i in 0..<20 {
        let ctgID = String(format: "Category%02d", i + 1)
        let upd : [AnyHashable: Any] = [
            "Budget":     i < ctgs.count ? ctgs[i].budget     : 0,
            "Proportion": i < ctgs.count ? ctgs[i].proportion : 0,
            "Selected":   i < ctgs.count ? ctgs[i].selected   : false,
            "Sign":       i < ctgs.count ? ctgs[i].sign       : false,
            "Title":      i < ctgs.count ? ctgs[i].title      : ctgID
        ]
        dbr?.child("Categories")
            .child(ctgID).updateChildValues(upd)
    }
}

//fetch and sort local (CoreData) Transactions
func fetchTxns(sortBy: String, asc: Bool) {
    //these are set so that "transactionsTable" in "VCEditTransactions.swift" will still maintain its user-chosen sort order after the user deletes transactions
    globalSortBy = sortBy
    globalAscending = asc
    
    let txnFR: NSFetchRequest<Transaction> = Transaction.fetchRequest()
    switch sortBy {
    case "Amount":        txnFR.sortDescriptors = [NSSortDescriptor(
                          key: #keyPath(Transaction.amount), ascending: asc)]
    case "Category":      txnFR.sortDescriptors = [NSSortDescriptor(
                          key: #keyPath(Transaction.category), ascending: asc)]
    case "Date":          txnFR.sortDescriptors = [NSSortDescriptor(
                          key: #keyPath(Transaction.date), ascending: asc)]
    case "Description":   txnFR.sortDescriptors = [NSSortDescriptor(
                          key: #keyPath(Transaction.title), ascending: asc)]
    case "Transaction #": txnFR.sortDescriptors = [NSSortDescriptor(
                          key: #keyPath(Transaction.index), ascending: asc)]
    default: break
    }
    do {
        txns = try PersistenceService.context.fetch(txnFR)
        
        //"StartDate" needs to be established before executing most "Dashboard"-related functions
        //before transitioning to any "Dashboard" UIViewController, this function is called with "sortBy: "Date", asc: true", at which point "StartDate" can be set to the minimum between now and the user's first Transaction
        //"StartDate" cannot be sooner than today or certain "Dashboard"-related functions will crash
        let start = min(Date(), txns.first?.date ?? Date()).toString()
        if sortBy == "Date" && asc {
            UserDefaults.standard.set(start, forKey: "StartDate")
        }
        
        //whether or not a Transaction or Category is selected determines if it is deleted when a delete function is called
        //therefore, all Transactions and Categories are unselected at load to prevent accidental deletion
        for txn in txns { txn.selected = false }
        PersistenceService.saveContext()
    } catch {}
}

//whenever Transactions are changed, this function is called to update counters in the user's data store and resolve any discrepencies between online and offline Transactions
func firebasePushTxns() {
    let key = dbr?.child("TransactionCounters")
    let upd: [AnyHashable: Any] = [
        "Count": txns.count,
        "MaxIndex": txns.max(by: { $0.index < $1.index })?.index ?? 0
    ]
    key?.updateChildValues(upd)
    key?.child("Count").observeSingleEvent(of: .value, with: { snap in
        if let ct = snap.value as? Int {
            key?.child("MaxIndex").observeSingleEvent(of: .value, with: {snap in
                if let mi = snap.value as? Int {
                    let miMatch =
                        mi == txns.max(by: { $0.index < $1.index })?.index ?? 0
                    let ctMatch = ct == txns.count
                    if !miMatch || !ctMatch {
                        dbr?.child("Transactions").removeValue()
                        for txn in txns {
                            let updates: [AnyHashable: Any] = [
                                "Amount":   txn.amount,
                                "Category": txn.category,
                                "Date":     txn.date.toString(),
                                "Index":    txn.index,
                                "Selected": txn.selected,
                                "Sign":     txn.sign,
                                "Title":    txn.title
                            ]
                            let child =
                                String(format: "Transaction%06d", txn.index)
                            dbr?.child("Transactions")
                                .child(child).updateChildValues(updates)
                        }
                        firebasePushTxns()
                    }
                }
            })
        }
    })
}

//this is just a micro helper function that prevents copy-pasting the same code into all "Input" .swift files
func makeToolbar() -> UIToolbar {
    let toolbar = UIToolbar(frame: CGRect.init(
        x: 0, y: 0, width: UIScreen.main.bounds.width, height: 0))
    toolbar.barStyle = .default
    toolbar.barTintColor = greyDarkest
    toolbar.sizeToFit()
    toolbar.tintColor = .white
    return toolbar
}
////////10////////20////////30////////40////////50////////60////////70////////80
