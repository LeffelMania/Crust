import Crust

class Employee {
    
    required init() { }
    
    var employer: Company?
    var uuid: String = ""
    var name: String = ""
    var joinDate: Date = Date()
    var salary: Int = 0
    var isEmployeeOfMonth: Bool = false
    var percentYearlyRaise: Double = 0.0
}

extension Employee: AnyMappable { }

class EmployeeMapping: MockMapping {
    
    var adaptor: MockAdaptor<Employee>
    var primaryKeys: [Mapping.PrimaryKeyDescriptor]? {
        return [ ("uuid", "uuid", nil) ]
    }
    
    required init(adaptor: MockAdaptor<Employee>) {
        self.adaptor = adaptor
    }
    
    func mapping(tomap: inout Employee, context: MappingContext) {
        let companyMapping = CompanyMapping(adaptor: MockAdaptor<Company>())
        
        tomap.employer              <- .mapping("company", companyMapping) >*<
        tomap.joinDate              <- "joinDate"  >*<
        tomap.uuid                  <- "uuid" >*<
        tomap.name                  <- "name" >*<
        tomap.salary                <- "data.salary"  >*<
        tomap.isEmployeeOfMonth     <- "data.is_employee_of_month"  >*<
        tomap.percentYearlyRaise    <- "data.percent_yearly_raise" >*<
        context
    }
}
