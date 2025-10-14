# Create User and Tablespace for Container Based Databases

IF you follow strict the [Confluent documentation](https://docs.confluent.io/kafka-connectors/oracle-xstream-cdc-source/current/prereqs-validation.html#connect-oracle-xstream-cdc-source-prereqs-user-privileges) for setting up the XSTream Connector then you will create a user as followed:

```bash
SQL> connect sys/confluent123@XE as sysdba
# XStream Users
SQL> ALTER SESSION SET CONTAINER = CDB$ROOT;
SQL> CREATE TABLESPACE xstream_adm_tbs DATAFILE '/opt/oracle/oradata/XE/xstream_adm_tbs.dbf'
  SIZE 1M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED;
SQL> ALTER SESSION SET CONTAINER = XEPDB1;
SQL> CREATE TABLESPACE xstream_adm_tbs DATAFILE '/opt/oracle/oradata/XE/XEPDB1/xstream_adm_tbs.dbf'
  SIZE 1M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED;
# Admin
SQL> ALTER SESSION SET CONTAINER = CDB$ROOT;
SQL> CREATE USER c##cfltadmin IDENTIFIED BY password
  DEFAULT TABLESPACE xstream_adm_tbs
  QUOTA UNLIMITED ON xstream_adm_tbs
  CONTAINER=ALL;
SQL> GRANT CREATE SESSION, SET CONTAINER TO c##cfltadmin CONTAINER=ALL;
SQL> BEGIN
  DBMS_XSTREAM_AUTH.GRANT_ADMIN_PRIVILEGE(
    grantee                 => 'c##cfltadmin',
    privilege_type          => 'CAPTURE',
    grant_select_privileges => TRUE,
    container               => 'ALL');
END;
/
# Connect user
SQL> CREATE TABLESPACE xstream_tbs DATAFILE '/opt/oracle/oradata/XE/xstream_tbs.dbf'
  SIZE 1M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED;
SQL> ALTER SESSION SET CONTAINER = XEPDB1;  
SQL> CREATE TABLESPACE xstream_tbs DATAFILE '/opt/oracle/oradata/XE/XEPDB1/xstream_tbs.dbf'
  SIZE 1M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED;
SQL> ALTER SESSION SET CONTAINER = CDB$ROOT;  
SQL> CREATE USER c##cfltuser1 IDENTIFIED BY password
  DEFAULT TABLESPACE xstream_tbs
  QUOTA UNLIMITED ON xstream_tbs
  CONTAINER=ALL;
SQL> GRANT CREATE SESSION, SET CONTAINER TO c##cfltuser1 CONTAINER=ALL;
SQL> GRANT SELECT_CATALOG_ROLE TO c##cfltuser1 CONTAINER=ALL;
SQL> GRANT SELECT ANY TABLE TO c##cfltuser1 CONTAINER=ALL;
SQL> GRANT LOCK ANY TABLE TO c##cfltuser1 CONTAINER=ALL;
SQL> GRANT FLASHBACK ANY TABLE TO c##cfltuser1 CONTAINER=ALL;
```

Everything looks great. But what if yoou want to create a new PDB?
Have a look

```bash
SQL> ALTER SESSION SET CONTAINER = CDB$ROOT;  
SQL> CREATE PLUGGABLE DATABASE XEPDB2
  ADMIN USER xepdb1admin IDENTIFIED BY confluent123
  ROLES = (dba)
  FILE_NAME_CONVERT = ('/opt/oracle/oradata/XE/pdbseed/',
                       '/opt/oracle/oradata/XE/XEPDB2/')
  STORAGE (MAXSIZE 1G);
# Pluggable database created.
SQL> ALTER SESSION SET CONTAINER = XEPDB2;
SQL> ALTER PLUGGABLE DATABASE XEPDB2 OPEN;
SQL> SELECT name, open_mode from v$pdbs;
SQL> select file_name from dba_data_files;
# FILE_NAME
# --------------------------------------------------------------------------------
# /opt/oracle/oradata/XE/XEPDB2/system01.dbf
# /opt/oracle/oradata/XE/XEPDB2/sysaux01.dbf
# /opt/oracle/oradata/XE/XEPDB2/undotbs01.dbf
SQL> connect c##cfltuser1/password
SQL> show con_name
# CON_NAME
# ------------------------------
# CDB$ROOT
SQL> ALTER SESSION SET CONTAINER = XEPDB2;
# ERROR: ORA-01435: user does not exist
```

So, the main problem is without the default tablespaces the user can not exist in new PDB.

```bash
SQL> connect sys/confluent123@XE as sysdba 
SQL> ALTER SESSION SET CONTAINER = XEPDB2;  
SQL> CREATE TABLESPACE xstream_tbs DATAFILE '/opt/oracle/oradata/XE/XEPDB2/xstream_tbs.dbf'
  SIZE 1M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED;
SQL> select file_name from dba_data_files;
SQL> ALTER SESSION SET CONTAINER = CDB$ROOT;  
SQL> COL USERNAME FORMAT A13
COL ACCOUNT_STATUS FORMAT A15
COL COMMON FORMAT A8
select username, account_status, common from dba_users where username like 'C##%';
SQL> select username, account_status, common, CON_ID from CDB_users where username like 'C##%';
# all users there
SQL> ALTER SESSION SET CONTAINER = XEPDB1;
SQL> select username, account_status, common, CON_ID from CDB_users where username like 'C##%';
# all users there
SQL> ALTER SESSION SET CONTAINER = XEPDB2;
SQL> select username, account_status, common, CON_ID from CDB_users where username like 'C##%';
# no users
# SYCN PDB
SQL>  execute SYS.DBMS_PDB.SYNC_PDB;
SQL> select username, account_status, common, CON_ID from CDB_users where username like 'C##%';
# USERNAME      ACCOUNT_STATUS  COMMON       CON_ID
# ------------- --------------- -------- ----------
# C##CFLTUSER1  OPEN            YES               6
```  

So, what was the problem here? In XE you need to sync the PDBs to get common users visible in a new PDB. But we do see only the C##CFLTUSER1 because this is the only one, having the default tablespace in XEPDB2.

## Executive Summary:

Please discuss always with your DBA how to implement the samples from Confluent documentation. Maybe you have your own Tablespace structure, or need to review giving grants etc. The Confluent documentation is only one way of how it could be implemented and deployed. Each Database could be different and there are different always organizational rules implemented.
So, don't forget to discuss everything with your DBA.