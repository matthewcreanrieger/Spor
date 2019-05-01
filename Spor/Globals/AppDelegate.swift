////////////////////////////////////////////////////////////////////////////////
import UIKit
import Firebase

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication, didFinishLaunchingWithOptions
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        FirebaseApp.configure()
        
        self.window = UIWindow(frame: UIScreen.main.bounds)
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        self.window?.rootViewController =
            storyboard.instantiateViewController(withIdentifier:
                UserDefaults.standard.bool(forKey: "SkipLogin") == true ?
                    "NewTransaction" : "Login"
        )
        
        self.window?.makeKeyAndVisible()
        
        return true
    }
    func applicationWillResignActive   (_ application: UIApplication) {}
    func applicationDidEnterBackground (_ application: UIApplication) {}
    func applicationWillEnterForeground(_ application: UIApplication) {}
    func applicationDidBecomeActive    (_ application: UIApplication) {}
    func applicationWillTerminate      (_ application: UIApplication) {
        PersistenceService.saveContext()
    }
}
////////////////////////////////////////////////////////////////////////////////
