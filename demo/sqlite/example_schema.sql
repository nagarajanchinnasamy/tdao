drop table if exists address;
create table address(
	id integer primary key autoincrement,
	addrline1 text not null,
	addrline2 text not null,
	city text not null,
	postalcode text not null,
	country text not null);
drop table if exists employee;
create table employee(
	id integer primary key autoincrement,
	name text not null,
	rollno text not null,
	address_id integer not null,
	foreign key(address_id) references address(id));
drop table if exists part;
create table part(
	id integer primary key autoincrement,
	name text not null,
	modelno text not null,
	serialno text not null,
	description text not null);
drop table if exists harddisk;
create table harddisk(
	id integer primary key autoincrement,
	capacity integer not null,
	rpm integer not null,
	part_id integer not null,
	foreign key(part_id) references part(id));
