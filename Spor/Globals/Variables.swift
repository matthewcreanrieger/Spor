////////10////////20////////30////////40////////50////////60////////70////////80
import UIKit
import Firebase

//used by "PieChart.swift" and "VCPieCharts.swift"
var pies = [PieChart]()

//used by "VCEditTransactions.swift" and "InputHelperFunctions.swift"
var globalAscending = true
var globalSortBy = ""

//used by "VCEditTransactions.swift", "VCSettings.swift", and "InputHelperFunctions.swift"
var globalTable = UITableView()
var globalChangeButton = DesignableButton()
var globalDeleteButton = DesignableButton()

//used by "VCSettings.swift", and "InputHelperFunctions.swift"
var globalBudgetField = UITextField()

//used by most classes
var ctgs = [Category]()
var txns = [Transaction]()
var dbr: DatabaseReference?
let red          = UIColor(named: "Red")          ?? .red
let teal         = UIColor(named: "Teal")         ?? .cyan
let offWhite     = UIColor(named: "OffWhite")     ?? .white
let greyLightest = UIColor(named: "GreyLightest") ?? .white
let greyLighter  = UIColor(named: "GreyLighter")  ?? .lightGray
let greyLight    = UIColor(named: "GreyLight")    ?? .lightGray
let grey         = UIColor(named: "Grey")         ?? .gray
let greyDark     = UIColor(named: "GreyDark")     ?? .darkGray
let greyDarker   = UIColor(named: "GreyDarker")   ?? .darkGray
let greyDarkest  = UIColor(named: "GreyDarkest")  ?? .black

//used by "VCPieCharts.swift" and "VCBreakdown.swift"
//a list of 20 color-blindness-friendly colors used to distinguish a user's categories
//CREDIT: Sasha Trubetskoy (https://sashat.me/2017/01/11/list-of-20-simple-distinct-colors/)
//SIMILARITY TO ORIGINAL CONTENT: mostly just reorganized
let colors = [
    teal,
    red,
    UIColor(red: 0.00, green: 0.50, blue: 0.50, alpha: 1.0),
    UIColor(red: 0.90, green: 0.75, blue: 1.00, alpha: 1.0),
    UIColor(red: 0.50, green: 0.00, blue: 0.00, alpha: 1.0),
    UIColor(red: 0.26, green: 0.39, blue: 0.85, alpha: 1.0),
    UIColor(red: 1.00, green: 0.88, blue: 0.10, alpha: 1.0),
    UIColor(red: 0.57, green: 0.12, blue: 0.71, alpha: 1.0),
    UIColor(red: 0.24, green: 0.71, blue: 0.29, alpha: 1.0),
    UIColor(red: 0.96, green: 0.51, blue: 0.19, alpha: 1.0),
    UIColor(red: 0.67, green: 1.00, blue: 0.78, alpha: 1.0),
    UIColor(red: 0.90, green: 0.10, blue: 0.29, alpha: 1.0),
    UIColor(red: 0.50, green: 0.50, blue: 0.50, alpha: 1.0),
    UIColor(red: 0.74, green: 0.96, blue: 0.05, alpha: 1.0),
    UIColor(red: 1.00, green: 0.85, blue: 0.69, alpha: 1.0),
    UIColor(red: 0.00, green: 0.00, blue: 0.46, alpha: 1.0),
    UIColor(red: 0.60, green: 0.39, blue: 0.14, alpha: 1.0),
    UIColor(red: 0.94, green: 0.20, blue: 0.90, alpha: 1.0),
    UIColor(red: 1.00, green: 0.98, blue: 0.78, alpha: 1.0),
    UIColor(red: 0.50, green: 0.50, blue: 0.00, alpha: 1.0)
]
////////10////////20////////30////////40////////50////////60////////70////////80
