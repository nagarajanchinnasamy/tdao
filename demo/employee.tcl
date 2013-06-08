package require tdao::dao
namespace import -force tdao::dao::dao

puts [dao define Employee {f1 f2 f3 fn} -primarykey {f1 f2} -autoincrement {f1 f3} -unique {{f1 f3}}]

#~ proc save_employee {db a1 a2 a3 an} {
#~ }
#~ 
#~ set conn [tdao::conn::sqlite open a1 a2]

puts [set emp [Employee #auto conn]]

puts [Employee emp1 conn]
puts [emp1 configure -f1 val1 -f2 val2]
puts [emp1 configure]
puts [emp1 cget]
puts [emp1 cget -f1]

puts [Employee emp2 conn -f1 val1 -f2 val2]
puts [emp2 add]
puts [emp2 get]
puts [emp2 configure -f1 nval1 -f2 nval2]
puts [emp2 save]

