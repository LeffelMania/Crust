import Foundation
import JSONValueRX

public enum CollectionInsertionMethod<Container: Sequence> {
    case append
    case union
    case replace(delete: ((_ orphansToDelete: Container) -> Container)?)
}

public enum Spec<T: Mapping>: Keypath {
    
    case mapping(Keypath, T)
    case collectionMapping(Keypath, T, CollectionInsertionMethod<T.SequenceKind>)
    
    public var keyPath: String {
        switch self {
        case .mapping(let keyPath, _):
            return keyPath.keyPath
        case .collectionMapping(let keyPath, _, _):
            return keyPath.keyPath
        }
    }
    
    public var mapping: T {
        switch self {
        case .mapping(_, let mapping):
            return mapping
        case .collectionMapping(_, let mapping, _):
            return mapping
        }
    }
    
    public var collectionInsertionMethod: CollectionInsertionMethod<T.SequenceKind> {
        switch self {
        case .mapping(_, _):
            return .union
        case .collectionMapping(_, _, let method):
            return method
        }
    }
}

public protocol Mapping {
    associatedtype MappedObject
    associatedtype SequenceKind: Sequence = [MappedObject]
    associatedtype AdaptorKind: Adaptor
    
    var adaptor: AdaptorKind { get }
    var primaryKeys: [String : Keypath]? { get }
    
    func mapping(tomap: inout MappedObject, context: MappingContext)
}

/// An Adaptor to use to write and read objects from a persistance layer.
public protocol Adaptor {
    /// The type of object being mapped to. If Realm then RLMObject or Object. If Core Data then NSManagedObject.
    associatedtype BaseType
    
    /// The type of returned results after a fetch.
    associatedtype ResultsType: Collection
    
    /// Called at the beginning of mapping a json blob. Good place to start a write transaction. Will only
    /// be called once at the beginning of a tree of nested objects being mapped.
    func mappingBegins() throws
    
    /// Called at the end of mapping a json blob. Good place to close a write transaction. Will only
    /// be called once at the end of a tree of nested objects being mapped.
    func mappingEnded() throws
    
    /// Called if mapping errored. Good place to cancel a write transaction. Mapping will no longer
    /// continue after this is called.
    func mappingErrored(_ error: Error)
    
    /// Fetch objects from local persistance.
    ///
    /// - parameter type: The type of object being returned by the query
    /// - parameter primaryKeyValues: An Array of of Dictionaries of primary keys to values to query. Each
    ///     Dictionary is a query for a single object with possible composite keys (multiple primary keys).
    ///
    ///     The query should have a form similar to "Dict0Key0 == Dict0Val0 AND Dict0Key1 == Dict0Val1 OR
    ///     Dict1Key0 == Dict1Val0 AND Dict1Key1 == Dict1Val1" etc. Where Dict0 is the first dictionary in the
    ///     array and contains all the primary key/value pairs to search for for a single object of type `type`.
    /// - parameter isMapping: Indicates whether or not we're in the process of mapping an object. If `true` then
    ///     the `Adaptor` may need to avoid querying the store since the returned object's primary key may be written
    ///     to if available. If this is the case, the `Adaptor` may need to return any objects cached in memory during the current
    ///     mapping process, not query the persistance layer.
    /// - returns: Results of the query.
    func fetchObjects(type: BaseType.Type, primaryKeyValues: [[String : CVarArg]], isMapping: Bool) -> ResultsType?
    
    /// Create a default object of type `BaseType`. This is called between `mappingBegins` and `mappingEnded` and
    /// will be the object that Crust then maps to.
    func createObject(type: BaseType.Type) throws -> BaseType
    
    /// Delete an object.
    func deleteObject(_ obj: BaseType) throws
    
    /// Save a set of mapped objects. Called right before `mappingEnded`.
    func save(objects: [ BaseType ]) throws
}

public protocol Transform: AnyMapping {
    func fromJSON(_ json: JSONValue) throws -> MappedObject
    func toJSON(_ obj: MappedObject) -> JSONValue
}

public extension Transform {
    func mapping(tomap: inout MappedObject, context: MappingContext) {
        switch context.dir {
        case .fromJSON:
            do {
                try tomap = self.fromJSON(context.json)
            } catch let err as NSError {
                context.error = err
            }
        case .toJSON:
            context.json = self.toJSON(tomap)
        }
    }
}

// TODO: Move into JSONValue lib.
extension NSDate: JSONable {
    public static func fromJSON(_ x: JSONValue) -> NSDate? {
        return Date.fromJSON(x) as NSDate?
    }
    
    public static func toJSON(_ x: NSDate) -> JSONValue {
        return Date.toJSON(x as Date)
    }
}
