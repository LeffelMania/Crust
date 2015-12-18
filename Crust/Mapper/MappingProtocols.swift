import Foundation

public struct CRMappingOptions : OptionSetType {
    public let rawValue: UInt
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    static let None = CRMappingOptions(rawValue: 0)
    static let AllowDuplicatesInCollection = CRMappingOptions(rawValue: 1)
}

public protocol Mappable { }

public protocol Mapping {
    typealias MappedObject: Mappable
    typealias AdaptorKind: Adaptor
    
    var adaptor: AdaptorKind { get }
    var primaryKeys: Array<CRMappingKey> { get }
    
    func mapping(inout tomap: MappedObject, context: MappingContext)
}

public protocol Adaptor {
    typealias BaseType
    typealias ResultsType: CollectionType
    
    func mappingBegins() throws
    func mappingEnded() throws
    func mappingErrored(error: ErrorType)
    
    func fetchObjectWithType(type: BaseType.Type, keyValues: Dictionary<String, CVarArgType>) -> BaseType?
    func fetchObjectsWithType(type: BaseType.Type, predicate: NSPredicate) -> ResultsType
    func createObject(objType: BaseType.Type) throws -> BaseType
    func deleteObject(obj: BaseType) throws
    func saveObjects(objects: [ BaseType ]) throws
}

public protocol Transform : AnyMapping {
    func fromJSON(json: JSONValue) throws -> MappedObject
    func toJSON(obj: MappedObject) -> JSONValue
}

public extension Transform {
    func mapping(inout tomap: MappedObject, context: MappingContext) {
        switch context.dir {
        case .FromJSON:
            do {
                try tomap = self.fromJSON(context.json)
            } catch let err as NSError {
                context.error = err
            }
        case .ToJSON:
            context.json = self.toJSON(tomap)
        }
    }
}

public enum KeyExtensions<T: Mapping> : CRMappingKey {
    case Mapping(CRMappingKey, T)
    indirect case MappingOptions(KeyExtensions, CRMappingOptions)
    
    public var keyPath: String {
        switch self {
        case .Mapping(let keyPath, _):
            return keyPath.keyPath
        case .MappingOptions(let keyPath, _):
            return keyPath.keyPath
        }
    }
    
    public var options: CRMappingOptions {
        switch self {
        case .MappingOptions(_, let options):
            return options
        default:
            return [ .None ]
        }
    }
    
    public func getMapping() throws -> T {
        switch self {
        case .Mapping(_, let mapping):
            return mapping
        case .MappingOptions(let mapping, _):
            return try mapping.getMapping()
        }
    }
}
