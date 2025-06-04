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