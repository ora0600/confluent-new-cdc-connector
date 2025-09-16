# Playing around with Offsets and see what is happening

We will change SCN, LCR via Offset API call (OR Confluent Cloud UI) and change Outbound Server settings. Too see what is happening in the cluster.

As we all know the Oracle XStream CDC Connector from Confluent, is a combination of the Xstream solution in Oracle DB and a Connector Client from Confluent. Together this is reliable solution for doing Oracle CDC to Confluent Cluster.

> [!IMPORTANT]
> It is very important to know, that you can only go back to the point of position of the low-watermark transaction processed by the Xtsream outbound server. You will get this information out of the view [ALL_XSTREAM_OUTBOUND_PROGRESS](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/ALL_XSTREAM_OUTBOUND_PROGRESS.html). The LCR or SCN possition must be higher. Once the LCRs are processed, and you will set the new offset lower then position of the low-watermark transaction processed you will get this error: **ORA-21560: argument last_position is null, invalid, or out of range.** If you have other cases, the offset update will become more complex, then you need to drop and create new outbound server.

Prereqs:
* Confluent cloud cluster is running
* Oracle DB 19c or XE 21c is running
* Outbound Server is running in DB
* run the order insert procedure
* fully-Managed CDC XStream Connector is running

**Table of Contents**
1. [SCN Management](#1-scn-management)
2. [Get SCNs from Database](#2-get-scns-from-database)
3. [LCR Auditing](#3-lcr-auditing)
4. [Use case: Connector maintenance](#4-use-case-connector-maintenance)   
5. [Use case: DB aborted 45 minutes ago, DBA would like to go back for 1 hour with Connector](#5-use-case-db-aborted-45-minutes-ago-dba-would-like-to-go-back-for-1-hour-with-connector)
6. [Shutdown abort the databsse](#6-shutdown-abort-the-database)


## 1. SCN Management

The primary function of the redo log is to record all changes made to the database.
A capture process is an optional Oracle background process that scans the database redo log to capture DML and DDL changes made to database objects. 
A capture process reformats changes captured from the redo log into LCRs. An LCR is an object with a specific format that describes a database change. A capture process captures two types of LCRs: row LCRs and DDL LCRs. 
Supplemental logging places additional column data into a redo log whenever an operation is performed. A capture process captures this additional information and places it in LCRs. 
System change number (SCN) values are very important for a capture process. You can query the [ALL_CAPTURE](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/ALL_CAPTURE.html) data dictionary view to display these values for one or more capture processes.

We do have 4 main SCNs to cover

* **First SCN**: The first SCN is the lowest SCN in the redo log from which a capture process can capture changes. If you specify a first SCN during capture process creation, then the database must be able to access redo log information from the SCN specified and higher. 
* **Start SCN**: The start SCN is the SCN from which a capture process begins to capture changes. You can specify a start SCN that is different than the first SCN during capture process creation, or you can alter a capture process to set its start SCN. The start CN does not need to be modified for normal operation of a capture process. If you want to switch the start offset/SCN then you can not be lower then the FIRST_SCN for a running capture process.
* **Captured SCN**: is the SCN that corresponds to the most recent change scanned in the redo log by a capture process. The applied SCN for a capture process is equivalent to the low-watermark SCN for an apply process that applies changes captured by the capture process.
* **Applied SCN**: for a capture process is the SCN of the most recent event dequeued by the relevant apply processes. All events lower than this SCN have been dequeued by all apply processes that apply changes captured by the capture process. 

## 2. Get SCNs from Database

Get all SCN from Capture Process:

```bash
sqlplus c##ggadmin@orclcdb
SQL> SET LINES 400
col CAPTURE_NAME heading '|capture|name' format a15
col CAPTURE_USER heading '|capture|user' format a15
col STATUS format a15
col FIRST_SCN heading '|first|SCN' format 9999999
col START_SCN heading '|start|SCN' format 9999999
col CAPTURED_SCN heading '|captured|SCN' format 9999999
col APPLIED_SCN heading '|applied|SCN' format 999999999999999999
col MAX_CHECKPOINT_SCN heading 'max|checkpoint|SCN' format 9999999
col REQUIRED_CHECKPOINT_SCN heading 'required|checkpoint|SCN' format 9999999
COLUMN LAST_ENQUEUED_SCN heading 'LAST|ENQUEUED|SCN' FORMAT 9999999
COLUMN OLDEST_SCN heading '|OLDEST|SCN' FORMAT 9999999
COLUMN FILTERED_SCN heading '|FILTERED|SCN' FORMAT 9999999
COLUMN QUEUE_NAME heading '|QUEUE|NAME' FORMAT A15
COLUMN CLIENT_STATUS heading '|CLIENT|STATUS' FORMAT A15
select capture_name, 
       QUEUE_NAME, 
       status, 
       client_status, 
       FIRST_SCN,
       START_SCN, 
       CAPTURED_SCN, 
       APPLIED_SCN,  
       MAX_CHECKPOINT_SCN, 
       REQUIRED_CHECKPOINT_SCN, 
       LAST_ENQUEUED_SCN, 
       OLDEST_SCN, 
       FILTERED_SCN
      from all_capture where CAPTURE_NAME= 'CONFLUENT_XOUT1';

#                                                                                                                      max   required     LAST
#capture         QUEUE                           CLIENT             first    start captured             applied checkpoint checkpoint ENQUEUED   OLDEST FILTERED
#name            NAME            STATUS          STATUS               SCN      SCN      SCN                 SCN        SCN        SCN      SCN      SCN      SCN
#--------------- --------------- --------------- --------------- -------- -------- -------- ------------------- ---------- ---------- -------- -------- --------
#CONFLUENT_XOUT1 Q$_XOUT_1       ENABLED         ATTACHED         3656175  3656175  3708883             3706012    3698041    3693862           3658133        0

```      

The DBMS_CAPTURE_ADM.BUILD procedure extracts the source database data dictionary to the redo log. When you create a capture process, you can specify a first SCN that corresponds to this data dictionary build in the redo log. 
Specifically, the first SCN for the capture process being created can be set to any value returned by the following query:

```bash
sqlplus c##ggadmin@orclcdb
SQL> COLUMN FIRST_CHANGE# HEADING 'First SCN' FORMAT 999999999
COLUMN NAME HEADING 'Log File Name' FORMAT A50
SELECT DISTINCT FIRST_CHANGE#, NAME FROM V$ARCHIVED_LOG
  WHERE DICTIONARY_BEGIN = 'YES';
# First SCN Log File Name
# ---------- -----------------------------------------------------------
#    3656175 /opt/oracle/homes/OraDBHome21cXE/dbs/arch1_7_1143830636.dbf
```

As you see our **FIRST_SCN=3656175** are for capture and registered log the same. This is vrey good.

The value returned for the NAME column is the name of the redo log file that contains the SCN corresponding to the first SCN. This redo log file, and subsequent redo log files, must be available to the capture process. If this query returns multiple distinct values for FIRST_CHANGE#, then the DBMS_CAPTURE_ADM.BUILD procedure has been run more than once on the source database. In this case, choose the first SCN value that is most appropriate for the capture process you are creating.
In some cases, the `DBMS_CAPTURE_ADM.BUILD` procedure is run automatically when a capture process is created, e.g. with during a `DBMS_XSTREAM_ADM.CREATE_OUTBOUND` call. When this happens, the first SCN for the capture process corresponds to this data dictionary build. We seen situation where this is not happen. I call it invisible error then. Please follow this [guide](https://github.com/ora0600/confluent-new-cdc-connector/blob/main/no_data_in_topic_error_in_tracefile.md) if you see no errors, but no data is synched. In most cases you can fix this with a `DBMS_CAPTURE_ADM.BUILD` call.

Start SCN Must Be Greater Than or Equal to First SCN. Oracle Corporation recommends that the difference between the first_SCN and start_SCN be as small as possible during capture process creation to keep the initial capture process startup time to a minimum.

## 3. LCR Auditing

this chapter is optional. Only for demo cases.

> [!IMPORTANT]
> LCR position data is very complex to deal with and could generate lot of errors. The Confluent Connector should always use SCN instead of LCR position for offset management.


I did prepare in DB an LCR Position (Logical change record) Auditing demo solution. The last processed LCR Position value can be find in a couple of DB Views like [ALL_XSTREAM_OUTBOUND_PROGRESS](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/ALL_XSTREAM_OUTBOUND_PROGRESS.html). But older LCR positions are not stored. So, an update of the connector offset with a LCR one hour back is not easy to serve because of missing information.
The database view `V$XSTREAM_OUTBOUND_SERVER` shows the last processed LCR position too and much more data. I did prepare a simple audit solution, which stores every 5 second the record into my new audit table.
Please install it in DB under `C##GGADMIN` User the followong audit solution:

```sql
-- Auditing sample for LCR Auditing
-- Sequence for PK
CREATE SEQUENCE confluent_xstream_lcr_auditing_seq START WITH 1 INCREMENT BY   1 NOCACHE NOCYCLE;
-- Audit Table
create table confluent_xstream_lcr_auditing 
   (ID NUMBER DEFAULT confluent_xstream_lcr_auditing_seq.nextval,
    SERVER_NAME VARCHAR2(128), 
	STARTUP_TIME DATE, 
	STATE VARCHAR2(19), 
	TRANSACTION VARCHAR2(128), 
	COMMITSCN NUMBER, 
	TOTAL_TRANSACTIONS_SENT NUMBER, 
	MESSAGE_SEQUENCE NUMBER, 
	TOTAL_MESSAGES_SENT NUMBER, 
	SEND_TIME DATE, 
	LAST_SENT_MESSAGE_NUMBER NUMBER, 
	LAST_SENT_MESSAGE_CREATE_TIME DATE, 
	LAST_SENT_POSITION RAW(64), 
	 PRIMARY KEY (ID)
);

set serveroutput on;

-- track LCRs every 5 seconds, as a sample for one hour
-- track LCRs every 5 seconds, as a sample for one hour
create or replace procedure lcr_auditing_outbound (p_server_name varchar2) as
  L_SERVER_NAME VARCHAR2(128); 
  L_STARTUP_TIME DATE; 
  L_STATE VARCHAR2(19); 
  L_TRANSACTION VARCHAR2(128); 
  L_COMMITSCN NUMBER;
  L_TOTAL_TRANSACTIONS_SENT NUMBER; 
  L_MESSAGE_SEQUENCE NUMBER;
  L_TOTAL_MESSAGES_SENT NUMBER; 
  L_SEND_TIME DATE;
  L_LAST_SENT_MESSAGE_NUMBER NUMBER; 
  L_LAST_SENT_MESSAGE_CREATE_TIME DATE; 
  L_LAST_SENT_POSITION RAW(64);
begin
  FOR x in 1..720 LOOP -- 720 * 5 sec wait = 1h
    begin
    select server_name, 
       startup_time, 
       state, 
       XIDUSN||'.'||XIDSLT||'.'||XIDSQN , 
       commitscn, 
       TOTAL_TRANSACTIONS_SENT, 
       MESSAGE_SEQUENCE, 
       TOTAL_MESSAGES_SENT, 
       SEND_TIME,
       LAST_SENT_MESSAGE_NUMBER,
       LAST_SENT_MESSAGE_CREATE_TIME,
       LAST_SENT_POSITION
    into L_SERVER_NAME,
       L_STARTUP_TIME,
       L_STATE , 
       L_TRANSACTION ,
       L_COMMITSCN ,
       L_TOTAL_TRANSACTIONS_SENT,
       L_MESSAGE_SEQUENCE,
       L_TOTAL_MESSAGES_SENT ,
       L_SEND_TIME ,
       L_LAST_SENT_MESSAGE_NUMBER ,
       L_LAST_SENT_MESSAGE_CREATE_TIME ,
       L_LAST_SENT_POSITION 
    from V$XSTREAM_OUTBOUND_SERVER
    where server_name = p_server_name;
    dbms_output.put_line(L_LAST_SENT_POSITION);
    -- Insert into audit table
	insert into  confluent_xstream_lcr_auditing
	   (SERVER_NAME , 
	    STARTUP_TIME , 
	    STATE , 
	    TRANSACTION, 
	    COMMITSCN , 
	    TOTAL_TRANSACTIONS_SENT , 
	    MESSAGE_SEQUENCE , 
	    TOTAL_MESSAGES_SENT , 
	    SEND_TIME , 
	    LAST_SENT_MESSAGE_NUMBER , 
	    LAST_SENT_MESSAGE_CREATE_TIME , 
	    LAST_SENT_POSITION ) values
		(L_SERVER_NAME , 
	    L_STARTUP_TIME , 
	    L_STATE , 
	    L_TRANSACTION, 
	    L_COMMITSCN , 
	    L_TOTAL_TRANSACTIONS_SENT , 
	    L_MESSAGE_SEQUENCE , 
	    L_TOTAL_MESSAGES_SENT , 
	    L_SEND_TIME , 
	    L_LAST_SENT_MESSAGE_NUMBER , 
	    L_LAST_SENT_MESSAGE_CREATE_TIME , 
	    L_LAST_SENT_POSITION);
		commit;
    exception when others then 
      NULL;
    end;
    -- wait for 5 secs
    dbms_lock.sleep(5);
  END LOOP;
end;
/

-- run auditing
begin
 lcr_auditing_outbound('XOUT');
end;
/
```

Now you can check the table which LCR positions were send to Confluent Cloud Cluster.

```sql
sqlplus c##ggadmin@orclcdb
--current date
SQL> !date
-- check the audit table
SQL> set linesize 200
-- check auditing
SQL> select COMMITSCN, 
       LAST_SENT_POSITION, 
       to_char(send_time,'DD.MM.YY HH24:MI:SS') as send_time
 from  confluent_xstream_lcr_auditing order by 3;

-- 1 hour agao
SQL> select COMMITSCN, 
       LAST_SENT_POSITION, 
       to_char(send_time,'DD.MM.YY HH24:MI:SS') as send_time 
  from confluent_xstream_lcr_auditing 
 where trunc(send_time) < SYSDATE - INTERVAL '1' HOUR 
   and rownum = 1;
```

Now, we know past SCNs and LCR positions to play around with offset API.

Remember: Confluent Offset management is described [here](https://docs.confluent.io/cloud/current/connectors/cc-oracle-xstream-cdc-source/cc-oracle-xstream-cdc-source.html#limitations).
In Oracle XStream, a custom offset reset refers to resetting the SCN (snapshot phase offset data) or lcr_position (streaming phase offset data).

The general way to reset offset would be:

1. Offset Discovery - Identify the SCN (lcr_position not recommend) to reset the offset value in connect-offsets topic.
2. Offset Reset - Reset the offset value in the connect-offsets topic.
3. Restart/Start - Use snapshot.mode = initial/ no_data and (re)start the connector.

## 4. Use case: Connector maintenance

You can pause the connector via API or UI. We will do with API, this is easier to follow.
For this case, we will pause our connector and in parallel transactions are executed in Database.

1. Pause Connector:

```Bash
# Create ccloud API Keys
confluent login
confluent api-key create --resource cloud
echo -n "KEY:SECRET" | base64
# base64
# get connectors
curl --request GET 'https://api.confluent.cloud/connect/v1/environments/env-pwpxp2/clusters/lkc-07zwx5/connectors' \
--header 'authorization: Basic base64' | jq
# pause connector 
curl --request PUT 'https://api.confluent.cloud/connect/v1/environments/env-pwpxp2/clusters/lkc-07zwx5/connectors/OracleXStreamSourceConnector_0/pause' \
--header 'Authorization: Basic base64' | jq
# show status
curl --request GET \
  --url 'https://api.confluent.cloud/connect/v1/environments/env-pwpxp2/clusters/lkc-07zwx5/connectors/OracleXStreamSourceConnector_0/status' \
  --header 'Authorization: Basic base64' | jq
```

In parallel transaction are executed in DB. First get the position of the low-watermark transaction processed by the Xtsream outbound server:

```bash
sqlplus c##ggadmin@orclcdb
SQL> select PROCESSED_LOW_POSITION,
         to_char(PROCESSED_LOW_TIME,'DD.MM.YYYY HH24:MI:SS') as PROCESSED_LOW_TIME,
         PROCESSED_LOW_SCN
    from ALL_XSTREAM_OUTBOUND_PROGRESS where server_name = 'XOUT';

#PROCESSED_LOW_POSITION                                                                                      PROCESSED_LOW_TIME  PROCESSED_LOW_SCN
#-------------------------------------------------------------------------------------------------------------------------------- -------------------
#0000000000389E0800000000000000000000000000389E08000000000000000002                                          15.09.2025 12:42:35            3710472
```

so the last time data were send to the Confluent Cloud Connector was `15.09.2025 12:42:35`.

Insert some records into DB tables sycned with our connector:

```bash
sqlplus ordermgmt/kafka@orclpdb1
SQL> insert into regions (region_name) values ('TEST2');
SQL> commit;
SQL> insert into regions (region_name) values ('TEST2');
SQL> commit;
SQL> !date
# Mon Sep 15 12:50:59 UTC 2025

# and check again the last SCN
sqlplus c##ggadmin@orclcdb
SQL> select PROCESSED_LOW_POSITION,
         to_char(PROCESSED_LOW_TIME,'DD.MM.YYYY HH24:MI:SS') as PROCESSED_LOW_TIME,
         PROCESSED_LOW_SCN
    from ALL_XSTREAM_OUTBOUND_PROGRESS where server_name = 'XOUT';
#PROCESSED_LOW_POSITION                                                                                      PROCESSED_LOW_TIME  PROCESSED_LOW_SCN
#-------------------------------------------------------------------------------------------------------------------------------- -------------------
#0000000000389E0800000000000000000000000000389E08000000000000000002                                          15.09.2025 12:42:35            3710472
```

So, the SCN is now **3710472** the time is the same then first query execution. 
We need to be one higher, so will update the connector offset to **3710473**.
Now, the connector maintenance is finished, and we update the the offset and resume the connector via API call.

```bash
# status conenctor
curl --request GET \
  --url 'https://api.confluent.cloud/connect/v1/environments/env-pwpxp2/clusters/lkc-07zwx5/connectors/OracleXStreamSourceConnector_0/status' \
  --header 'Authorization: Basic base64' | jq
# update the offset to the last LCR
curl --request POST \
  --url 'https://api.confluent.cloud/connect/v1/environments/env-pwpxp2/clusters/lkc-07zwx5/connectors/OracleXStreamSourceConnector_0/offsets/request' \
  --header 'Authorization: Basic base64' \
  --header 'content-type: application/json' \
  --data '{"type":"PATCH","offsets":[{"partition":{"server": "ORCLPDB1"},"offset":{"scn": "3710473"}}]}'
# Resume
curl --request PUT \
  --url 'https://api.confluent.cloud/connect/v1/environments/env-pwpxp2/clusters/lkc-07zwx5/connectors/OracleXStreamSourceConnector_0/resume' \
  --header 'Authorization: Basic base64'
# status conenctor
curl --request GET \
  --url 'https://api.confluent.cloud/connect/v1/environments/env-pwpxp2/clusters/lkc-07zwx5/connectors/OracleXStreamSourceConnector_0/status' \
  --header 'Authorization: Basic base64' | jq
```

So, the missing data in regions was synched successfully. But it could be that the connector throws an error:

```bash
Failure:
An exception occurred in the change event producer. This connector will be stopped.

Caused By:
ORA-21560: argument last_position is null, invalid, or out of range.
```

So, remember we changed to SCN `3710473` 
The current DB SCN situation was as followed:

```bash
# CAPTURE SCNs
# ============
#                                                                                                                      max   required     LAST
#capture         QUEUE                           CLIENT             first    start captured             applied checkpoint checkpoint ENQUEUED   OLDEST FILTERED
#name            NAME            STATUS          STATUS               SCN      SCN      SCN                 SCN        SCN        SCN      SCN      SCN      SCN
#--------------- --------------- --------------- --------------- -------- -------- -------- ------------------- ---------- ---------- -------- -------- --------
#CONFLUENT_XOUT1 Q$_XOUT_1       ENABLED         ATTACHED         3656175  3656175  3708883             3706012    3698041    3693862           3658133        0

# REDOLOG SCNs
# ============
# First SCN Log File Name
# ---------- -----------------------------------------------------------
#    3656175 /opt/oracle/homes/OraDBHome21cXE/dbs/arch1_7_1143830636.dbf
```

First SCN `3656175` is always lower than `3710473`. So, Everything looks fine.
But, if you got such an error, I do change the scn a bit higher step by step. So, I would try next with `3710474`.

### With CP the process would look like this:

```bash
# start connect
docker-compose -f docker-compose-cdc-ccloud_new.yml up -d
# start connector
# Are connectors running?
curl -s -X GET -H 'Content-Type: application/json' http://localhost:8083/connectors | jq
# start connector with correct json config
curl -s -X POST -H 'Content-Type: application/json' --data @cdc_ccloud.json http://localhost:8083/connectors | jq
# Check status
curl -s -X GET -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/status | jq
```

Topics are created, initial load done, and orders are synced.
Now, I pause the CP Connector

```bash
# We need to stop with CP 
curl -s -X PUT -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/stop | jq
# Check status
curl -s -X GET -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/status | jq
```

The lowest SCN is now:

```bash
# and check again the last SCN
sqlplus c##ggadmin@orclcdb
SQL> select PROCESSED_LOW_POSITION,
         to_char(PROCESSED_LOW_TIME,'DD.MM.YYYY HH24:MI:SS') as PROCESSED_LOW_TIME,
         PROCESSED_LOW_SCN
    from ALL_XSTREAM_OUTBOUND_PROGRESS where server_name = 'XOUT';
#PROCESSED_LOW_POSITION                                                                                      PROCESSED_LOW_TIME  PROCESSED_LOW_SCN
#-------------------------------------------------------------------------------------------------------------------------------- -------------------
#0000000000389E0800000000000000000000000000389E08000000000000000002                                          15.09.2025 12:42:35            3710472
```

We got lowest SCN of `3710472` and I will set offset to `3710473`. We do change the offset and resume.

```bash
# Update 
curl -s -X PATCH -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/offsets \
--data '{"offsets":[{"partition":{"server": "ORCLPDB1"},"offset":{"scn": "3710473"}}]}' || jq
#RESUME
curl -s -X PUT -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/resume | jq
# Check status
curl -s -X GET -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/status | jq
```

If you will get this error:

```bash
oracle.streams.StreamsException: ORA-21560: argument last_position is null, invalid, or out of range
```

Increase the SCN step-by-step and then it will work.

### How to force connector to read from specified SCN?

So, we did synched missing data after last connector stop. And the offset of connector was higher then processes low position.
Remember:

```bash
select PROCESSED_LOW_POSITION,
         to_char(PROCESSED_LOW_TIME,'DD.MM.YYYY HH24:MI:SS') as PROCESSED_LOW_TIME,
         PROCESSED_LOW_SCN
    from ALL_XSTREAM_OUTBOUND_PROGRESS where server_name = 'XOUT';
#PROCESSED_LOW_POSITION                                                                                      PROCESSED_LOW_TIME  PROCESSED_LOW_SCN
#-------------------------------------------------------------------------------------------------------------------------------- -------------------
#0000000000389E0800000000000000000000000000389E08000000000000000002                                          15.09.2025 12:42:35            3710472
```

We set offset to **3710473**, so it was higher.
What if would like to set offset lower then this, so we try **3710460** instead.

* Stop/Pause Connector
* add some new regions 
* set the new offset 
* Resume Connector
* see what is happening 

Unfortunately we got the following errors in connector:

```bash
oracle.streams.StreamsException: ORA-21560: argument last_position is null, invalid, or out of range
# and 
org.apache.kafka.connect.errors.ConnectException: An exception occurred in the change event producer. This connector will be stopped.
```

To get the connnector working again, try to set an offset higher then processed low position SCN.


## 5. Use case: DB aborted 45 minutes ago, DBA would like to go back for 1 hour with Connector

Get SCN first 

```bash
SQL> select capture_name, 
            start_scn,
            captured_scn,
            applied_scn,
            max_checkpoint_scn,
            required_checkpoint_scn 
      from dba_capture;
#                                                             max   required
#capture            start captured             applied checkpoint checkpoint
#name                 SCN      SCN                 SCN        SCN        SCN
#--------------- -------- -------- ------------------- ---------- ----------
#CONFLUENT_XOUT1  3656175  3715046             3706012    3705056    3706012
SQL> select consumer_name,
       name, 
       FIRST_SCN,
       NEXT_SCN,
       DICTIONARY_BEGIN,
       DICTIONARY_END,
       PURGEABLE
from DBA_REGISTERED_ARCHIVED_LOG;
# CONSUMER_NAME      Log File Name                                                  FIRST_SCN    NEXT_SCN DIC DIC PUR
# ------------------ -------------------------------------------------------------- ---------- ---------- --- --- ---
# OGG$CAP_ORADB19C     /opt/oracle/product/19c/dbhome_1/dbs/arch1_8_1192789111.dbf    2160676   2180306    NO  NO  NO                                                                                                      
# OGG$CAP_ORADB19C     /opt/oracle/product/19c/dbhome_1/dbs/arch1_9_1192789111.dbf    2180306   2181564   YES YES  NO
# CONFLUENT_XOUT1      /opt/oracle/product/19c/dbhome_1/dbs/arch1_11_1192789111.dbf   2315882   2316067    NO  NO  NO
# CONFLUENT_XOUT1      /opt/oracle/product/19c/dbhome_1/dbs/arch1_12_1192789111.dbf   2316067   2324080   YES YES  NO

# the earliest SCN would be 
SQL> SELECT SCN_TO_TIMESTAMP(2315882) from dual;

SCN_TO_TIMESTAMP(2315882)
---------------------------------------------------------------------------
13-MAY-25 10.03.45.000000000 AM
```


If the START_FROM_SCN/start_from_lcr_position is before the outbound server’s processed low watermark position, but after the min(FIRST_CHANGE#) of the online redo log files (Reason for this: when you create a outbound server, the capture process created as part of the CREATE_OUTBOUND call has the FIRST_SCN and START_SCN set to the min(FIRST_CHANGE#) of the online redo log files.), then:

```bash
sqlplus c##ggadmin@orclcdb
# get first SCN from outbound
SQL> SELECT CAPTURE_NAME, 
            QUEUE_NAME,
            STATUS,
            START_SCN,
            to_char(START_TIME,'DD.MM.YYYY HH24:MI:SS') as START_TIME
      FROM ALL_XSTREAM_OUTBOUND 
     WHERE SERVER_NAME = 'XOUT';
# CAPTURE_NAME                   QUEUE_NAME                     STATUS      START_SCN START_TIME
# ------------------------------ ------------------------------ ---------- ---------- -------------------
# CONFLUENT_XOUT1                Q$_XOUT_11                     ATTACHED      2316067 13.05.2025 10:04:39

# get Data from Capture process
SQL> SELECT CAPTURE_NAME,
            START_SCN,
            FIRST_SCN,
            CAPTURED_SCN,
            APPLIED_SCN,
            STATUS
     from ALL_CAPTURE
    where CAPTURE_NAME ='CONFLUENT_XOUT1';
# CAPTURE_NAME                    START_SCN  FIRST_SCN CAPTURED_SCN APPLIED_SCN STATUS
# ------------------------------ ---------- ---------- ------------ ----------- ----------
# CONFLUENT_XOUT1                   2316067    2316067      2417168     2407076 ENABLED

# VALID SCNs in archived logs
SQL> SELECT NAME, FIRST_CHANGE#, NEXT_CHANGE# FROM V$ARCHIVED_LOG;
# Log File Name                                                 First SCN  NEXT_CHANGE#
# ------------------------------------------------------------- ---------- ------------
# /opt/oracle/product/19c/dbhome_1/dbs/arch1_8_1192789111.dbf    2160676      2180306
# /opt/oracle/product/19c/dbhome_1/dbs/arch1_9_1192789111.dbf    2180306      2181564
# /opt/oracle/product/19c/dbhome_1/dbs/arch1_10_1192789111.dbf   2181564      2315882
# /opt/oracle/product/19c/dbhome_1/dbs/arch1_11_1192789111.dbf   2315882      2316067
# /opt/oracle/product/19c/dbhome_1/dbs/arch1_12_1192789111.dbf   2316067      2324080

#Query to identify the valid SCN range for online redo log files
SQL> SELECT LOGFILE.MEMBER AS NAME, LOG.FIRST_CHANGE# FIRST_CHANGE#,LOG.NEXT_CHANGE# NEXT_CHANGE# 
      FROM V$LOG LOG INNER JOIN V$LOGFILE LOGFILE ON (LOG.GROUP# = LOGFILE.GROUP#);
# Log File Name                                       First SCN NEXT_CHANGE#
# -------------------------------------------------- ---------- ------------
# /opt/oracle/oradata/ORCLCDB/redo04.log                2315882      2316067
# /opt/oracle/oradata/ORCLCDB/redo05.log                2316067      2324080
# /opt/oracle/oradata/ORCLCDB/redo06.log                2324080   1.8447E+19```
```

So, our objective to move back to this time:

```bash 
 PROCESSED_LOW_TIME               LOW_SCN_OF_REDO
 -------------------------------- -----------------
 13-MAY-25 10.03.45.000000000 AM           2315882
```

This should be work fine. Move back to `2315882`.


The past time scn `2315882` is lower what we processed so far with our connector `2316067` (the data is already synched). The past time scn `2315882` is after the current capture process `START_SCN=2316067 and FIRST_SCN=2316067`. It is after the first_change# of logs.
Now, to move back into the past, because database was crashed and we want to keep the old synched again.

We need 
* Drop the existing outbound server and create a new outbound server.  Verify that the newly created capture process has the FIRST_SCN/START_SCN before the START_FROM_SCN
* Proceed to Offset Reset section.

1. I pause the connector

```Bash
# Create ccloud API Keys
# pause connector 
curl --request PUT 'https://api.confluent.cloud/connect/v1/environments/env-6810nj/clusters/lkc-jyy882/connectors/OracleXStreamSourceConnector_0/pause' \
  --header 'Authorization: Basic base64' | jq
# show status
curl --request GET \
  --url 'https://api.confluent.cloud/connect/v1/environments/env-6810nj/clusters/lkc-jyy882/connectors/OracleXStreamSourceConnector_0/status' \
  --header 'Authorization: Basic base64' | jq

or with CP
# We need to stop with CP 
curl -s -X PUT -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/stop | jq
# Check status
curl -s -X GET -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/status | jq  
```

2. Drop the Outbound Server

```Bash
sqlplus c##ggadmin@orclcdb
SQL>SELECT CAPTURE_NAME, 
            QUEUE_NAME,
            STATUS,
            START_SCN,
            to_char(START_TIME,'DD.MM.YYYY HH24:MI:SS') as START_TIME
      FROM ALL_XSTREAM_OUTBOUND 
     WHERE SERVER_NAME = 'XOUT';
# CAPTURE_NAME     QUEUE_NAME  STATUS    START_SCN  START_TIME
# ---------------- ----------- --------- ---------- --------------------
# CONFLUENT_XOUT1  Q$_XOUT_11  ATTACHED  2371921    07.05.2025 08:15:01

# drop Outbound Server
SQL> BEGIN
  DBMS_XSTREAM_ADM.DROP_OUTBOUND(
    server_name => 'XOUT');
END;
/
# Drop the queue and queue table, if it was not created with the create outbound procedure
SQL> BEGIN
  DBMS_CAPTURE_ADM.DROP_CAPTURE(
    capture_name          => 'CONFLUENT_XOUT1',
    drop_unused_rule_sets => true);
END;
/
SQL> BEGIN
  DBMS_XSTREAM_ADM.REMOVE_QUEUE(
    queue_name               => 'Q$_XOUT_11',
    drop_unused_queue_table  => true);
END;
/
SQL> SELECT CAPTURE_NAME, 
            QUEUE_NAME,
            STATUS,
            START_SCN,
            to_char(START_TIME,'DD.MM.YYYY HH24:MI:SS') as START_TIME
      FROM ALL_XSTREAM_OUTBOUND 
     WHERE SERVER_NAME = 'XOUT';
# no rows     
```

The new outbound server capture process need to have FIRST_SCN/START_SCN `2315882` before the START_FROM_SCN `2316067`

```bash
sqlplus c##ggadmin@orclcdb
# Create queue and queue table
SQL> BEGIN
  DBMS_XSTREAM_ADM.SET_UP_QUEUE(
    queue_table => 'c##ggadmin.xs_queue_tbl',
    queue_name  => 'c##ggadmin.xs_queue');
END;
/

# Create a capture process
# The following example creates a capture process named xs_capture that starts capturing changes from the specified start_scn value. It enqueues the captured changes into the queue named xs_queue.
SQL> BEGIN
  DBMS_CAPTURE_ADM.CREATE_CAPTURE(
    queue_name       => 'c##ggadmin.xs_queue',
    capture_name     => 'xs_capture',
    capture_user     => 'c##ggadmin',
    first_scn        => 2315882,
    start_scn        => 2315882,
    source_database  => 'ORCLPDB1',
    source_root_name => 'ORCLCDB',
    capture_class    => 'XStream');
END;
/
# Create capture process rules
SQL> BEGIN
  DBMS_XSTREAM_ADM.ADD_TABLE_RULES(
    table_name            => 'ordermgmt.orders',
    streams_type          => 'capture',
    streams_name          => 'xs_capture',
    queue_name            => 'c##ggadmin.xs_queue',
    include_dml           => TRUE,
    include_ddl           => TRUE,
    source_database       => 'ORCLPDB1',
    source_root_name      => 'ORCLCDB',
    source_container_name => 'ORCLPDB1');
END;
/
SQL>BEGIN
  DBMS_XSTREAM_ADM.ADD_SCHEMA_RULES(
    schema_name           => 'ordermgmt',
    streams_type          => 'capture',
    streams_name          => 'xs_capture',
    queue_name            => 'c##ggadmin.xs_queue',
    include_dml           => TRUE,
    include_ddl           => TRUE,
    source_container_name => 'ORCLPDB1');
END;
/
# Table rules
BEGIN 
  DBMS_XSTREAM_ADM.ADD_TABLE_RULES(
    table_name            => 'ordermgmt.regions',
    streams_type          => 'capture',
    streams_name          => 'xs_capture',
    queue_name            => 'c##ggadmin.xs_queue',
    include_dml           => TRUE,
    include_ddl           => TRUE,
    source_container_name => 'ORCLPDB1');
END;
/
BEGIN 
  DBMS_XSTREAM_ADM.ADD_TABLE_RULES(
    table_name      => 'ordermgmt.orders',
    streams_type    => 'capture',
    streams_name    => 'xs_capture',
    queue_name      => 'c##ggadmin.xs_queue',
    include_dml     => TRUE,
    include_ddl     => TRUE,
    source_container_name => 'ORCLPDB1');
END;
/
SQL> BEGIN
  DBMS_XSTREAM_ADM.ADD_TABLE_RULES(
    table_name            => 'ordermgmt.regions',
    streams_type          => 'apply',
    streams_name          => 'XOUT',
    queue_name            => 'c##ggadmin.xs_queue',
    include_dml           => TRUE,
    include_ddl           => TRUE,
    source_database       => 'ORCLPDB1',
    source_root_name      => 'ORCLCDB',
    source_container_name => 'ORCLPDB1');
END;
/
# Do not start the capture process.
# Run the ADD_OUTBOUND procedure.
SQL> DECLARE
  tables  DBMS_UTILITY.UNCL_ARRAY;
  schemas DBMS_UTILITY.UNCL_ARRAY;
BEGIN
    tables(1)  := 'ordermgmt.orders';
    tables(2)  := 'ordermgmt.regions';
    schemas(1) := 'ordermgmt';
  DBMS_XSTREAM_ADM.ADD_OUTBOUND(
    server_name           =>  'xout',
    queue_name            =>  'c##ggadmin.xs_queue',
    source_container_name => 'ORCLPDB1',
    table_names           =>  tables,
    schema_names          =>  schemas);
END;
/

# GET XOUT Infos
SQL> SELECT CAPTURE_NAME, 
            QUEUE_NAME,
            STATUS,
            START_SCN,
            to_char(START_TIME,'DD.MM.YYYY HH24:MI:SS') as START_TIME
      FROM ALL_XSTREAM_OUTBOUND 
     WHERE SERVER_NAME = 'XOUT';
# CAPTURE_NAME                   QUEUE_NAME                     STATUS      START_SCN START_TIME
# ------------------------------ ------------------------------ ---------- ---------- -------------------
# XS_CAPTURE                     XS_QUEUE                       DISABLED      2315882 13.05.2025 10:03:45   
# get Data from Capture process
SQL> SELECT CAPTURE_NAME,
            START_SCN,
            FIRST_SCN,
            CAPTURED_SCN,
            APPLIED_SCN,
            STATUS
     from ALL_CAPTURE
    where CAPTURE_NAME ='XS_CAPTURE';
# CAPTURE_NAME                    START_SCN  FIRST_SCN CAPTURED_SCN APPLIED_SCN STATUS
# ------------------------------ ---------- ---------- ------------ ----------- ----------
# XS_CAPTURE                        2315882    2315882            0           0 DISABLED
# start capture
SQL> BEGIN
 DBMS_CAPTURE_ADM.START_CAPTURE(
 capture_name => 'XS_CAPTURE');
END;
/
#  start outbound
SQL> BEGIN
 DBMS_XSTREAM_ADM.START_OUTBOUND(
 server_name => 'XOUT');
END;
/
```

So, Outbound server and capture process are enabled but not attached with the connector. Now, we resume the connector with the past scn `2444221`.

```bash
# status conenctor
curl --request GET \
  --url 'https://api.confluent.cloud/connect/v1/environments/env-6810nj/clusters/lkc-jyy882/connectors/OracleXStreamSourceConnector_0/status' \
  --header 'Authorization: Basic base64' | jq
# update the offset to the last LCR
curl --request POST \
  --url 'https://api.confluent.cloud/connect/v1/environments/env-6810nj/clusters/lkc-jyy882/connectors/OracleXStreamSourceConnector_0/offsets/request' \
  --header 'Authorization: Basic base64' \
  --header 'content-type: application/json' \
  --data '{"type":"PATCH","offsets":[{"partition":{"server": "ORCLPDB1"},"offset":{"scn": "2315882"}}]}'
# Resume
curl --request PUT \
  --url 'https://api.confluent.cloud/connect/v1/environments/env-6810nj/clusters/lkc-jyy882/connectors/OracleXStreamSourceConnector_0/resume' \
  --header 'Authorization: Basic base64'

# status conenctor
curl --request GET \
  --url 'https://api.confluent.cloud/connect/v1/environments/env-6810nj/clusters/lkc-jyy882/connectors/OracleXStreamSourceConnector_0/status' \
  --header 'Authorization: Basic base64' | jq

or with CP:
```bash
# Check status
curl -s -X GET -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/status | jq
# Update 
curl -s -X PATCH -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/offsets \
--data '{"offsets":[{"partition":{"server": "ORCLPDB1"},"offset":{"scn": "2315882"}}]}' || jq
#RESUME
curl -s -X PUT -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/resume | jq
# Check status
curl -s -X GET -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/status | jq
```

Connector is running now.

What does the database tell us;

```bash
sqlplus c##ggadmin@orclcdb
# processed low position for outbound server
SQL> SELECT SERVER_NAME,
       SOURCE_DATABASE,
       PROCESSED_LOW_POSITION,
       TO_CHAR(PROCESSED_LOW_TIME,'HH24:MI:SS MM/DD/YY') PROCESSED_LOW_TIME
FROM ALL_XSTREAM_OUTBOUND_PROGRESS;
#   SERVER_NAME  SOURCE_DATABASE PROCESSED_LOW_POSITION                                             PROCESSED_LOW_TIM
# -------------- --------------- ------------------------------------------------------------------ -----------------
#  XOUT           ORCLPDB1       00000000002769FB000000000000000000000000002769FB000000000000000002 14:12:41 05/14/25


# Connected user
SQL> SELECT SERVER_NAME, 
       CONNECT_USER, 
       CAPTURE_NAME, 
       SOURCE_DATABASE,
       CAPTURE_USER,
       QUEUE_OWNER
  FROM ALL_XSTREAM_OUTBOUND;
# SERVER_NAME CONNECT_USER CAPTURE_NAME  SOURCE_DATABASE CAPTURE_USER QUEUE_OWNER
# ----------- ------------ ------------- --------------- ------------ -------------------------------------
# XOUT        C##GGADMIN   XS_CAPTURE    ORCLPDB1        C##GGADMIN   C##GGADMIN

# messages captured and enqueued
SQL> SELECT CAPTURE_NAME,
       STATE,
       TOTAL_MESSAGES_CAPTURED,
       TOTAL_MESSAGES_ENQUEUED 
  FROM gV$XSTREAM_CAPTURE;
#                                                      Redo
#                                                   Entries           Total
# Capture                                         Evaluated            LCRs
# Name            State                           In Detail        Enqueued
# --------------- ------------------------- --------------- ---------------
# XS_CAPTURE      WAITING FOR TRANSACTION             97541            7859
```


Connector is running. In my case no records are duplicated into kafka cluster.
If you set the SCN too low then the following error message could be thrown

```bash
# messages captured and enqueued
SQL> SELECT CAPTURE_NAME,
       STATE,
       TOTAL_MESSAGES_CAPTURED,
       TOTAL_MESSAGES_ENQUEUED 
  FROM gV$XSTREAM_CAPTURE;
# XS_CAPTURE      : SCN               0               0
#                 DO: SCN 2315882
# ==> WAITING FOR DICTIONARY REDO - Waiting for redo log files containing the dictionary build related to the first SCN to be added to the capture process session. A capture process cannot begin to scan the redo log files until all of the log files containing the dictionary build have been added.
```

You need to build a new dictionary from redo. The best way is to ask your DBA to help here. Please be aware that moving to past depends heavily on SCN in database (so redo and archived log files).

## 6. Shutdown abort the database

Try to simulate a DB crash.

```bash

sqlplus /nolog
SQL> conne sys/confluent123 as sysdba
SQL> shutdown abort;
```

connector error is:

```bash
"tasks": [
    {
      "id": 0,
      "state": "FAILED",
      "worker_id": "connect:8083",
      "trace": "org.apache.kafka.connect.errors.ConnectException: An exception occurred in the change event producer. This connector will be stopped.\n\tat io.debezium.pipeline.ErrorHandler.setProducerThrowable(ErrorHandler.java:67)\n\tat io.confluent.connect.oracle.xstream.cdc.streaming.OracleStreamingChangeEventSource.execute(OracleStreamingChangeEventSource.java:132)\n\tat io.confluent.connect.oracle.xstream.cdc.streaming.OracleStreamingChangeEventSource.execute(OracleStreamingChangeEventSource.java:48)\n\tat io.debezium.pipeline.ChangeEventSourceCoordinator.streamEvents(ChangeEventSourceCoordinator.java:313)\n\tat io.debezium.pipeline.ChangeEventSourceCoordinator.executeChangeEventSources(ChangeEventSourceCoordinator.java:203)\n\tat io.debezium.pipeline.ChangeEventSourceCoordinator.lambda$start$0(ChangeEventSourceCoordinator.java:143)\n\tat java.base/java.util.concurrent.Executors$RunnableAdapter.call(Unknown Source)\n\tat java.base/java.util.concurrent.FutureTask.run(Unknown Source)\n\tat java.base/java.util.concurrent.ThreadPoolExecutor.runWorker(Unknown Source)\n\tat java.base/java.util.concurrent.ThreadPoolExecutor$Worker.run(Unknown Source)\n\tat java.base/java.lang.Thread.run(Unknown Source)\nCaused by: oracle.streams.StreamsException: ORA-03113: end-of-file on communication channel\nProcess ID: 8563\nSession ID: 370 Serial number: 9305\n\n\n\tat oracle.streams.XStreamOut.XStreamOutReceiveLCRCallbackNative(Native Method)\n\tat oracle.streams.XStreamOut.receiveLCRCallback(Unknown Source)\n\tat io.confluent.connect.oracle.xstream.cdc.streaming.OracleStreamingChangeEventSource.captureData(OracleStreamingChangeEventSource.java:197)\n\tat io.confluent.connect.oracle.xstream.cdc.streaming.OracleStreamingChangeEventSource.execute(OracleStreamingChangeEventSource.java:122)\n\t... 9 more\n"
    }
```

bring database back

```bash
SQL> startup;
SQL> conn c#ggadmin@orclcdb
SQL> SELECT SERVER_NAME,
           XIDUSN ||'.'||
           XIDSLT ||'.'||
           XIDSQN "Transaction ID",
           COMMITSCN,
           COMMIT_POSITION,
           LAST_SENT_POSITION,
           MESSAGE_SEQUENCE
     FROM V$XSTREAM_OUTBOUND_SERVER;
# no rows selected
```

Outbound Servers are not started. Start them and resume the connector.

```bash
SQL> BEGIN
 DBMS_XSTREAM_ADM.START_OUTBOUND(
 server_name => 'XOUT');
END;
/
```


Resume connector:

```bash
# We need to stop with CP 
curl -s -X PUT -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/stop | jq
#RESUME
curl -s -X PUT -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/resume | jq
# status
curl -s -X GET -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/status | jq
```

Everything is running again. 
