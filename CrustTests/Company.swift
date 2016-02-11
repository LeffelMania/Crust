import Crust

class Company {
    
    required init() { }
    
    var employees = Array<Employee>()
    var uuid: String = ""
    var name: String = ""
    var foundingDate: NSDate = NSDate()
    var founder: Employee?
    var pendingLawsuits: Int = 0
}

extension Company: AnyMappable { }

class CompanyMapping : Mapping {
    
    var adaptor: MockAdaptor<Company>
    var primaryKeys: Dictionary<String, CRMappingKey>? {
        return [ "uuid" : "data.uuid" ]
    }
    
    required init(adaptor: MockAdaptor<Company>) {
        self.adaptor = adaptor
    }
    
    func mapping(inout tomap: Company, context: MappingContext) {
        let employeeMapping = EmployeeMapping(adaptor: MockAdaptor<Employee>())
        
        tomap.employees             <- KeyExtensions.Mapping("employees", employeeMapping) >*<
        tomap.founder               <- .Mapping("founder", employeeMapping) >*<
        tomap.uuid                  <- "data.uuid" >*<
        tomap.name                  <- "name" >*<
        tomap.foundingDate          <- "data.founding_date"  >*<
        tomap.pendingLawsuits       <- "data.lawsuits.pending"  >*<
        context
    }
}

class CompanyMappingWithDupes : CompanyMapping {
    
    override func mapping(inout tomap: Company, context: MappingContext) {
        let employeeMapping = EmployeeMapping(adaptor: MockAdaptor<Employee>())
        let mappingExtension = KeyExtensions.Mapping("employees", employeeMapping)
        
        tomap.employees             <- KeyExtensions.MappingOptions(mappingExtension, [ .AllowDuplicatesInCollection ]) >*<
        tomap.founder               <- .Mapping("founder", employeeMapping) >*<
        tomap.uuid                  <- "data.uuid" >*<
        tomap.name                  <- "name" >*<
        tomap.foundingDate          <- "data.founding_date"  >*<
        tomap.pendingLawsuits       <- "data.lawsuits.pending"  >*<
        context
    }
}
