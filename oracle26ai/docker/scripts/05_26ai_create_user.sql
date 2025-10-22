-- Create Users
ALTER SESSION SET CONTAINER = CDB$ROOT;
CREATE USER c##ggadmin IDENTIFIED BY "Confluent12!"
  DEFAULT TABLESPACE users
  QUOTA UNLIMITED ON users
  CONTAINER=ALL;
-- The following example creates a common user named c##cfltuser in a CDB
CREATE USER c##cfltuser IDENTIFIED BY "Confluent12!"
  DEFAULT TABLESPACE users
  QUOTA UNLIMITED ON users
  CONTAINER=ALL;
