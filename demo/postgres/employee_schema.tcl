-- Table: address

-- DROP TABLE address;

CREATE TABLE address
(
  id serial NOT NULL,
  addrline1 text NOT NULL,
  addrline2 text,
  city text,
  postalcode text NOT NULL,
  country text NOT NULL,
  CONSTRAINT address_pkey PRIMARY KEY (id )
)
WITH (
  OIDS=FALSE
);
ALTER TABLE address
  OWNER TO nagu;

-- Rule: get_pkey_on_insert ON address

-- DROP RULE get_pkey_on_insert ON address;

CREATE OR REPLACE RULE get_pkey_on_insert AS
    ON INSERT TO address DO  SELECT currval('address_id_seq'::regclass) AS id
 LIMIT 1;

-- Table: employee

-- DROP TABLE employee;

CREATE TABLE employee
(
  id serial NOT NULL,
  name text NOT NULL,
  rollno text NOT NULL,
  address_id integer,
  CONSTRAINT employee_pkey PRIMARY KEY (id ),
  CONSTRAINT employee_address_id_fkey FOREIGN KEY (address_id)
      REFERENCES address (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE
);
ALTER TABLE employee
  OWNER TO nagu;
