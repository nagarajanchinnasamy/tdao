tdao(n) 0.1.0 "Tcl Data Access Objects"
=======================================

The tdao package provides an object oriented mechanism to define and use Data Access Objects (DAOs) in a DBMS platform independent manner. A DAO definition models a table/view of a database through a list of field/column names and optional information about primary key, unique and auto-increment (or sequence) fields. A DAO instance represents a record/tuple of a table/view. DAO instances are used to manipulate ( add, get, save and delete) records of a table.

While tdao provides an object oriented mechanism to work with DAOs, it does not depend on any object oriented extensions of Tcl. Hence, the knowledge of such extensions is not necessary.

tdao package contains two sub-packages: tdao::dbc and tdao::dao.

tdao::dbc package provides methods to load a database driver and open a database connection. Using the connection handle returned by open, one can invoke record manipulation methods, transaction handling methods and a method to close the database connection. tdao::dbc supports connectivity to sqlite, postgres, mariadb database drivers.

tdao::dao package provides methods to define the schema of a table/view in a DAO definition and create and manipulate DAO instances. The interface provided by tdao::dao package is very similar to struct::record package. It just adds additional methods (add, get, save and delete) to struct::record package to manipulate records of a table/view.

With every DAO instance, a connection handle needs to be associated to enable the instance to communicate with the database when data manipulation methods add, get, save and delete are invoked. This connection can be obtained using open method of ::tdao::dbc package.

Following example gives a step-by-step illustration on how to use this package.

    #
    # Step 0: Setup a database using the example_schema.sql
    #         found in the respective sub-folder in demo folder. Create
    #         necessary user account and privileges.
    #
    # Step 1: Load tdao package and import dao and dbc commands
    #
    #
    package require tdao
    namespace import -force tdao::dao::dao
    namespace import -force tdao::dbc::dbc
    #
    # Step 2: Load Database connectivity module and open a connection.
    #         Un/Comment lines below as necessary
    #
    #
    set db [dbc load sqlite]
    set conn [$db open [file normalize "sqlite/employee.db"]]
    #~ set db [dbc load postgres]
    #~ set conn [$db open employee -user nagu -password Welcome123]
    #~ set db [dbc load mariadb]
    #~ set conn [$db open employee -user nagu -password Welcome123]
    #
    # Step 3: Define Data Access Objects (DAO): address & employee
    #
    #
    puts [dao define Address  address {
        id
        addrline1
        addrline2
        {city Bangalore}
        {postalcode 560001}
        {country India}
    } -primarykey id -autoincrement id]
    #
    #
    puts [dao define Employee  employee {
        id
        name
        rollno
        address_id
    } -primarykey id -autoincrement id]
    #
    # Step 4: Define Transactions: save_employee
    #
    #
    proc save_employee {conn op emp addr} {
      $conn begin
        switch $op {
          add {
            if {[catch {$addr add} err]} {
              $conn rollback
              return -code error $err
            }
            $emp configure -address_id [$addr cget -id]
            if {[catch {$emp add} err]} {
              $conn rollback
              return -code error $err
            }
          }
          update {
            if {[catch {$addr save} err]} {
              $conn rollback
              return -code error $err
            }
            if {[catch {$emp save} err]} {
              $conn rollback
              return -code error $err
            }          
          }
        }
      $conn commit
      return 1
    }
    #
    # Step 5: Instantiate DAOs address & employee
    #
    #
    Employee emp $conn -name "Employee Name1" -rollno "INBNG0001"
    puts "Employee before adding: [emp cget]"
    Address addr $conn  -addrline1 "Address Line 1"  -addrline2 "Address Line 2"
    puts "Address before adding: [addr cget]"
    #
    # Step 6: Add/Modify employee & address
    #
    #
    if {[catch {save_employee $conn add emp addr} err]} {
      puts "Saving employee failed...\nError: $err"
      $conn close
      exit
    }
    puts "Employee after adding: [emp cget]"
    puts "Address after adding: [addr cget]"
    # Modify and save Address object.
    addr configure  -addrline1 "Updated Address Line 1"  -addrline2 "Updated Address Line 2"  -city "Updated City Name"  -country "Updated Country Name"  -postalcode "Updated Postal Code"
    addr save
    # Check if the changes are reflected by retrieving it from database
    addr reset
    puts "Reset address: [addr cget]"
    addr configure -id [emp cget -address_id]
    addr get
    puts "Modified address: [addr cget]"
    #
    # Step 7: Clean up and close the database connection
    #
    #
    dao delete object addr emp
    dao delete definition Address Employee
    $conn close

===

Copyright

Copyright © 2013, Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
