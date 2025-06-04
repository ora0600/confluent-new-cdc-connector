# How to avoid deleting required archive logs

According to Oracle's documentation, if a capture process is stopped and restarted, then it starts scanning the redo log from the SCN that corresponds to its Required Checkpoint SCN. A capture process needs the redo log file that includes the required checkpoint SCN and all subsequent redo log files.

```bash
set lines 300
PROMPT ==== Capture Process Status and Statistics -REQUIRED_CHECKPOINT_SCN ====
COLUMN CAPTURE_NAME FORMAT A16
SELECT CAPTURE_NAME, STATUS, CAPTURE_TYPE, START_SCN, APPLIED_SCN, REQUIRED_CHECKPOINT_SCN
FROM DBA_CAPTURE
WHERE CAPTURE_NAME IN (SELECT CAPTURE_NAME FROM DBA_XSTREAM_OUTBOUND);
#CAPTURE_NAME     STATUS   CAPTURE_TY  START_SCN APPLIED_SCN REQUIRED_CHECKPOINT_SCN
#---------------- -------- ---------- ---------- ----------- -----------------------
#CONFLUENT_XOUT1  ENABLED  LOCAL         2327839     2429348                 2422468
```

The required checkpoint scn is this sample: 2422468

```Bash
PROMPT ==== Displaying Redo Log Files That Are Required by Each Capture Process ====
COLUMN CONSUMER_NAME HEADING 'Capture|Process|Name' FORMAT A16
COLUMN SOURCE_DATABASE HEADING 'Source|Database' FORMAT A10
COLUMN SEQUENCE# HEADING 'Sequence|Number' FORMAT 99999
COLUMN NAME HEADING 'Required|Archived Redo Log|File Name' FORMAT A60
SELECT r.CONSUMER_NAME,
       r.SOURCE_DATABASE,
       r.SEQUENCE#, 
       r.THREAD#,
       r.NAME, 
       c.REQUIRED_CHECKPOINT_SCN,
       r.NEXT_SCN
  FROM DBA_REGISTERED_ARCHIVED_LOG r, ALL_CAPTURE c
  WHERE r.CONSUMER_NAME =  c.CAPTURE_NAME AND
        r.NEXT_SCN      >= c.REQUIRED_CHECKPOINT_SCN;  
# no rows selected        
```

If the last query results in `no rows selected` then I can delete all archive logs.
I run the query without checking the SCN.

```Bash
PROMPT ==== Displaying Redo Log Files That Are Required by Each Capture Process ====
COLUMN CONSUMER_NAME HEADING 'Capture|Process|Name' FORMAT A16
COLUMN SOURCE_DATABASE HEADING 'Source|Database' FORMAT A10
COLUMN SEQUENCE# HEADING 'Sequence|Number' FORMAT 99999
COLUMN NAME HEADING 'Required|Archived Redo Log|File Name' FORMAT A60
SELECT r.CONSUMER_NAME,
       r.SOURCE_DATABASE,
       r.SEQUENCE#, 
       r.THREAD#,
       r.NAME, 
       c.REQUIRED_CHECKPOINT_SCN,
       r.NEXT_SCN
  FROM DBA_REGISTERED_ARCHIVED_LOG r, ALL_CAPTURE c
  WHERE r.CONSUMER_NAME =  c.CAPTURE_NAME;
#Capture                                         Required
#Process          Source     Sequence            Archived Redo Log
#Name             Database     Number    THREAD# File Name                                                    REQUIRED_CHECKPOINT_SCN   NEXT_SCN
#---------------- ---------- -------- ---------- ------------------------------------------------------------ ----------------------- ----------
#OGG$CAP_ORADB19C ORCLPDB1          8          1 /opt/oracle/product/19c/dbhome_1/dbs/arch1_8_1192789111.dbf                  2311341    2180306
#OGG$CAP_ORADB19C ORCLPDB1          9          1 /opt/oracle/product/19c/dbhome_1/dbs/arch1_9_1192789111.dbf                  2311341    2181564
#CONFLUENT_XOUT1  ORCLPDB1         11          1 /opt/oracle/product/19c/dbhome_1/dbs/arch1_11_1192789111.dbf                 2433426    2327839
#CONFLUENT_XOUT1  ORCLPDB1         12          1 /opt/oracle/product/19c/dbhome_1/dbs/arch1_12_1192789111.dbf                 2433426    2328550  
```        

So, I can delete every archive log (4 in total), and I do that

```bash
ssh -i ~/keys/cmawsdemoxstream.pem ec2-user@X.X.X.X 
sudo docker exec -it oracle19c /bin/bash
rm /opt/oracle/product/19c/dbhome_1/dbs/arch1_8_1192789111.dbf
rm /opt/oracle/product/19c/dbhome_1/dbs/arch1_9_1192789111.dbf 
rm /opt/oracle/product/19c/dbhome_1/dbs/arch1_11_1192789111.dbf
rm /opt/oracle/product/19c/dbhome_1/dbs/arch1_12_1192789111.dbf
```

Archive logs are deleted, check what is happing on capture process

```bash
PROMPT ==== messages captured and enqueued ====
COLUMN CAPTURE_NAME HEADING 'Capture|Process|Name' FORMAT A15
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
#Capture                                   Latency               Current                                Total MessTotalage
#Process                                        in Seconds Since Process           Message           captured     Enqueued
#Name            STATE                     Seconds   Last Status Time              Creation Time     Messages     Messages
#--------------- ------------------------- ------- ------------- ----------------- ----------------- -------- ------------
#CONFLUENT_XOUT1 WAITING FOR TRANSACTION         5             4 13:42:29 06/04/25 13:42:28 06/04/25    13911         4409
```

Data is still flowing without any problem. We do not touch any component.

One other suggestion would be to use RMAN to delete the archived redo log files. RMAN does not delete the archived redo log files if required by the capture process, unless disk space is exhausted, in which case it would delete a required archived redo log file also.
However, RMAN always ensures that archived redo log files are backed up before it deletes them. If RMAN deletes an archived redo log file that is required by a capture process, then RMAN records this action in the alert log [Ref](https://docs.oracle.com/en/database/oracle/oracle-database/19/xstrm/troubleshooting-xstream-out.html#GUID-4E6239CC-E633-45B9-8081-A1FEB5A64012).
