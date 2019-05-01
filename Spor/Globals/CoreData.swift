////////////////////////////////////////////////////////////////////////////////
import CoreData

@objc(Category)
public class Category: NSManagedObject {}
extension Category {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Category> {
        return NSFetchRequest<Category> (entityName: "Category")
    }
    @NSManaged public var budget: Double
    @NSManaged public var proportion: Double
    @NSManaged public var selected: Bool
    @NSManaged public var sign: Bool
    @NSManaged public var title: String
}

@objc(Transaction)
public class Transaction: NSManagedObject {}
extension Transaction {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Transaction> {
        return NSFetchRequest<Transaction>(entityName: "Transaction")
    }
    @NSManaged public var amount: Double
    @NSManaged public var category: String
    @NSManaged public var date: Date
    @NSManaged public var index: Int32
    @NSManaged public var selected: Bool
    @NSManaged public var sign: Bool
    @NSManaged public var title: String
}

class PersistenceService {
    private init() {}
    static var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    static var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Spor")
        container.loadPersistentStores(completionHandler: {
            (storeDescription, error) in
                if let error = error as NSError? { return }
        })
        return container
    }()
    static func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges { do { try context.save() } catch { return } }
    }
}
////////////////////////////////////////////////////////////////////////////////
