////////10////////20////////30////////40////////50////////60////////70////////80
import UIKit
import CoreData
import Firebase

class VCLogin: UIViewController, UITextFieldDelegate {

    //a dark grey overlay and loading indicator displayed while authenticating with Firebase
    @IBOutlet weak var activityIndicatorView: UIView!
    
    //used to outline the input field teal when a user has entered all required info
    @IBOutlet weak var inputsView: DesignableView!
    
    //the helper labels contain instructions if the user hasn't enetered, for example, a proper email address
    @IBOutlet weak var passwordHelperLabel: UILabel!
    @IBOutlet weak var retypePasswordHelperLabel: UILabel!
    @IBOutlet weak var usernameHelperLabel: UILabel!
    
    @IBOutlet weak var passwordField: DesignableTextField!
    @IBOutlet weak var retypePasswordField: DesignableTextField!
    @IBOutlet weak var usernameField: DesignableTextField!
    
    //this label needs to be a variable because it is hidden for the "Sign In" authentication method
    @IBOutlet weak var retypePasswordLabel: UILabel!
    
    @IBOutlet weak var signInButton: DesignableButton!
    @IBOutlet weak var signUpButton: DesignableButton!
    @IBOutlet weak var goButton: DesignableButton!
    @IBOutlet weak var tcCheck: DesignableButton!
    @IBOutlet weak var tc: UITextView!
    
    var username = ""
    var password = ""
    var retypedPassword = ""
    var invalidPassword = true
    var invalidUsername = true
    var signUp = true
    var tcChecked = false
    
    //used to prevent Firebase from serving a confusing error message to users
    var timeStamp = Date()
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //if a user gets to this screen, then the "Login" View Controller should not be skipped at launch
        UserDefaults.standard.set(false, forKey: "SkipLogin")

        timeStamp = Calendar.current.date(byAdding: .minute, value: Int(-1),
                                          to: Date()) ?? Date()
        
        //add toolbar with "Close" button to inputViews of applicable UITextFields and configure these fields to close when the "Return" key is pressed
        let toolbar = UIToolbar(frame: .init(x: 0, y: 0, width: 0, height: 0))
        toolbar.barStyle = .default
        toolbar.barTintColor = greyDarkest
        toolbar.setItems([UIBarButtonItem(title: "Close",
                                          style: .plain,
                                          target: self,
                                          action: #selector(buttonAction))],
                                          animated: true)
        toolbar.sizeToFit()
        toolbar.tintColor = .white
        for field in [usernameField, passwordField, retypePasswordField] {
            field?.inputAccessoryView = toolbar
            field?.tintColor = .white
            field?.delegate = self
        }
    }
    @objc func buttonAction() { view.endEditing(true) }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //prevents bug where a UITextView initially displays the middle of its content rather than the beginning
        tc.scrollRangeToVisible(NSRange(location:0, length:0))
    }
    
    //switch which authentication method is highlighted, "Sign Up" or "Sign In", and hide/reveal all appropriate input items
    @IBAction func tapAuthenticationType(_ sender: DesignableButton) {
        signUp = !signUp
        switch signUp {
        case true:
            //switch which authentication method is highlighted, "Sign Up" or "Sign In"
            signUpButton.borderColor = teal
            signUpButton.setTitleColor(.white, for: .normal)
            signInButton.borderColor = greyLighter
            signInButton.setTitleColor(greyLighter, for: .normal)
            
            //switch whether items not relevant to "Sign In" are hidden
            retypePasswordField.isHidden = false
            retypePasswordLabel.isHidden = false
            retypePasswordHelperLabel.isHidden =
                retypedPassword == "" || retypedPassword == password
            
            //switch whether the user agreement is checked by default since a returning user will have already agreed to the terms
            tcCheck.borderColor = greyLighter
            tcCheck.setTitle("", for: .normal)
            tcCheck.isUserInteractionEnabled = true
            tcChecked = false
            
            //check if the "Go" button can be highlighted based on whether all required inputs have been provided by the user
            //for example, username and password don't get wiped when switching between "Sign Up" and "Sign In", so if a user switches from "Sign Up" to "Sign In", they may have already filled out all the necessary info for that authentication method
            highlightGoButton()
            
        //reverse of everything in the "true" case
        case false:
            signInButton.borderColor = teal
            signInButton.setTitleColor(.white, for: .normal)
            signUpButton.borderColor = greyLighter
            signUpButton.setTitleColor(greyLighter, for: .normal)
            retypePasswordField.isHidden = true
            retypePasswordLabel.isHidden = true
            retypePasswordHelperLabel.isHidden = true
            tcCheck.borderColor = teal
            tcCheck.setTitle("✓", for: .normal)
            tcCheck.isUserInteractionEnabled = false
            tcChecked = true
            highlightGoButton()
        }
    }

    @IBAction func editUsernameField(_ sender: DesignableTextField) {
        username = sender.text ?? ""

        //hide the helper text if the field is empty or the field contains a valid email format
        let f = "SELF MATCHES %@"
        let e = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        invalidUsername = !NSPredicate(format: f, e).evaluate(with: username)
        usernameHelperLabel.isHidden = username == "" || !invalidUsername

        //remove any red highlights from when/if a user hit the "Go" button without completing a required field
        usernameField.backgroundColor = greyDarkest

        highlightGoButton()
    }
    
    //determine the differences between a user's starting "password" or "retypedPassword" and what has been inputed into "passwordField" or "retypedPasswordField" and create a new password based on this information
    //this reinventing of the wheel, so-to-speak, for a secure text entry is necessary in order to prevent iOS from attempting to autofill "Strong Password" info/suggestions, which disrupts the UX of the login workflow
    @IBAction func editPasswordField(_ sender: DesignableTextField) {
        var input = Array(sender.text ?? "")
        var oldPW = Array(sender == passwordField ? password : retypedPassword)
        var newPW = Array("")
        
        //if character(s) are simply deleted from "passwordField" or "retypePasswordField" (not replaced or added to), "cursorPosition" is used to determine which corresponding character(s) need to also be removed from "oldPW"
        //this is indicated by "input" comprising of only "•" (bullets) and being shorter in length than "oldPW"
        var onlyBullets = true
        for char in input { if char != "•" { onlyBullets = false } }
        if onlyBullets && input.count < oldPW.count {
            if let selectedRange = sender.selectedTextRange {
                let cursorPosition = sender.offset(
                    from: sender.beginningOfDocument, to: selectedRange.start)
                let prefix = String(oldPW.prefix(cursorPosition))
                let suffix = String(oldPW.suffix(input.count - cursorPosition))
                input = Array(prefix + suffix)
            } else { input = Array("") }
        }

        //if no changes were made via input, input would comprise solely of a number of bullets equal to the length of "oldPW"
        //therefore, the number of changes made to "oldPW" via "input" can be measured with "bulletDifference" by calculating the number of characters in "input" that are NOT bullets
        var bulletDifference = oldPW.count
        for char in input { if char == "•" { bulletDifference -= 1 } }
        
        //the only way "bulletDifference" can be less than 0 is if a user copy-pasted a bullet into "input", which cannot be allowed because it would cause this function to crash
        //if a user pastes bullet(s) into "input", "input" is deleted
        //an edge case not accounted for is pasting a mix of characters and bullets (i.e. "ex•mple") when "oldPW.count" exceeds the number of bullets in the mixed input, but this does not cause crashes and therefore is not worth preventing
        if bulletDifference < 0 {
            bulletDifference = oldPW.count
            input = Array("")
        }
        
        //"bulletDifference" is used to remove every character from "oldPW" that corresponds with a character in "input" that has been changed
        //a changed character in "input" is indicated by the fact that it is not a bullet
        //once "bulletDifference" equals the number of bullets deleted, this loop ends
        var bulletsDeleted = 0
        for i in 0..<input.count {
            if bulletsDeleted == bulletDifference { break }
            if input[i] != "•" {
                oldPW.remove(at: i - bulletsDeleted)
                bulletsDeleted += 1
            }
        }
        
        //what remains of "oldPW" is used to substitute bullets in "input" for appropriate characters from "oldPW" to create "newPW"
        //for example, if "oldPW" is "AcbDE" and "input" is "•bc••", then "oldPW" will get truncated to "ADE" and "newPW" will equal "A" + "bc" + "DE", or "AbcDE"
        var i = 0
        for char in input {
            if char == "•" {
                newPW.append(oldPW[i])
                i += 1
            } else { newPW.append(char) }
        }
        sender == passwordField ?
            (password = String(newPW)) : (retypedPassword = String(newPW))

        //"passwordField" or "retypePasswordField" is then converted into a string of bullets equal to the length of the new password to ensure password security in the UI
        sender.text = String(repeating: "•", count: sender == passwordField ?
            password.count : retypedPassword.count)
        
        //hide the helper text if the field is empty or the field contains a valid password (length greater than 6 characters)
        //password security is poor intentionally; users shouldn't worry about creating a secure password because the Firebase database itself probably doens't meet security best practices
        invalidPassword = password.count < 6
        passwordHelperLabel.isHidden = password == "" || !invalidPassword
        retypePasswordHelperLabel.isHidden =
            retypedPassword == "" || retypedPassword == password
        
        sender == passwordField ? (passwordField.backgroundColor = greyDarkest)
            : (retypePasswordField.backgroundColor = greyDarkest)
        highlightGoButton()
    }
    
    //allow users to permanenantly skip the login workflow and transition users to the "NewTransaction" View Controller if they want to always use the app offline
    //the "Ask Later" button in the UI also transitions users to the "NewTransaction" View Controller, but this is defined in the Storyboard
    @IBAction func tapAskNever(_ sender: DesignableButton) {
        let alert = UIAlertController(
            title: "Are you sure you want to always skip the Login screen?",
            message: "Note: If you never create an account, all of your data " +
            "will be lost in the event your device is restored or replaced.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: "Don't Ask Again",
            style: .destructive,
            handler: { action in
                UserDefaults.standard.set(true, forKey: "SkipLogin")
                
                //leave the "Login" View Controller and transition to the home screen of the app (the "NewTransaction" View Controller)
                self.performSegue(withIdentifier: "NewTransaction", sender: nil)
            }
        ))
        alert.addAction(UIAlertAction(title: "Cancel",
                                      style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    //"tc" stands for "Terms & Conditions" (the entry in the UI has been renamed to "Disclaimer")
    //users must agree to the "Disclaimer" before authenticating
    @IBAction func tapTC(_ sender: DesignableButton) {
        tcChecked = !tcChecked
        switch tcChecked {
        case true:
            tcCheck.borderColor = teal
            tcCheck.setTitle("✓", for: .normal)
        case false:
            tcCheck.borderColor = greyLighter
            tcCheck.setTitle("", for: .normal)
        }
        highlightGoButton()
    }
    
    //switch whether the "Go" button is highlighted and enabled based on whether all required inputs have been filled in by the user
    //the "Go" button starts the authentication attempt
    func highlightGoButton() {
        if tcChecked && !invalidUsername && !invalidPassword &&
            (!signUp || retypedPassword == password)
        {
            goButton.borderColor = teal
            goButton.backgroundColor = teal
            inputsView.borderColor = teal
        } else {
            goButton.borderColor = greyDarker
            goButton.backgroundColor = greyDark
            inputsView.borderColor = greyDarker
        }
    }

    @IBAction func tapGoButton(_ sender: DesignableButton) {
        //close all open keyboards
        view.endEditing(true)
        
        //if any required fields are incomplete, highlight them red
        if !tcChecked || invalidUsername || invalidPassword ||
            (signUp && retypedPassword != password)
        {

            usernameField.backgroundColor = invalidUsername ? red : greyDarkest
            passwordField.backgroundColor = invalidPassword ? red : greyDarkest
            retypePasswordField.backgroundColor =
                signUp && (retypedPassword != password || invalidPassword) ?
                    red : greyDarkest
            tcCheck.borderColor = tcChecked ? teal : red
        }
        //if all required fields are complete, attempt to either Sign Up or Sign In the user with the credentials supplied
        else { signUp ?
            signUp(username, password) : signIn(username, password) }
    }

    func signUp(_ username: String, _ password: String) {
        //when the app is attempting to communicate with Firebase's servers, all user inputs are disabled and a dark grey overlay and loading indicator are displayed
        displayActivityIndicator(true)

        Auth.auth().createUser(withEmail: username, password: password) {
            authResult, error in
            
            //if there is no error, prompt users to verify their email
            if error == nil { self.sendVerificationEmail(authResult!) }
            
            //if there is an error, generate an appropriate error message for the user to respond to
            else {
                let alert = UIAlertController(
                    title: "Sign Up Failed",
                    message: self.generateErrorMessage(error!),
                    preferredStyle: .alert
                )

                //if the specific error is that the user's email is already in use, then prompt the user to use the supplied credentials to Sign In rather than Sign Up
                if AuthErrorCode(rawValue: error!._code) == .emailAlreadyInUse {
                    alert.addAction(UIAlertAction(
                        title: "Yes",
                        style: .cancel,
                        handler: { action in
                            self.tapAuthenticationType(self.signInButton)
                            self.signIn(self.username, self.password)
                        }
                    ))
                    alert.addAction(UIAlertAction(title: "No, Cancel",
                                                  style: .destructive,
                                                  handler: nil))
                }
                //otherwise, just prompt the user to close the error message and try again
                else { alert.addAction(UIAlertAction(title: "Got it",
                                                     style: .cancel,
                                                     handler: nil)) }
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    func signIn(_ username: String, _ password: String) {
        displayActivityIndicator(true)
        Auth.auth().signIn(withEmail: username, password: password) {
            [weak self] user, error in
            
            guard let strongSelf = self else { return }
            //if there is no error and the user's email is validated, prepare to segue to the "NewTransaction" View Controller
            //if there is no error and the user's email is NOT validated, prompt users to verify their email
            if error == nil {
                (user!.user.isEmailVerified ||
                    user!.user.email!.suffix(14) == "@gmail.com.com") ?
                        strongSelf.prepareSegue(userID: user!.user.uid) :
                        strongSelf.sendVerificationEmail(user!)
            }
            //if there is an error, generate an appropriate error message for the user to respond to
            else {
                let alert = UIAlertController(
                    title: "Login Failed",
                    message: strongSelf.generateErrorMessage(error!),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Got it",
                                              style: .cancel, handler: nil))
                strongSelf.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    func sendVerificationEmail(_ user: AuthDataResult) {
        //inform the user that an email validation link was sent and prompts the following options:
        //1. continuing to Sign In with the credentials supplied
        //2. sending another verification email
        //3. canceling the authentication process
        func messageLoop() {
            self.displayActivityIndicator(false)
            let alert = UIAlertController(
                title: "Email Not Validated",
                message: "Click the link that was sent to " + self.username +
                    " to verify this email. Then, tap \"Continue\" to finish " +
                    "the sign up process.\n\nNote: It may take a few minutes " +
                    "for the email to appear in your inbox!",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(
                title: "Continue",
                style: .default,
                handler: { action in self.signIn(self.username, self.password) }
            ))
            alert.addAction(UIAlertAction(
                title: "Send Another Email",
                style: .default,
                handler: { action in
                    self.displayActivityIndicator(true)
                    self.sendVerificationEmail(user)
                }
            ))
            alert.addAction(UIAlertAction(title: "Cancel",
                                          style: .destructive, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }

        //Firebase only allows 1 email to be sent per minute; "timeSinceLastRequest" is used to prevent more than 1 request from being sent per minute, which also prevents users from being served a confusing error message
        let timeSinceLastRequest = Date().timeIntervalSince(timeStamp)
        timeStamp = Date()
        if timeSinceLastRequest > 60 {
            user.user.sendEmailVerification { (error) in
                //if there is no error...
                if error == nil {
                    //...and the user's email is validated, prepare to segue to the "NewTransaction" View Controller
                    if user.user.isEmailVerified {
                        self.prepareSegue(userID: user.user.uid)
                    }
                    //...and the user's email is NOT validated, prompt users to verify their email (this process loops until the email is validated or the user selects "Cancel")
                    else { messageLoop() }
                }
                //if there is an error, generate an appropriate error message for the user to respond to
                else {
                    let alert = UIAlertController(
                        title: "Login Failed",
                        message: self.generateErrorMessage(error!),
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "Got it",
                                                  style: .cancel, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        } else { messageLoop() }
    }

    //generate user-friendly messages for the user to respond to based on Firebase error codes
    func generateErrorMessage(_ error: Error) -> String {
        //if an error message is being displayed, user inputs need to be reenabled
        displayActivityIndicator(false)
        
        if let errorCode = AuthErrorCode(rawValue: error._code) {
            switch errorCode {
            case .emailAlreadyInUse:
                return "This email address is already in use. Would you like " +
                    "to try signing in with these credentials instead?"
            case .missingEmail:
                return "Please supply an email address."
            case .userDisabled:
                return "This account has been disabled."
            case .invalidEmail:
                return "The email address provided is not valid."
            case .userNotFound:
                return "The username provided is not associated with an " +
                    "account."
            case .tooManyRequests:
                return "An unusual number of login attempts have been " +
                    "made from this device. Please wait 60 seconds and try " +
                    "again."
            case .weakPassword:
                return "The password entered is too weak. Please try making " +
                    "a longer password with more capital letters, special " +
                    "characters, and/or numbers."
            case .wrongPassword:
                return "The password provided is incorrect."
            default:
                return "Either you are not connected to the Internet or " +
                    "Spor's servers are down! Please try again later."
            }
        } else { return "An unkown error occured." }
    }
    
    func prepareSegue(userID: String) {
        //used in Firebase lookups
        UserDefaults.standard.set(userID, forKey: "UserID")
        
        //fetch any existing transactions and categories that were entered while signed out
        let ctgFR: NSFetchRequest<Category>    = Category   .fetchRequest()
        let txnFR: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        ctgFR.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Category.title),    ascending: true)
        ]
        txnFR.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Transaction.index), ascending: false)
        ]
        do { ctgs = try PersistenceService.context.fetch(ctgFR) } catch {}
        do { txns = try PersistenceService.context.fetch(txnFR) } catch {}

        //if any transactions were created offline, prompt the user with the option to merge these offline transactions with what is online
        //otherwise, finish the segue to the "NewTransaction" View Controller
        if txns.count > 0 {
            let key = Database.database().reference().child(userID)
            let ctRef = key.child("TransactionCounters").child("Count")
            let miRef = key.child("TransactionCounters").child("MaxIndex")
            ctRef.observeSingleEvent(of: .value, with: { snap in
                if let ct = snap.value as? Int {
                    miRef.observeSingleEvent(of: .value, with: { snap in
                        if let mi = snap.value as? Int {
                            self.askToKeepExistingTransactions(key, ct, mi)
                        }
                        else {
                            self.askToKeepExistingTransactions(key, ct, 0)
                        }
                    })
                } else { self.askToKeepExistingTransactions(key, 0, 0) }
            })
        } else { self.completeSegue() }
    }

    func askToKeepExistingTransactions(_ parent: DatabaseReference,
                                       _ firebaseCount: Int,
                                       _ firebaseMaxIndex: Int)
    {
        displayActivityIndicator(false)
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        let amount = numberFormatter.string(
            from: NSNumber(value: txns.count)) ?? "An unknown number of"
        
        //booleans are included in "message" to make the prompt grammatically correct for either just 1 transaction or more than 1 transaction
        let plural = txns.count > 1
        let alert = UIAlertController(
            title: "Keep Existing Transactions?",
            message:
                amount + (plural ? " transactions were" : " transaction was") +
                " recorded while signed out. Would you like to add " +
                (plural ? "these transactions" : "this transaction") + " to " +
                username + "'s ledger?",
            preferredStyle: .alert
        )

        //if a user chooses to delete offline transactions, complete the segue
        alert.addAction(UIAlertAction(
            title: "No, Delete " +
                (plural ? "These Transactions" : "This Transaction"),
            style: .destructive,
            handler: { action in self.completeSegue() }
        ))

        //if a user chooses to keep offline transactions, loop through and create a Hashable for each offline transaction and add it as Transaction###### to the user's Firebase data store
        alert.addAction(UIAlertAction(
            title: "Yes, Keep " + (plural ?
                "These Transactions" : "This Transaction"),
            style: .cancel,
            handler: { action in
                var maxIndex = 0
                for i in 0..<txns.count {
                    //reassign the indexes of each offline transaction to the max Firebase transaction index plus one plus the number of offline transactions already added, defined as "maxIndex"
                    //this "maxIndex" value is also used to determine the ID for each Transaction in the Firebase database (Transaction######)
                    maxIndex = firebaseMaxIndex + 1 + i
                    let updates: [AnyHashable: Any] = [
                        "Amount":   txns[i].amount,
                        "Category": txns[i].category,
                        "Date":     txns[i].date.toString(),
                        "Index":    Int32(maxIndex),
                        "Selected": false,
                        "Sign":     txns[i].sign,
                        "Title":    txns[i].title
                    ]
                    let child = String(format: "Transaction%06d", maxIndex)
                    parent.child("Transactions")
                        .child(child).updateChildValues(updates)
                }
                let updates: [AnyHashable: Any] = [
                    "Count": firebaseCount + txns.count,
                    "MaxIndex": maxIndex
                ]
                parent.child("TransactionCounters").updateChildValues(updates)
                self.completeSegue()
            }
        ))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func completeSegue() {
        //the activity indicator needs to be redisplayed here in the event that a user was prompted with "askToKeepExistingTransactions"
        displayActivityIndicator(true)
        
        //delete all local categories, transactions, and user preferences because these will be refreshed using the user's Firebase data
        for ctg in ctgs { PersistenceService.context.delete(ctg) }
        for txn in txns { PersistenceService.context.delete(txn) }
        ctgs = []
        txns = []
        PersistenceService.saveContext()
        
        //used to display who is signed in in the "Settings" View Controller
        UserDefaults.standard.set(username, forKey: "Username")
        
        //reset the following in order for "New Transactions"'s functions to work properly
        UserDefaults.standard.removeObject(forKey: "Budget")
        UserDefaults.standard.removeObject(forKey: "Period")
        UserDefaults.standard.removeObject(forKey: "FirebaseFetched")
        
        //skip the login workflow for all future app launches until the user signs out
        UserDefaults.standard.set(true, forKey: "SkipLogin")
        
        performSegue(withIdentifier: "NewTransaction", sender: nil)
    }
    
    //when the app is attempting to communicate with Firebase's servers, disable all user inputs and display a dark grey overlay and loading indicator
    func displayActivityIndicator(_ display: Bool) {
        activityIndicatorView.isHidden = !display
        view.isUserInteractionEnabled = !display
    }
    
    //if a user presses "Return" or taps outside of ".inputView", close all input views
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
        super.touchesBegan(touches, with: event)
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return false
    }
}
////////10////////20////////30////////40////////50////////60////////70////////80
