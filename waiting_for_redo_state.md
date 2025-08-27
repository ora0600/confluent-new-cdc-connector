# Waiting for REDO State

We may come into a situation where you see 

```bash
# messages captured and enqueued
SQL> SELECT CAPTURE_NAME,
       STATE,
       TOTAL_MESSAGES_CAPTURED,
       TOTAL_MESSAGES_ENQUEUED 
  FROM gV$XSTREAM_CAPTURE;
# ==> WAITING FOR REDO: FILE NA, Thread 1, SEQUENCE 0 SCN 
```

WAITING FOR REDO  : If the state is WAITING FOR REDO  request the user to query the REQUIRED_CHECKPOINT_SCN column in the ALL_CAPTURE data dictionary view to verify if the capture process is made available the archived redo log file containing required checkpoint SCN. If the REQUIRED_CHECKPOINT_SCN is not available to the capture process, then the capture process is most likely not recoverable and the customer should be advised to create a new outbound server and drop the existing one. This should be followed by creation of a new connector with the new outbound server. Changing outbound server in existing connector is not advised.

Try to execute the [simple Xstream Report](https://github.com/ora0600/confluent-new-cdc-connector/blob/main/simple_xstream_report.sql) to get all the information you need.

If you then have problems to start a new outbound server, be aware that XStream outbound server only gets created when there are no uncommitted transactions. Even if there is an open transaction on a table or schema not configured in the XStream configuration, the server creation would be stuck.


The [Oracle documentation](https://docs.oracle.com/en/database/oracle/oracle-database/18/xstrm/xstream-guide.pdf) (Chapter 7.2.3 The Capture Process Is Missing Required Redo Log Files starting with page 7-10 or 238) described very well, what you have to do, if you getting such error : `WAITING FOR REDO`.
You can check the **V$LOGMNR_LOGS** dynamic performance view to determine the missing SCN range, and add the relevant redo log files. A capture process needs the redo log file that includes the **required checkpoint SCN** and all subsequent redo log files. You can query the **REQUIRED_CHECKPOINT_SCN** column in the **ALL_CAPTURE** data dictionary view to determine the required checkpoint SCN for a capture process.
If the capture process is disabled for longer than the amount of time specified in the **CONTROL_FILE_RECORD_KEEP_TIME** initialization parameter, then information about the
missing redo log files might have been replaced in the control file. You can query the V$ARCHIVE_LOG view to see if the log file names are listed. If they are not listed, then you can register them with a **ALTER DATABASE REGISTER OR REPLACE LOGFILE** SQL statement.
