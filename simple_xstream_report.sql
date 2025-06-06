-- Simple XStream Report
-- execute as sysdba
-- sqlplus sys/confluent123@orclcdb as sysdba
-- SQL> @simple_xstream_report.sql
-- SQL> !cat 



ALTER SESSION SET NLS_DATE_FORMAT = 'DD-MON-YYYY HH24:MI:SS';
ALTER SESSION set container=CDB$ROOT;

spool /tmp/simple_xstream_report.txt

SET LINESIZE 300
SET PAGESIZE 999

PROMPT ==== Simple XStream Report : time ====
select sysdate from dual;

-- Database enable for Golden Gate
PROMPT ==== XStream Outbound Server General Information ====
COLUMN VALUE FORMAT A40
COLUMN NAME FORMAT A40
select name, value from v$parameter where name = 'enable_goldengate_replication' ;

PROMPT ==== Is archive log enabled: ARCHIVELOG ====
SELECT LOG_MODE FROM V$DATABASE;

PROMPT ==== Monitoring Session Information About XStream Out Components ====
COLUMN ACTION HEADING 'XStream Component' FORMAT A30
COLUMN SID HEADING 'Session ID' FORMAT 99999
COLUMN SERIAL# HEADING 'Session|Serial|Number' FORMAT 99999999
COLUMN PROCESS HEADING 'Operating System|Process ID' FORMAT A17
COLUMN PROCESS_NAME HEADING 'XStream|Program|Name' FORMAT A7
 
SELECT /*+PARAM('_module_action_old_length',0)*/ ACTION,
       SID,
       SERIAL#,
       PROCESS,
       SUBSTR(PROGRAM,INSTR(PROGRAM,'(')+1,4) PROCESS_NAME
  FROM V$SESSION
  WHERE MODULE ='XStream';

PROMPT ==== XStream Outbound Server General Information ====
-- XStream Outbound Server Configuration Report Script
COLUMN SERVER_NAME FORMAT A15
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

PROMPT ==== Displaying Status and Error Information for an Outbound Server ====
COLUMN APPLY_NAME HEADING 'Outbound Server|Name' FORMAT A15
COLUMN STATUS HEADING 'Status' FORMAT A8
COLUMN ERROR_NUMBER HEADING 'Error Number' FORMAT 9999999
COLUMN ERROR_MESSAGE HEADING 'Error Message' FORMAT A40

SELECT APPLY_NAME, 
       STATUS,
       ERROR_NUMBER,
       ERROR_MESSAGE
  FROM DBA_APPLY
  WHERE PURPOSE = 'XStream Out';

PROMPT ==== Displaying the Apply Parameter Settings for an Outbound Server ====
COLUMN APPLY_NAME HEADING 'Outbound Server|Name' FORMAT A15
COLUMN PARAMETER HEADING 'Parameter' FORMAT A30
COLUMN VALUE HEADING 'Value' FORMAT A22
COLUMN SET_BY_USER HEADING 'Set by|User?' FORMAT A10
 
SELECT APPLY_NAME,
       PARAMETER, 
       VALUE,
       SET_BY_USER  
  FROM ALL_APPLY_PARAMETERS a, ALL_XSTREAM_OUTBOUND o
  WHERE a.APPLY_NAME=o.SERVER_NAME
  ORDER BY a.PARAMETER;

PROMPT ==== Capture Process Parameters ====
COLUMN CAPTURE_NAME HEADING 'Capture|Process|Name' FORMAT A25
COLUMN PARAMETER HEADING 'Parameter' FORMAT A30
COLUMN VALUE HEADING 'Value' FORMAT A10
COLUMN SET_BY_USER HEADING 'Set by|User?' FORMAT A10
 
SELECT c.CAPTURE_NAME,
       PARAMETER,
       VALUE,
       SET_BY_USER
  FROM ALL_CAPTURE_PARAMETERS c, ALL_XSTREAM_OUTBOUND o
  WHERE c.CAPTURE_NAME=o.CAPTURE_NAME
  ORDER BY PARAMETER;


PROMPT ==== Monitoring the History of Events for XStream Out Components ====
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

PROMPT ==== Displaying Information About an Outbound Servers Current Transaction ====
COLUMN SERVER_NAME HEADING 'Outbound|Server|Name' FORMAT A10
COLUMN 'Transaction ID' HEADING 'Transaction|ID' FORMAT A11
COLUMN COMMITSCN HEADING 'Commit SCN' FORMAT 9999999999999
COLUMN COMMIT_POSITION HEADING 'Commit Position' FORMAT A35
COLUMN LAST_SENT_POSITION HEADING 'Last Sent|Position' FORMAT A35
COLUMN MESSAGE_SEQUENCE HEADING 'Message|Number' FORMAT 999999999
 
SELECT SERVER_NAME,
       XIDUSN ||'.'|| 
       XIDSLT ||'.'||
       XIDSQN "Transaction ID",
       COMMITSCN,
       COMMIT_POSITION,
       LAST_SENT_POSITION,
       MESSAGE_SEQUENCE
  FROM V$XSTREAM_OUTBOUND_SERVER;

PROMPT ==== Displaying Statistics for an Outbound Server ====
COLUMN SERVER_NAME HEADING 'Outbound|Server|Name' FORMAT A8
COLUMN TOTAL_TRANSACTIONS_SENT HEADING 'Total|Trans|Sent' FORMAT 9999999
COLUMN TOTAL_MESSAGES_SENT HEADING 'Total|LCRs|Sent' FORMAT 9999999999
COLUMN BYTES_SENT HEADING 'Total|MB|Sent' FORMAT 99999999999999
COLUMN ELAPSED_SEND_TIME HEADING 'Time|Sending|LCRs|(in seconds)' FORMAT 99999999
COLUMN LAST_SENT_MESSAGE_NUMBER HEADING 'Last|Sent|Message|Number' FORMAT 99999999
COLUMN LAST_SENT_MESSAGE_CREATE_TIME HEADING 'Last|Sent|Message|Creation|Time' FORMAT A30
 
SELECT SERVER_NAME,
       TOTAL_TRANSACTIONS_SENT,
       TOTAL_MESSAGES_SENT,
       (BYTES_SENT/1024)/1024 BYTES_SENT,
       (ELAPSED_SEND_TIME/100) ELAPSED_SEND_TIME,
       LAST_SENT_MESSAGE_NUMBER,
       TO_CHAR(LAST_SENT_MESSAGE_CREATE_TIME,'HH24:MI:SS MM/DD/YY') 
          LAST_SENT_MESSAGE_CREATE_TIME
  FROM V$XSTREAM_OUTBOUND_SERVER;

PROMPT ==== Displaying the Processed Low Position for an Outbound Server   ====
COLUMN SERVER_NAME HEADING 'Outbound|Server|Name' FORMAT A10
COLUMN SOURCE_DATABASE HEADING 'Source|Database' FORMAT A20
COLUMN PROCESSED_LOW_POSITION HEADING 'Processed|Low LCR|Position' FORMAT A30
COLUMN PROCESSED_LOW_TIME HEADING 'Processed|Low|Time' FORMAT A30

SELECT SERVER_NAME,
       SOURCE_DATABASE,
       PROCESSED_LOW_POSITION,
       TO_CHAR(PROCESSED_LOW_TIME,'HH24:MI:SS MM/DD/YY') PROCESSED_LOW_TIME
FROM ALL_XSTREAM_OUTBOUND_PROGRESS; 

PROMPT ==== Capture Process Status and Statistics ====
SELECT CAPTURE_NAME, STATUS, CAPTURE_TYPE, START_SCN, APPLIED_SCN, REQUIRED_CHECKPOINT_SCN
FROM DBA_CAPTURE
WHERE CAPTURE_NAME IN (SELECT CAPTURE_NAME FROM DBA_XSTREAM_OUTBOUND);

PROMPT ==== Determining the Applied SCN for Each Capture Process ====
COLUMN CAPTURE_NAME HEADING 'Capture Process Name' FORMAT A30
COLUMN APPLIED_SCN HEADING 'Applied SCN' FORMAT 99999999999

SELECT CAPTURE_NAME, APPLIED_SCN FROM ALL_CAPTURE;

PROMPT ==== Displaying the Redo Log Scanning Latency for Each Capture Process ====
COLUMN CAPTURE_NAME HEADING 'Capture|Process|Name' FORMAT A16
COLUMN LATENCY_SECONDS HEADING 'Latency|in|Seconds' FORMAT 999999
COLUMN LAST_STATUS HEADING 'Seconds Since|Last Status' FORMAT 999999
COLUMN CAPTURE_TIME HEADING 'Current|Process|Time'
COLUMN CREATE_TIME HEADING 'Message|Creation Time' FORMAT 999999

SELECT CAPTURE_NAME,
       ((SYSDATE - CAPTURE_MESSAGE_CREATE_TIME)*86400) LATENCY_SECONDS,
       ((SYSDATE - CAPTURE_TIME)*86400) LAST_STATUS,
       TO_CHAR(CAPTURE_TIME, 'HH24:MI:SS MM/DD/YY') CAPTURE_TIME,       
       TO_CHAR(CAPTURE_MESSAGE_CREATE_TIME, 'HH24:MI:SS MM/DD/YY') CREATE_TIME
  FROM V$XSTREAM_CAPTURE;

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

PROMPT ==== Queue Information ====
COLUMN OWNER FORMAT A15
COLUMN QUEUE_TABLE FORMAT A15
COLUMN NAME FORMAT A13
COLUMN QUEUE_TYPE HEADING 'Queue|Type' FORMAT A12
COLUMN MAX_RETRIES HEADING 'Max|Retries' FORMAT 999999
COLUMN RETRY_DELAY HEADING 'Retry|Delay' FORMAT 999999
COLUMN RETENTION   FORMAT 999999
SELECT OWNER, QUEUE_TABLE, NAME, QUEUE_TYPE, MAX_RETRIES, RETRY_DELAY, RETENTION
FROM DBA_QUEUES
WHERE OWNER IN (SELECT QUEUE_OWNER FROM DBA_XSTREAM_OUTBOUND)
AND NAME IN (SELECT QUEUE_NAME FROM DBA_XSTREAM_OUTBOUND);

PROMPT ==== Queue Statistics (Buffered Queues) ====
COLUMN QUEUE_SCHEMA HEADING 'Queue|Schema' FORMAT A15
COLUMN Name HEADING 'Queue|Name' FORMAT A15
COLUMN QUEUE_State HEADING 'Queue|State' FORMAT A12
COLUMN MESSAGE_COUNT HEADING 'Mesg|Count' FORMAT 999999
SELECT QUEUE_SCHEMA, QUEUE_NAME, QUEUE_STATE, COUNT(*) AS MESSAGE_COUNT
FROM V$BUFFERED_QUEUES
WHERE QUEUE_NAME IN (SELECT QUEUE_NAME FROM DBA_XSTREAM_OUTBOUND)
GROUP BY QUEUE_SCHEMA, QUEUE_NAME, QUEUE_STATE;

PROMPT ==== xstream transactions with 0 cumulative message count (Number of LCRs processed in the transaction=0 ) ====
select 'No Rows', count(*) from gv$xstream_transaction where CUMULATIVE_MESSAGE_COUNT =0
union all
select 'With Rows', count(*) from gv$xstream_transaction where CUMULATIVE_MESSAGE_COUNT >0;

PROMPT ==== Apply Usage ====
COLUMN APPLY_NAME HEADING 'APP' FORMAT A15
SELECT APPLY_NAME AS APP,
SGA_USED/(1024*1024) AS USED,
SGA_ALLOCATED/(1024*1024) AS ALLOCATED,
TOTAL_MESSAGES_DEQUEUED AS DEQUEUED,
TOTAL_MESSAGES_SPILLED AS SPILLED
FROM gV$XSTREAM_APPLY_READER;

PROMPT ==== Capture Usage ====
COLUMN CAPTURE_NAME HEADING 'CAP' FORMAT A15
SELECT CAPTURE_NAME AS CAP,
SGA_USED/(1024*1024) AS USED,
SGA_ALLOCATED/(1024*1024) AS ALLOCATED,
TOTAL_MESSAGES_CAPTURED AS CAPTURED,
TOTAL_MESSAGES_ENQUEUED AS ENQUEUED
FROM gV$XSTREAM_CAPTURE;

PROMPT ==== Streams SGAStat ====
select * from gv$sgastat where pool like '%streams%' and BYTES > 1000 order by BYTES desc;

PROMPT ==== Streams Pool Usage ====
SELECT COMPONENT, CURRENT_SIZE/1024/1024 AS "CURRENT_SIZE_MB", USER_SPECIFIED_SIZE/1024/1024 AS "SPECIFIED_SIZE_MB"
FROM V$SGA_DYNAMIC_COMPONENTS
WHERE COMPONENT = 'streams pool';

PROMPT ==== Supplemental Logging Status (Database Level) ====
SELECT SUPPLEMENTAL_LOG_DATA_MIN, SUPPLEMENTAL_LOG_DATA_PK, SUPPLEMENTAL_LOG_DATA_UI,
       SUPPLEMENTAL_LOG_DATA_FK, SUPPLEMENTAL_LOG_DATA_ALL
FROM V$DATABASE;

PROMPT ==== Supplemental Logging (Table Level) for XStream Tables ====
COLUMN OWNER FORMAT A20
COLUMN TABLE_NAME HEADING 'Table|Name' FORMAT A20
COLUMN LOG_GROUP_NAME HEADING 'LogGroup|Name' FORMAT A20
COLUMN LOG_GROUP_TYPE HEADING 'LogGroup|Type' FORMAT A20
SELECT OWNER, TABLE_NAME, LOG_GROUP_NAME, ALWAYS, LOG_GROUP_TYPE
FROM DBA_LOG_GROUPS
WHERE OWNER NOT IN ('SYS','SYSTEM','XDB','OUTLN','DBSNMP')
ORDER BY OWNER, TABLE_NAME;

PROMPT ==== Displaying the Registered Redo Log Files for Each Capture Process ====
COLUMN CONSUMER_NAME HEADING 'Capture|Process|Name' FORMAT A16
COLUMN SOURCE_DATABASE HEADING 'Source|Database' FORMAT A10
COLUMN SEQUENCE# HEADING 'Sequence|Number' FORMAT 99999
COLUMN NAME HEADING 'Archived Redo Log|File Name' FORMAT A60
COLUMN DICTIONARY_BEGIN HEADING 'Dictionary|Build|Begin' FORMAT A10
COLUMN DICTIONARY_END HEADING 'Dictionary|Build|End' FORMAT A10

SELECT r.CONSUMER_NAME,
       r.SOURCE_DATABASE,
       r.SEQUENCE#, 
       r.NAME, 
       r.DICTIONARY_BEGIN, 
       r.DICTIONARY_END 
  FROM DBA_REGISTERED_ARCHIVED_LOG r, ALL_CAPTURE c
  WHERE r.CONSUMER_NAME = c.CAPTURE_NAME;  

PROMPT ==== Displaying Redo Log Files That Are Required by Each Capture Process ====
COLUMN CONSUMER_NAME HEADING 'Capture|Process|Name' FORMAT A16
COLUMN SOURCE_DATABASE HEADING 'Source|Database' FORMAT A10
COLUMN SEQUENCE# HEADING 'Sequence|Number' FORMAT 99999
COLUMN NAME HEADING 'Required|Archived Redo Log|File Name' FORMAT A60

SELECT r.CONSUMER_NAME,
       r.SOURCE_DATABASE,
       r.SEQUENCE#, 
       r.NAME 
  FROM DBA_REGISTERED_ARCHIVED_LOG r, ALL_CAPTURE c
  WHERE r.CONSUMER_NAME =  c.CAPTURE_NAME AND
        r.NEXT_SCN      >= c.REQUIRED_CHECKPOINT_SCN;  

PROMPT ==== Displaying SCN Values for Each Redo Log File Used by Each Capture Process ====
COLUMN CONSUMER_NAME HEADING 'Capture|Process|Name' FORMAT A17
COLUMN NAME HEADING 'Archived Redo Log|File Name' FORMAT A60
COLUMN FIRST_SCN HEADING 'First SCN' FORMAT 99999999999
COLUMN NEXT_SCN HEADING 'Next SCN' FORMAT 99999999999
COLUMN PURGEABLE HEADING 'Purgeable?' FORMAT A10
 
SELECT r.CONSUMER_NAME,
       r.NAME, 
       r.FIRST_SCN,
       r.NEXT_SCN,
       r.PURGEABLE 
  FROM DBA_REGISTERED_ARCHIVED_LOG r, ALL_CAPTURE c
  WHERE r.CONSUMER_NAME = c.CAPTURE_NAME;

PROMPT ==== Outbound Server State and Dequeued SCN ====
SELECT SERVER_NAME, STATE, TOTAL_MESSAGES_SENT, BYTES_SENT, LAST_SENT_MESSAGE_NUMBER AS LAST_DEQUEUED_SCN
FROM V$XSTREAM_OUTBOUND_SERVER
WHERE SERVER_NAME IN (SELECT SERVER_NAME FROM DBA_XSTREAM_OUTBOUND);

PROMPT ==== SYSAUX Tablespace Usage ====
COLUMN TABLESPACE_NAME FORMAT A15

SELECT TABLESPACE_NAME, SUM(BYTES)/1024/1024 AS "USED_MB", SUM(MAXBYTES)/1024/1024 AS "MAX_MB"
FROM DBA_DATA_FILES
WHERE TABLESPACE_NAME = 'SYSAUX'
GROUP BY TABLESPACE_NAME;

PROMPT ==== UNDO Tablespace Usage ====
COLUMN STATUS FORMAT A15
SELECT TABLESPACE_NAME, STATUS, SUM(BYTES)/1024/1024 AS "USED_MB"
FROM DBA_UNDO_EXTENTS
GROUP BY TABLESPACE_NAME, STATUS;

PROMPT ==== UNDO Tablespace Datafiles ====
COLUMN FILE_NAME FORMAT A50
SELECT TABLESPACE_NAME, FILE_NAME, BYTES/1024/1024 AS "FILE_SIZE_MB", AUTOEXTENSIBLE
FROM DBA_DATA_FILES
WHERE TABLESPACE_NAME IN (SELECT DISTINCT TABLESPACE_NAME FROM DBA_UNDO_EXTENTS);

PROMPT ==== Current SCN Information ====
SELECT CURRENT_SCN, TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') AS CURRENT_TIME
FROM V$DATABASE;

PROMPT ==== Redo Log SCN Range ====
SELECT THREAD#, SEQUENCE#, FIRST_CHANGE#, NEXT_CHANGE#, STATUS
FROM V$LOG
ORDER BY THREAD#, SEQUENCE# DESC;

Spool off
