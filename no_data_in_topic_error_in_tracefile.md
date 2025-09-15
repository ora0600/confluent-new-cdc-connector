# Getting no data in topics, no errors visible

What I did in DB and connector
* Create Outbound Server in DB
* Stop Confluent XStream CDC connector 
* Drop Outbound Server in DB
* Create a new Outbound Server in DB
* Resume Confluent XStream CDC connector

The result was, no data were synch to Confluent Cloud Cluster, and I also do not any errors.
So, I did a deep search, were could be the problem.


Track Trace files: Trace Files are here: /opt/oracle/diag/rdbms/xe/XE/trace/
The [Oracle backgroundprocesses](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/background-processes.html) are documented and show the meaning of the shortcut: 

```bash
# LogMiner working process (Outbound)
ls -ltr XE_ms*.trc

# Capture Processes
ls -ltr XE_rp*.trc

# Check Trace files for Apply Process (Outbound)
ls -ltr XE_ap*.trc

# Check for Apply Reader (Outbound)
ls -ltr XE_as*.trc

# Check capture processs (Outbound)
ls -ltr XE_cp*.trc

# Propagation process, send LCRs (Outbound)
ls -ltr XE_cx*.trc
```

I found an Error: `more XE_cx00_2365.trc` "**Missing Streams multi-version data dictionary**". I followed instructions in trace file

Check missing Object:

```sql
select owner, object_name from dba_objects  where object_id = '3703627';
no rows selected.

select u.name owner, o.name from system.logmnr_obj$ o, user$ u
    where o.obj# = '3703627' and o.objv# = '3703627'
      and o.owner# = u.user#;

```

So, nothing found.

Check again in alert log `cat /opt/oracle/diag/rdbms/xe/XE/trace/alert_XE.log | grep XE_cx00_2365.trc`. Nothing found in Alert.log.

CHeck now: Streams Apply Process Fails With ORA-26687 or "Missing Streams multi-version data dictionary" (Doc ID 223000.1)

Check the propagazation statistics:

```sql
SELECT p.PROPAGATION_NAME,
       s.QUEUE_NAME,
       s.DBLINK,
       s.TOTAL_MSGS,
       s.TOTAL_BYTES
  FROM DBA_PROPAGATION p, V$PROPAGATION_SENDER s
  WHERE p.DESTINATION_DBLINK = s.DBLINK AND
        p.SOURCE_QUEUE_OWNER = s.QUEUE_SCHEMA AND
        p.SOURCE_QUEUE_NAME  = s.QUEUE_NAME;

SELECT APPLY_NAME,
       TOTAL_RECEIVED,
       TOTAL_APPLIED,
       TOTAL_ERRORS,
       (TOTAL_ASSIGNED - (TOTAL_ROLLBACKS + TOTAL_APPLIED)) BEING_APPLIED,
       TOTAL_IGNORED 
  FROM V$STREAMS_APPLY_COORDINATOR;
```

No rows returned.

Check rules.

```sql
PROMPT ==== Monitoring XStream Rules ====
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

```

Output looks good.

Check all states:

```sql
-- capture
select state from V$XSTREAM_CAPTURE;
-- WAITING FOR TRANSACTION = Waiting for LogMiner to provide more transactions.

-- Apply Server 
select apply_name, state from V$XSTREAM_APPLY_SERVER;
-- IDLE = Performaning no work

-- Apply Reader
select state from V$XSTREAM_APPLY_READER;
-- IDLE = Performing no work

-- Apply Coordinator
select state from V$XSTREAM_APPLY_COORDINATOR;
-- IDLE = Performing no work

-- Outbound
select state from V$XSTREAM_OUTBOUND_SERVER;
-- IDLE = Performing no work.  
```

Outbound is getting no data from Apply processes. Performing no work because there are no LCRs to send to the XStream client application.
So, why?

Data is flowing into table ORDERS:

```sql
SQL> connect ordermgmt/kafka@XEPDB1
SQL> select count(*) from ordermgmt.orders;
5354
SQL> select count(*) from ordermgmt.orders;
5365
```

Check not message Tracking:

```bash
SQL> connect sys/confluent123@XE as SYSDBA
SQL> COL COMPONENT_NAME HEADING 'XStream|Component|Name' FORMAT A15
COL COMPONENT_TYPE HEADING 'XStream|Component|Type' FORMAT A15
COL ACTION HEADING 'ACTION|on|LCR' FORMAT A15
COL ACTION_DETAILS HEADING 'ACTION|Details' FORMAT A15
COL SOURCE_DATABASE_NAME HEADING 'Source|DB' FORMAT A15
COL OBJECT_OWNER HEADING 'Obj|Owner' FORMAT A15
COL OBJECT_NAME HEADING 'Obj|Name' FORMAT A15
COL XID HEADING 'Transaction|ID' FORMAT A15
COL COMMAND_TYPE HEADING 'Command|TYPE' FORMAT A15
SELECT --TRACKING_LABEL,
       --TAG,
       COMPONENT_NAME, 
       COMPONENT_TYPE,
       ACTION,
       ACTION_DETAILS,
       --TIMESTAMP,
       MESSAGE_CREATION_TIME,
       MESSAGE_NUMBER,
       -- TRACKING_ID
       SOURCE_DATABASE_NAME,
       OBJECT_OWNER,
       OBJECT_NAME, 
       XID, 
       COMMAND_TYPE
       --MESSAGE_POSITION
from V$XSTREAM_MESSAGE_TRACKING;
#XStream         XStream         ACTION
#Component       Component       on              ACTION                                   Source          Obj             Obj             Transaction     Command
#Name            Type            LCR             Details         MESSAGE_C MESSAGE_NUMBER DB              Owner           Name            ID              TYPE
#--------------- --------------- --------------- --------------- --------- -------------- --------------- --------------- --------------- --------------- ---------------
#CONFLUENT_XOUT1 CAPTURE         Created                         09-SEP-25        3703627 XEPDB1          ORDERMGMT       ORDERS          2.1.574         INSERT
#CONFLUENT_XOUT1 CAPTURE         Enqueue                         09-SEP-25        3703627 XEPDB1          ORDERMGMT       ORDERS          2.1.574         INSERT
#XOUT            PROPAGATION SEN Dequeued                        09-SEP-25        3703627 XEPDB1          Missing MVDD:1  Missing MVDD:1  2.1.574         INSERT
#                DER+RECEIVER

#XOUT            PROPAGATION SEN Propagation rec received from l 09-SEP-25        3703627 XEPDB1          Missing MVDD:1  Missing MVDD:1  2.1.574         INSERT
#                DER+RECEIVER    eiver enqueue   ocal capture

#XOUT            PROPAGATION SEN Propagation rec Received from p 09-SEP-25        3703627 XEPDB1          Missing MVDD:1  Missing MVDD:1  2.1.574         INSERT
#                DER+RECEIVER    eiver enqueue   ropagation send
#                                                er

#XOUT            PROPAGATION SEN Rule evaluation rule evaluation 09-SEP-25        3703627 XEPDB1          Missing MVDD:1  Missing MVDD:1  2.1.574         INSERT
#                DER+RECEIVER                     cacheable, met
#                                                hod: GET_OBJECT
#                                                _OWNER

#XOUT            PROPAGATION SEN Rule evaluation positive rule s 09-SEP-25        3703627 XEPDB1          Missing MVDD:1  Missing MVDD:1  2.1.574         INSERT
#                DER+RECEIVER     filtering      et name: "C##GG
#                                                ADMIN"."RULESET
#                                                $_94"

#XOUT            PROPAGATION SEN Rule evaluation Rule evaluation 09-SEP-25        3703627 XEPDB1          Missing MVDD:1  Missing MVDD:1  2.1.574         INSERT
#                DER+RECEIVER                     completed


8 rows selected.
```

We see that we have a problem: Mulit-Version Data dictionary is missing.
The Big question is **How to fox this?**


Oracle:
Missing Streams Multi-Version Data Dictionary (Doc ID 729692.1): This is caused by the Apply related process reusing the same parallel query processes which had been used by the previous incarnation of the Apply process

Resolving the MISSING Streams Multi-version Data Dictionary Error (Doc ID 212044.1): The error "MISSING Streams multi-version data dictionary!!!" occurs when the Streams data dictionary information for the specified object is not available in the database. This message is generated at an apply site in the apply reader trace file (P000). This is an informational message. When the "Missing ...data dictionary information" message occurs, the LCR is not applied. The apply process does not disable or abort when the multi-version data dictionary information is unavailable.

# Next trail: Did I forgot to build the DD before re-creating?

I pause the connector.
I drop the outbound again.
Build Data dictionary
Re-create the outbound:

```bash

SQL> sys/confluent123@XE as sysdba
SQL> exec dbms_xstream_adm.drop_outbound('XOUT');
# Connector failed automatically
SQL> connect c##ggadmin@XE
SQL> exec DBMS_CAPTURE_ADM.BUILD;
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
      checkpoint_retention_time => 1
    );
    -- STREAM POOL SIZE should be 1024, in XE 256
    DBMS_XSTREAM_ADM.SET_PARAMETER(
    streams_type => 'capture',
    streams_name => 'confluent_xout1',
    parameter    => 'max_sga_size',
    value        => '256');
    DBMS_XSTREAM_ADM.SET_PARAMETER(
    streams_type => 'apply',
    streams_name => 'xout',
    parameter    => 'max_sga_size',
    value        => '256');
END;
/
```

And now, please restart the connector.
Connector restart failed: **The outbound server 'XOUT' is not valid. Please check if this outbound server is configured in the Oracle database.  And oracle.streams.StreamsException: ORA-26804: Apply "XOUT" is disabled.**

Restart again, maybe I was to fast with Connector Restart. Now, it is running.

And yes, this was reason. Before creating a new outbound, create the DD.

