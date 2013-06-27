# ---------------------------------------------------------------------
# Step 0: Setup a database named employee using the employee_schema.sql
#         found in the respective sub-folder. Create necessary user
#         account and previleges.
# ---------------------------------------------------------------------

# ---------------------------------------------------------------------
# Step 1: Load tdao package and import dao and dbc commands
# ---------------------------------------------------------------------

package require tdao
namespace import -force tdao::dao::dao
namespace import -force tdao::dbc::dbc

# ---------------------------------------------------------------------
# Step 2: Load Database connectivity module and open a connection.
#         Un/Comment lines below as necessary
# ---------------------------------------------------------------------
set db [dbc load sqlite]
set conn [$db open [file normalize "sqlite/example.db"]]
#~ set db [dbc load postgres]
#~ set conn [$db open employee -user nagu -password Welcome123]
#~ set db [dbc load mariadb]
#~ set conn [$db open employee -user nagu -password Welcome123]

# ---------------------------------------------------------------------
# Step 3: Define Data Access Objects (DAO): address & employee
# ---------------------------------------------------------------------
puts [dao define Part \
	part {
		id
		name
		modelno
		serialno
		description
	} \
	-primarykey id \
	-autoincrement id]

puts [dao define HardDisk \
	harddisk {
		part_id
		capacity
		rpm
	} \
	-primarykey id \
	-autoincrement id \
	-inherits Part]

# ---------------------------------------------------------------------
# Step 4: Instantiate DAOs
# ---------------------------------------------------------------------
HardDisk hd1 $conn -name "harddrive" -modelno "hd0001" -serialno "INB100001" -description "blah blah" -capacity 500 -rpm 7200

Part part $conn {*}[hd1 cget dict -id -name -modelno -serialno -description]

puts "Definitions: [dao show definitions]"
puts "Instances of HardDisk: [dao show instances HardDisk]"
puts "Instances of Part: [dao show instances Part]"
puts "Fields of HardDisk: [dao show fields HardDisk]"
puts "Fields of Part: [dao show fields Part]"
puts "Values of hd1: [dao show values hd1]"
puts "Values of part: [dao show values part]"

# ---------------------------------------------------------------------
# Step 5: Clean up and close the database connection
# ---------------------------------------------------------------------
#~ dao delete object addr emp
#~ dao delete schema Address Employee

$conn close
