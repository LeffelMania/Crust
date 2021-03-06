import Crust

class Company {
    
    required init() { }
    
    var employees = [Employee]()
    var uuid: String = ""
    var name: String = ""
    var foundingDate: Date = Date()
    var founder: Employee?
    var pendingLawsuits: Int = 0
}

extension Company: AnyMappable { }

class CompanyMapping: Mapping {
    
    var adaptor: MockAdaptor<Company>
    var primaryKeys: [Mapping.PrimaryKeyDescriptor]? {
        return [ ("uuid", "data.uuid", nil) ]
    }
    
    required init(adaptor: MockAdaptor<Company>) {
        self.adaptor = adaptor
    }
    
    func mapping(tomap: inout Company, context: MappingContext) {
        let employeeMapping = EmployeeMapping(adaptor: MockAdaptor<Employee>())
        
        tomap.employees             <- Binding.mapping("employees", employeeMapping) >*<
        tomap.founder               <- .mapping("founder", employeeMapping) >*<
        tomap.uuid                  <- "data.uuid" >*<
        tomap.name                  <- "name" >*<
        tomap.foundingDate          <- "data.founding_date"  >*<
        tomap.pendingLawsuits       <- "data.lawsuits.pending"  >*<
        context
    }
}

class CompanyMappingWithDupes: CompanyMapping {
    
    override func mapping(tomap: inout Company, context: MappingContext) {
        let employeeMapping = EmployeeMapping(adaptor: MockAdaptor<Employee>())
        
        tomap.employees             <- Binding.collectionMapping("employees", employeeMapping, (.append, true)) >*<
        tomap.founder               <- .mapping("founder", employeeMapping) >*<
        tomap.uuid                  <- "data.uuid" >*<
        tomap.name                  <- "name" >*<
        tomap.foundingDate          <- "data.founding_date"  >*<
        tomap.pendingLawsuits       <- "data.lawsuits.pending"  >*<
        context
    }
}
