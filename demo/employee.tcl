package require tdao
namespace import -force tdao::dao::dao
namespace import -force tdao::gdbc::gdbc

puts [dao define Address {
	id
	addrline1
	addrline2
	city
	postalcode
	country
} -primarykey id -autoincrement id]

#~ set db [gdbc load sqlite]
#~ $db open conn [file normalize "sqlite/employee.db"]
set db [gdbc load postgres]
$db open employee -user nagu -password Welcome123

puts [set addr [Address #auto conn]]

puts [Address addr1 conn]
puts [addr1 configure \
	-addrline1 "AddressLine1" \
	-addrline2 "AddressLine2" \
	-city "MyCity" \
	-postalcode "0000000" \
	-country "India"]
puts [addr1 configure]
puts [addr1 cget]
puts [addr1 add]
puts [addr1 cget -id]

puts [Address addr2 conn \
	-addrline1 "AddressLine1" \
	-addrline2 "AddressLine2" \
	-city "MyCity" \
	-postalcode "0000000" \
	-country "India"]
puts [addr2 add]
puts [addr2 configure \
	-addrline1 "NewAddressLine1" \
	-addrline2 "NewAddressLine2" \
	-city "NewMyCity" \
	-postalcode "0000000" \
	-country "India"]
puts [addr2 save]

Address addr3 conn -id [addr2 cget -id]
addr3 get
puts [addr3 cget]

conn close
