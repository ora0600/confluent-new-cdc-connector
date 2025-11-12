# Adhoc Snapshots with channel signals for new added tables to existing Confluent Oracle XStream CDC Source Connector

> [!NOTE]
> [Documentaion](https://docs.confluent.io/kafka-connectors/oracle-xstream-cdc-source/current/signals-actions.html#connect-oracle-xstream-cdc-signal-actions) for this new feature

Pre-Reqs:
* CCloud Cluster is running
* Oracle XE 21c is running

You can send signals through one or more channels, such as a **database** table or a **Kafka topic**. To configure which channels are enabled, use the signal.enabled.channels configuration property.

In my Demo I created the table during provisioning:

```bash
CREATE TABLE ordermgmt.cflt_signals (
  id VARCHAR(42) PRIMARY KEY,
  type VARCHAR(32) NOT NULL,
  data VARCHAR(2048)
);
```

I add new property in connector for signal table and decided not to do the initial load.

```json
"signal.data.collection" = "XEPDB1.ORDERMGMT.CFLT_SIGNALS"
"snapshot.mode"          = "no_data"
```

## 1. Use case: Do partly initial loads for your tables

The first use case is not to load initial data into Kafka topic. 
First I start the Outbound Server, and afterwards the Connector:

```bash 
ssh -i ~/keys/cmawsdemoxstream.pem ec2-user@X.X.X.X 
ps -ef | grep XE  # if your run 21c
# You can also check the logs
sudo tail -f /var/log/cloud-init-output.log
# log into container
sudo docker exec -it oracle21c /bin/bash
# login s SYS
sqlplus sys/confluent123@XE as sysdb
SQL> select name, log_mode, open_mode from v$database;
SQL> connect c##ggadmin@XE
# Password is Confluent12!
# Create and start Outbound Server
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
    include_ddl           =>  TRUE,
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
```

Then I start the connector, with the following parameters, so initial load:

```json
    "signal.data.collection"            = "XEPDB1.ORDERMGMT.CFLT_SIGNALS"
    "snapshot.mode"                     = "no_data"
```

The connector will only create internal topics for now. All the other topics will be created once the connector will get a change data record in LCR format. Remember, we do not do an initial load.
All components are running, and now I send the signals for a couple of look-up table to load completely with all records in those tables. For doing this you need to insert so called signals into DB table.

```bash
SQL> connect ordermgmt/kafka@XEPDB1
SQL> INSERT INTO cflt_signals (id, type, data)
VALUES (
  random_uuid(),
  'execute-snapshot',
  '{  "type": "blocking", "data-collections": ["XEPDB1.ORDERMGMT.COUNTRIES", "XEPDB1.ORDERMGMT.REGIONS", "XEPDB1.ORDERMGMT.LOCATIONS", "XEPDB1.ORDERMGMT.WAREHOUSES", "XEPDB1.ORDERMGMT.PRODUCT_CATEGORIES", "XEPDB1.ORDERMGMT.NOTES"]}'
);
SQL> commit;
```

You will see this statement in Topic `XEPDB1.ORDERMGMT.CFLT_SIGNALS` in your topic viewer in Confluent Cloud as message. It is a normal CDC topic.

Now, these Tablesmentioned into the INSERT should be loaded completely. Please check in CCloud UI Topic Viewer. Topics are created automatically and data is loaded as expected.
If you have a view into the connector log, you will see the actions behind this setting.
So, the connector got a signal and from there you will get lot of infos what is now happening: like stopping streaming etc.

Now, load the subset, so not the complete dataset of those tables.

```bash
SQL> INSERT INTO cflt_signals (id, type, data)
VALUES (
  random_uuid(), 
  'execute-snapshot',
  '{
      "type": "blocking",
      "data-collections": ["XEPDB1.ORDERMGMT.PRODUCTS","XEPDB1.ORDERMGMT.ORDER_ITEMS","XEPDB1.ORDERMGMT.ORDERS","XEPDB1.ORDERMGMT.CUSTOMERS","XEPDB1.ORDERMGMT.CONTACTS","XEPDB1.ORDERMGMT.INVENTORIES"],
      "additional-conditions": [
        {
          "data-collection": "XEPDB1.ORDERMGMT.PRODUCTS",
          "filter": "SELECT * FROM ORDERMGMT.PRODUCTS WHERE product_id=97"
        },
     {
       "data-collection": "XEPDB1.ORDERMGMT.ORDER_ITEMS",
       "filter": "SELECT * FROM ORDERMGMT.ORDER_ITEMS where product_id=97"
     },
     {
       "data-collection": "XEPDB1.ORDERMGMT.ORDERS",
       "filter": "SELECT * FROM ORDERMGMT.ORDERS where order_id=66"
     },
     {
       "data-collection": "XEPDB1.ORDERMGMT.CUSTOMERS",
       "filter": "SELECT * FROM ORDERMGMT.CUSTOMERS where customer_id=7"
     },
     {
       "data-collection": "XEPDB1.ORDERMGMT.INVENTORIES",
       "filter": "SELECT * FROM ORDERMGMT.INVENTORIES where product_id=97"
     },
     {
       "data-collection": "XEPDB1.ORDERMGMT.CONTACTS",
       "filter": "SELECT * FROM ORDERMGMT.CONTACTS where customer_id=7"
     }
      ]
    }'
);
SQL> commit;
```

Here the same, the subset was loaded as defined in the signal. Please check your topics in CCloudUI Topicviewer.

## 2. Use case: Add tables in existing Outbound Server and do ad-hoc snapshots

Create a new table first and add it to the capture process of the outbound server.

```bash
SQL> connect ordermgmt/kafka@XEPDB1
# Create table
SQL> CREATE TABLE cmtest
( id number(10) NOT NULL,
  CONSTRAINT cmtest_pk PRIMARY KEY (id)
);
SQL> connect c##ggadmin@XE
# Add table to outbound server
SQL> DECLARE
  tables  DBMS_UTILITY.UNCL_ARRAY;
  schemas DBMS_UTILITY.UNCL_ARRAY;
BEGIN
  tables(1)  := 'ordermgmt.cmtest';
  schemas(1) := NULL;
  DBMS_XSTREAM_ADM.ALTER_OUTBOUND(
    server_name           =>  'xout',
    source_container_name =>  'XEPDB1',
    table_names           =>  tables,
    schema_names          =>  schemas,
    add                   =>  true);
END;
/
# Check Views
SQL> PROMPT ==== Monitoring XStream Rules ====
COLUMN STREAMS_NAME HEADING 'XStream|Component|Name' FORMAT A15
COLUMN STREAMS_TYPE HEADING 'XStream|Component|Type' FORMAT A9
COLUMN RULE_NAME HEADING 'Rule|Name' FORMAT A13
COLUMN RULE_SET_TYPE HEADING 'Rule Set|Type' FORMAT A8
COLUMN STREAMS_RULE_TYPE HEADING 'Rule|Level' FORMAT A7
COLUMN SCHEMA_NAME HEADING 'Schema|Name' FORMAT A10
COLUMN OBJECT_NAME HEADING 'Object|Name' FORMAT A11
COLUMN RULE_TYPE HEADING 'Rule|Type' FORMAT A4
SELECT STREAMS_NAME, 
       STREAMS_TYPE,
       RULE_NAME,
       RULE_SET_TYPE,
       STREAMS_RULE_TYPE,
       SCHEMA_NAME,
       OBJECT_NAME,
       RULE_TYPE
  FROM ALL_XSTREAM_RULES;
# 
# XStream         XStream
# Component       Component Rule          Rule Set Rule    Schema     Object      Rule
# Name            Type      Name          Type     Level   Name       Name        Type
# --------------- --------- ------------- -------- ------- ---------- ----------- ----
# ....
# XOUT            APPLY     CMTEST69      POSITIVE TABLE   ORDERMGMT  CMTEST      DML
# XOUT            APPLY     CMTEST70      POSITIVE TABLE   ORDERMGMT  CMTEST      DDL

SQL> COLUMN SERVER_NAME FORMAT A15
COLUMN CAPTURE_NAME FORMAT A15
COLUMN CONNECT_USER FORMAT A20
COLUMN SOURCE_DATABASE FORMAT A20
COLUMN QUEUE_OWNER FORMAT A15
COLUMN QUEUE_NAME FORMAT A15
COLUMN PARAMETER FORMAT A40
COLUMN VALUE FORMAT A40
COLUMN STATE FORMAT A20
COLUMN TABLESPACE_NAME FORMAT A20
COLUMN FILE_NAME FORMAT A50
COLUMN CREATE_DATE FORMAT A28
COLUMN START_TIME FORMAT A28
COLUMN COMMITTED_DATA_ONLY heading "COMMITTED|DATA|ONLY" FORMAT A9
SELECT SERVER_NAME, 
       CAPTURE_NAME, 
       QUEUE_OWNER, 
       QUEUE_NAME, 
       CONNECT_USER, 
       SOURCE_DATABASE,
       STATUS,
       CREATE_DATE,
       COMMITTED_DATA_ONLY,
       START_SCN,
       START_TIME
FROM DBA_XSTREAM_OUTBOUND;
#  SERVER     CAPTURE_   QUEUE      QUEUE     CONNECT    SOURCE  STATUS   CREATE_DATE      COMMITED START  START_TIME
#  NAME   NAME           OWNER      NAME      USER        DB                               DATA    SCN
#  -----  -------------- ---------- --------- ----------- ------ -------- ---------------  -------- ------- ---------------------------- 
# XOUT    CONFLUENT_XOUT1 C##GGADMIN Q$_XOUT_1 C##GGADMIN  XEPDB1 ATTACHED 12-NOV-25 14.46  YES      3648969 12-NOV-25 02.46.22.000000 PM

SQL> COLUMN CAPTURE_NAME HEADING 'Capture|Process|Name' FORMAT A15
COLUMN STATE HEADING 'STATE' FORMAT A25
COLUMN LATENCY_SECONDS HEADING 'Latency|in|Seconds' FORMAT 999999
COLUMN LAST_STATUS HEADING 'Seconds Since|Last Status' FORMAT 999999
COLUMN CAPTURE_TIME HEADING 'Current|Process|Time'
COLUMN CREATE_TIME HEADING 'Message|Creation Time' FORMAT 999999
COLUMN TOTAL_MESSAGES_CAPTURED HEADING 'Total|captured|Messages' FORMAT 999999
COLUMN TOTAL_MESSAGES_ENQUEUED HEADING 'MessTotalage|Enqueued|Messages' FORMAT 999999
SELECT CAPTURE_NAME,
		STATE,
       ((SYSDATE - CAPTURE_MESSAGE_CREATE_TIME)*86400) LATENCY_SECONDS,
       ((SYSDATE - CAPTURE_TIME)*86400) LAST_STATUS,
       TO_CHAR(CAPTURE_TIME, 'HH24:MI:SS MM/DD/YY') CAPTURE_TIME,       
       TO_CHAR(CAPTURE_MESSAGE_CREATE_TIME, 'HH24:MI:SS MM/DD/YY') CREATE_TIME,
       TOTAL_MESSAGES_CAPTURED,
       TOTAL_MESSAGES_ENQUEUED 
  FROM gV$XSTREAM_CAPTURE;
# Capture                                   Latency               Current                                Total MessTotalage
# Process                                        in Seconds Since Process           Message           captured     Enqueued
# Name            STATE                     Seconds   Last Status Time              Creation Time     Messages     Messages
# --------------- ------------------------- ------- ------------- ----------------- ----------------- -------- ------------
# CONFLUENT_XOUT1 WAITING FOR TRANSACTION        15            15 15:10:32 11/12/25 15:10:32 11/12/25    45502          443
```

Now, change the include table list parameter in config of the connector. I use the UI of Connector in the Confluent Cloud UI.
Edit the property `table.include.list` to `ORDERMGMT[.](ORDER_ITEMS|ORDERS|EMPLOYEES|PRODUCTS|CUSTOMERS|INVENTORIES|PRODUCT_CATEGORIES|CONTACTS|NOTES|WAREHOUSES|LOCATIONS|COUNTRIES|REGIONS|CMTEST)` and click save changes.
Now, click apply changes.

Insert data into new table:

```bash

SQL> connect ordermgmt/kafka@XEPDB1
SQL> begin
      FOR X in 1..100 LOOP
        insert into cmtest values (x);
      END LOOP;
      commit;
END;
/      
SQL> SELECT Count(*) from CMTEST;
```

Send the signal for a new table and send another signal for a new table, but here we need only a subnet

```bash
INSERT INTO cflt_signals (id, type, data)
VALUES (
  random_uuid(), 
  'execute-snapshot',
  '{
      "type": "blocking",
      "data-collections": ["XEPDB1.ORDERMGMT.CMTEST"]
   }'
);
commit;
```

The Data was completely loaded again into the topic. Because our inserts from above were already cdc'ed by the connector. So, now you have 200 messages, 100 with op=c (insert) and 100 iwth op=r (Read for snapshot)
Anyway you could try the same with the tables CMTEST1 and CMTEST2

I really like this feature this is doing bring much more flexibility and you are to onboard new `unlock-data-use-cases` very easily.

Happy testing.