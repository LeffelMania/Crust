import Foundation
import JSONValueRX

public enum MappingDirection {
    case fromJSON
    case toJSON
}

internal let CrustMappingDomain = "CrustMappingDomain"

public protocol Keypath: JSONKeypath { }

extension String: Keypath { }
extension Int: Keypath { }

open class MappingContext {
    open internal(set) var json: JSONValue
    open internal(set) var object: Any
    open internal(set) var error: Error?
    open internal(set) var parent: MappingContext? = nil
    open fileprivate(set) var dir: MappingDirection
    
    init(withObject object: Any, json: JSONValue, direction: MappingDirection) {
        self.dir = direction
        self.object = object
        self.json = json
    }
}

/// Method caller used to perform mappings.
public struct Mapper<T: Mapping> {
    
    public init() { }
    /*
    public func mapToAppendable<M: Mapping, C: Appendable>(from json: JSONValue, using spec: Spec<M>) throws -> C
    where M.MappedObject == C.Iterator.Element, M.MappedObject: Equatable, M.SequenceKind == C, M.MappedObject: AnyObject {
    
            var collection = C.createInstance(with: M.MappedObject.self)
            let context = MappingContext(withObject: collection, json: json, direction: MappingDirection.fromJSON)
            
            try spec.mapping.start(context: context)
            collection <- (spec, context)
            try spec.mapping.completeMapping(collection: collection, context: context)
            
            return collection
    }
    */
    public func mapToCollection<M: Mapping, C: RangeReplaceableCollection>(from json: JSONValue, using spec: Spec<M>) throws -> C
    where M.MappedObject == C.Iterator.Element, M.MappedObject: Equatable, M.SequenceKind == C {
        
        var collection = C()
        let context = MappingContext(withObject: collection, json: json, direction: MappingDirection.fromJSON)
        
        try spec.mapping.start(context: context)
        collection <*- (spec, context)
        try spec.mapping.completeMapping(collection: collection, context: context)
        
        return collection
    }
    
    public func map(from json: JSONValue, using spec: Spec<T>, parentContext: MappingContext? = nil) throws -> T.MappedObject {
        
        var object = try { () -> T.MappedObject in
            let mapping = spec.mapping
            guard let object = try mapping.getExistingInstance(json: json) else {
                return try mapping.getNewInstance()
            }
            return object
        }()
        
        let context = MappingContext(withObject: object, json: json, direction: MappingDirection.fromJSON)
        context.parent = parentContext
        try self.perform(spec, on: &object, with: context)
        
        return object
    }
    
    public func map(from json: JSONValue, using mapping: T, parentContext: MappingContext? = nil) throws -> T.MappedObject {
        let object = try { () -> T.MappedObject in
            guard let object = try mapping.getExistingInstance(json: json) else {
                return try mapping.getNewInstance()
            }
            return object
        }()
        return try map(from: json, to: object, using: mapping, parentContext: parentContext)
    }
    
    public func map(from json: JSONValue, to object: T.MappedObject, using mapping: T, parentContext: MappingContext? = nil) throws -> T.MappedObject {
        var object = object
        let context = MappingContext(withObject: object, json: json, direction: MappingDirection.fromJSON)
        context.parent = parentContext
        try self.perform(mapping, on: &object, with: context)
        return object
    }
    
    public func mapFromObjectToJSON(_ object: T.MappedObject, mapping: T) throws -> JSONValue {
        var object = object
        let context = MappingContext(withObject: object, json: JSONValue.object([:]), direction: MappingDirection.toJSON)
        try self.perform(mapping, on: &object, with: context)
        return context.json
    }
    
    internal func perform(_ mapping: T, on object: inout T.MappedObject, with context: MappingContext) throws {
        try mapping.start(context: context)
        mapping.execute(object: &object, context: context)
        try mapping.complete(object: &object, context: context)
    }
    
    internal func perform(_ spec: Spec<T>, on object: inout T.MappedObject, with context: MappingContext) throws {
        let mapping = spec.mapping
        try mapping.start(context: context)
        object <- (spec, context)
        try mapping.complete(object: &object, context: context)
    }
    /*
    internal func perform<Collection: RangeReplaceableCollection>(
        _ spec: Spec<T>,
        on collection: inout Collection,
        with context: MappingContext) throws
    where T.MappedObject == Collection.Iterator.Element, T.SequenceKind == Collection, T.MappedObject: Equatable {
        
        let mapping = spec.mapping
        try mapping.start(context: context)
        collection <- (spec, context)
        try mapping.completeMapping(collection: collection, context: context)
    }
 */
}

public extension Mapping {
    func getExistingInstance(json: JSONValue) throws -> MappedObject? {
        
        try self.checkForAdaptorBaseTypeConformance()
        
        guard let primaryKeys = self.primaryKeys else {
            return nil
        }
        
        var keyValues = [ String : CVarArg ]()
        try primaryKeys.forEach { primaryKey, jsonKey in
            let keyPath = jsonKey.keyPath
            if let val = json[keyPath] {
                keyValues[primaryKey] = val.valuesAsNSObjects()
            } else {
                let userInfo = [ NSLocalizedFailureReasonErrorKey : "Primary key of \(keyPath) does not exist in JSON but is expected from mapping \(Self.self)" ]
                throw NSError(domain: CrustMappingDomain, code: -1, userInfo: userInfo)
            }
        }
        
        let obj = self.adaptor.fetchObjects(type: MappedObject.self as! AdaptorKind.BaseType.Type, primaryKeyValues: [keyValues], isMapping: true)?.first
        return obj as! MappedObject?
    }
    
    func getNewInstance() throws -> MappedObject {
        
        try self.checkForAdaptorBaseTypeConformance()
        
        return try self.adaptor.createObject(type: MappedObject.self as! AdaptorKind.BaseType.Type) as! MappedObject
    }
    
    func delete(obj: MappedObject) throws {
        try self.checkForAdaptorBaseTypeConformance()
        
        try self.adaptor.deleteObject(obj as! AdaptorKind.BaseType)
    }
    
    internal func checkForAdaptorBaseTypeConformance() throws {
        // NOTE: This sux but `MappedObject: AdaptorKind.BaseType` as a type constraint throws a compiler error as of 7.1 Xcode
        // and `MappedObject == AdaptorKind.BaseType` doesn't work with sub-types (i.e. expects MappedObject to be that exact type)
        
        guard MappedObject.self is AdaptorKind.BaseType.Type else {
            let userInfo = [ NSLocalizedFailureReasonErrorKey : "Type of object \(MappedObject.self) is not a subtype of \(AdaptorKind.BaseType.self)" ]
            throw NSError(domain: CrustMappingDomain, code: -1, userInfo: userInfo)
        }
    }
    
    internal func start(context: MappingContext) throws {
        if context.parent == nil {
            var underlyingError: NSError?
            do {
                try self.adaptor.mappingBegins()
            } catch let err as NSError {    // We can handle NSErrors higher up.
                underlyingError = err
            } catch {
                var userInfo = [AnyHashable : Any]()
                userInfo[NSLocalizedFailureReasonErrorKey] = "Errored during mappingBegins for adaptor \(self.adaptor)"
                userInfo[NSUnderlyingErrorKey] = underlyingError
                throw NSError(domain: CrustMappingDomain, code: -1, userInfo: userInfo)
            }
        }
    }
    
    internal func endMapping(context: MappingContext) throws {
        if context.parent == nil {
            var underlyingError: NSError?
            do {
                try self.adaptor.mappingEnded()
            } catch let err as NSError {
                underlyingError = err
            } catch {
                var userInfo = [AnyHashable : Any]()
                userInfo[NSLocalizedFailureReasonErrorKey] = "Errored during mappingEnded for adaptor \(self.adaptor)"
                userInfo[NSUnderlyingErrorKey] = underlyingError
                throw NSError(domain: CrustMappingDomain, code: -1, userInfo: userInfo)
            }
        }
    }
    
    public func execute(object: inout MappedObject, context: MappingContext) {
        self.mapping(tomap: &object, context: context)
    }
    
    internal func complete(object: inout MappedObject, context: MappingContext) throws {
        try self.completeMapping(objects: [object], context: context)
        context.object = object
    }
    
    internal func completeMapping<C: Sequence>(collection: C, context: MappingContext) throws where C.Iterator.Element == MappedObject {
        try self.completeMapping(objects: collection, context: context)
        context.object = collection
    }
    
    private func completeMapping<C: Sequence>(objects: C, context: MappingContext) throws where C.Iterator.Element == MappedObject {
        if context.error == nil {
            do {
                try self.checkForAdaptorBaseTypeConformance()
                let objects = objects.map { $0 as! AdaptorKind.BaseType }
                try self.adaptor.save(objects: objects)
            } catch let error as NSError {
                context.error = error
            }
        }
        
        if let error = context.error {
            if context.parent == nil {
                self.adaptor.mappingErrored(error)
            }
            throw error
        }
        
        try self.endMapping(context: context)
    }
}
