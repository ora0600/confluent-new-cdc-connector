-- connect as sysdba
CONNECT sys/confluent123 AS SYSDBA
-- enable goldengate replication
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH;
-- Enable archive log
shutdown immediate
startup mount
alter database archivelog;
alter database open;
ALTER SESSION SET CONTAINER=cdb$root;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER SESSION SET CONTAINER=XEPDB1;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
exit;