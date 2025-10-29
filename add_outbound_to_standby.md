# Create Outbound on Standby

To create an outbound server in read only mode is not possible. Typically you would create a standby as dulicate from the primary where an outbound server is running. Or switch the standby  (read only) into primary role temporarly and create an outbound server then and switch back to standby.,
My assumption is to create outbound in primary and make a standby out of primary is the common setup. 
So you have an outbound server in your DR site created as desribed above (I can not test it, have no standby).

I will simulate
- First create outbound (in read-write mode)
- Stop Outbound server
- Install Startup trigger
- shutdown and startup
- outbound is running after startup

```bash
sqlplus sys/confluent123 as sysdba
SQL> connect c##ggadmin@XE
SQL> DECLARE
  tables  DBMS_UTILITY.UNCL_ARRAY;
  schemas DBMS_UTILITY.UNCL_ARRAY;
BEGIN
    tables(1)   := 'ORDERMGMT.ORDERS';
    tables(2)   := 'ORDERMGMT.ORDER_ITEMS';
    tables(3)   := 'ORDERMGMT.EMPLOYEES';
    tables(4)   := 'ORDERMGMT.PRODUCTS';
    tables(5)   := 'ORDERMGMT.CUSTOMERS';
    tables(6)   := 'ORDERMGMT.INVENTORIES';
    tables(7)   := 'ORDERMGMT.PRODUCT_CATEGORIES';
    tables(8)   := 'ORDERMGMT.CONTACTS';
    tables(9)   := 'ORDERMGMT.NOTES';
    tables(10)  := 'ORDERMGMT.WAREHOUSES';
    tables(11)  := 'ORDERMGMT.LOCATIONS';
    tables(12)  := 'ORDERMGMT.COUNTRIES';
    tables(13)  := 'ORDERMGMT.REGIONS';
    tables(14)  := NULL;
    schemas(1)  := 'ORDERMGMT';        
  DBMS_XSTREAM_ADM.CREATE_OUTBOUND(
    capture_name          =>  'confluent_xout1',
    server_name           =>  'xout',
    source_container_name =>  'XEPDB1',   
    table_names           =>  tables,
    schema_names          =>  schemas,
    comment               => 'Confluent Xstream CDC Connector' );
    -- set retention
    DBMS_CAPTURE_ADM.ALTER_CAPTURE(
      capture_name => 'confluent_xout1',
      checkpoint_retention_time => 1);
    -- STREAM POOL SIZE should be 1024, in XE 256, Capture
    DBMS_XSTREAM_ADM.SET_PARAMETER(
    streams_type => 'capture',
    streams_name => 'confluent_xout1',
    parameter    => 'max_sga_size',
    value        => '256');
    -- STREAM POOL SIZE should be 1024, in XE 256, Outbound
    DBMS_XSTREAM_ADM.SET_PARAMETER(
    streams_type => 'apply',
    streams_name => 'xout',
    parameter    => 'max_sga_size',
    value        => '256');
END;
/
## THIS

SQL> exec DBMS_XSTREAM_ADM.STOP_OUTBOUND('xout', TRUE);
SQL>PROMPT ==== Monitoring the History of Events for XStream Out Components ====
COLUMN STREAMS_NAME FORMAT A20
COLUMN PROCESS_TYPE FORMAT A17
COLUMN EVENT_NAME FORMAT A10
COLUMN DESCRIPTION FORMAT A50
COLUMN EVENT_TIME FORMAT A30
SELECT STREAMS_NAME,
       PROCESS_TYPE,
       EVENT_NAME,
       DESCRIPTION,
       EVENT_TIME
  FROM DBA_REPLICATION_PROCESS_EVENTS;
# Capture Name         PROCESS_TYPE      EVENT_NAME DESCRIPTION                                        EVENT_TIME
# -------------------- ----------------- ---------- -------------------------------------------------- ------------------------------
# XOUT                 APPLY SERVER      STOP       SUCCESS                                            29-OCT-25 12.22.36.332879 PM
# XOUT                 APPLY READER      STOP       SUCCESS                                            29-OCT-25 12.22.36.333645 PM
# CONFLUENT_XOUT1      CAPTURE SERVER    STOP       SUCCESS                                            29-OCT-25 12.22.40.670684 PM
# CONFLUENT_XOUT1      CAPTURE           STOP       SUCCESS                                            29-OCT-25 12.22.40.711567 PM
SQL> CREATE TRIGGER start_outbound
AFTER STARTUP ON DATABASE -- or DB_ROLE_CHANGE
BEGIN
     --if db_role = 'PRIMARY' then
        DBMS_XSTREAM_ADM.START_OUTBOUND('xout');
     --else
     --  DBMS_XSTREAM_ADM.STOP_OUTBOUND('xout', TRUE);
     --end if;
END start_outbound;
/
SQL> connect sys/confluent123 as sysdba
SQL> shutdown immediate
SQL> startup
# Check status of outbound
SQL> PROMPT ==== Monitoring the History of Events for XStream Out Components ====
COLUMN STREAMS_NAME FORMAT A20
COLUMN PROCESS_TYPE FORMAT A17
COLUMN EVENT_NAME FORMAT A10
COLUMN DESCRIPTION FORMAT A50
COLUMN EVENT_TIME FORMAT A30
SELECT STREAMS_NAME,
       PROCESS_TYPE,
       EVENT_NAME,
       DESCRIPTION,
       EVENT_TIME
  FROM DBA_REPLICATION_PROCESS_EVENTS;
#Capture Name         PROCESS_TYPE      EVENT_NAME DESCRIPTION                                        EVENT_TIME
#-------------------- ----------------- ---------- -------------------------------------------------- ------------------------------
#XOUT                 APPLY SERVER      STOP       SUCCESS                                            29-OCT-25 12.22.36.332879 PM
#XOUT                 APPLY READER      STOP       SUCCESS                                            29-OCT-25 12.22.36.333645 PM
#CONFLUENT_XOUT1      CAPTURE SERVER    STOP       SUCCESS                                            29-OCT-25 12.22.40.670684 PM
#CONFLUENT_XOUT1      CAPTURE           STOP       SUCCESS                                            29-OCT-25 12.22.40.711567 PM
#XOUT                 APPLY COORDINATOR START      SUCCESS                                            29-OCT-25 12.24.50.644943 PM
#CONFLUENT_XOUT1      CAPTURE           START      SUCCESS                                            29-OCT-25 12.24.50.677014 PM
#XOUT                 APPLY READER      START      SUCCESS                                            29-OCT-25 12.24.50.728495 PM
#XOUT                 APPLY SERVER      START      SUCCESS                                            29-OCT-25 12.24.50.734123 PM
#CONFLUENT_XOUT1      CAPTURE SERVER    START      SUCCESS                                            29-OCT-25 12.24.50.886101 PM  
```

Outbound Server is started automatically via Startup trigger.
The creation of Outbound Server need to better tested,. in read-only mode it did not work to create an outbound server

