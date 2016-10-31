import XCTest
import Crust
import JSONValueRX

class CompanyMappingTests : XCTestCase {
    
    func testJsonToCompany() {
        
        let stub = CompanyStub()
        let json = try! JSONValue(object: stub.generateJsonObject())
        let mapper = CRMapper<Company, CompanyMapping>()
        let object = try! mapper.mapFromJSONToNewObject(json, mapping: CompanyMapping(adaptor: MockAdaptor<Company>()))
        
        XCTAssertTrue(stub.matches(object))
    }
    
    class MockAdaptorExistingCompany : MockAdaptor<Company> {
        var company: Company
        
        required init(withCompany company: Company) {
            self.company = company
        }
        
        override func fetchObjectsWithType(_ type: BaseType.Type, keyValues: Dictionary<String, CVarArg>) -> Array<Company> {
            return [ self.company ]
        }
    }
    
    func testUsesExistingObject() {
        
        let uuid = UUID().uuidString;
        
        let original = Company()
        original.uuid = uuid
        let adaptor = MockAdaptorExistingCompany(withCompany: original)
        
        let stub = CompanyStub()
        stub.uuid = uuid;
        let json = try! JSONValue(object: stub.generateJsonObject())
        let mapper = CRMapper<Company, CompanyMapping>()
        let object = try! mapper.mapFromJSONToExistingObject(json, mapping: CompanyMapping(adaptor: adaptor))
        
        XCTAssertTrue(object === original)
        XCTAssertTrue(stub.matches(object))
    }
    
    func testNilOptionalNilsRelationship() {
        let uuid = UUID().uuidString;
        
        let original = Company()
        original.uuid = uuid
        original.founder = Employee()
        
        let adaptor = MockAdaptorExistingCompany(withCompany: original)
        
        let stub = CompanyStub()
        stub.uuid = uuid;
        stub.founder = nil;
        let json = try! JSONValue(object: stub.generateJsonObject())
        let mapper = CRMapper<Company, CompanyMapping>()
        let object = try! mapper.mapFromJSONToExistingObject(json, mapping: CompanyMapping(adaptor: adaptor))
        
        XCTAssertTrue(stub.matches(object))
        XCTAssertNil(object.founder)
    }
}
