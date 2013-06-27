drop table if exists address;
create table address(
	id integer primary key auto_increment,
	addrline1 text not null,
	addrline2 text not null,
	city text not null,
	postalcode text not null,
	country text not null);
drop table if exists employee;
create table employee(
	id integer primary key auto_increment,
	name text not null,
	rollno text not null,
	address_id integer not null,
	foreign key(address_id) references address(id));
