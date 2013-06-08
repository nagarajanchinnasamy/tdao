package require tdao::dao
namespace import -force tdao::dao::dao

puts [dao define Employee {f1 f2 f3 fn} -primarykey {f1 f2} -autoincrement {f1 f3} -unique {{f1 f3}}]

#~ proc save_employee {db a1 a2 a3 an} {
#~ }
#~ 
#~ set conn [tdao::conn::sqlite open a1 a2]
#~ 
#~ set emp [Employee #auto $conn]
#~ 
Employee emp1 conn
#~ emp1 configure -f1 val1 -f2 val2 
#~ puts "[emp1 cget]"
#~ 
#~ Employee emp2 $conn -f1 val1 -f2 val2
#~ emp2 add
#~ emp2 get
#~ emp2 configure -f1 nval1 -f2 nval2
#~ emp2 save
#~ 
