# FAQ: In General play with customer requests 

For the mentioned cases I run my demo environment:
* Confluent Cloud,
* Oracle 19c EE on AWS and 
* a self-managed XStream Connector from Confluent is running.

The environment is documented [here](https://github.com/ora0600/confluent-new-cdc-connector/tree/main).


Following cases are covered here:
1. [Setting up xstream from oracle to gcp kafka Non-cdc and cdc – db rac/non-rac.](#1-setting-up-xstream-from-oracle-to-gcp-kafka-non-cdc-and-cdc-–-db-racnon-rac)
2. [After creation and initial load make changes to the table (DML operations) and validate if those changes reflect in the topic](#2-after-creation-and-initial-load-make-changes-to-the-table-dml-operations-and-validate-if-those-changes-reflect-in-the-topic-and-initial-load-make-changes-to-the-table-dml-operations-and-validate-if-those-changes-reflect-in-the-topic)
3. [Evaluate, if we can add multiple tables in single connector.](#3-evaluate-if-we-can-add-multiple-tables-in-single-connector)
4. [Evaluate, if we can add multiple tables with different owner’s in the single connector](#4-evaluate-if-we-can-add-multiple-tables-with-different-owners-in-the-single-connector)
5. [Include multiple tables for capture whether multiple capture process/xstream outbound servers are required.](#5-include-multiple-tables-for-capture-whether-multiple-capture-processxstream-outbound-servers-are-required)
6. [Pause/stop capture/xstream outbound server.](#6-pausestop-capturexstream-outbound-server)
7. [Switch redo logs to generate archives and try resume/start capture/xstream server and see if it picks from archives.](#7-switch-redo-logs-to-generate-archives-and-try-resumestart-capturexstream-server-and-see-if-it-picks-from-archives)
8. [Alter capture to start from specific scn/time](#8-alter-capture-to-start-from-specific-scntime)
9. [Alter connector to pick from prior time/scn.](#9-alter-connector-to-pick-from-prior-timescn)
10. [Stop db/disable/enable archives and steps to restart capture/xstream outbound server and connector required during maintenance.](#10-atop-dbdisableenable-archives-and-steps-to-restart-capturexstream-outbound-server-and-connector-required-during-maintenance)
11. [Test case, for long running transactions where we won’t commit and then we move or delete archives from the source and then commit. Check the connector status and data.](#11-test-case-for-long-running-transactions-where-we-wont-commit-and-then-we-move-or-delete-archives-from-the-source-and-then-commit-check-the-connector-status-and-data)
12. [Test case scenario, if we move the archives or delete (Since in prod huge number of archives gets generates and we move the archives regularly via cron) while capture process is running what will be the status and how to manage.](#12-test-case-scenario-if-we-move-the-archives-or-delete-since-in-prod-huge-number-of-archives-gets-generates-and-we-move-the-archives-regularly-via-cron-while-capture-process-is-running-what-will-be-the-status-and-how-to-manage)
13. [Abrupt or normal shut down of source database and check the connector.](#13-abrupt-or-normal-shut-down-of-source-database-and-check-the-connector)
14. [Any parameter to set at capture level to make sure it doesn’t consume much memory while extract/replicate.](#14-any-parameter-to-set-at-capture-level-to-make-sure-it-doesnt-consume-much-memory-while-extractreplicate)
15. [Need to explore the monitoring of sessions of those connectors and any specific monitoring which needs our attention need to specify by Confluent.](#15-need-to-explore-the-monitoring-of-sessions-of-those-connectors-and-any-specific-monitoring-which-needs-our-attention-need-to-specify-by-confluent)
16. [Playing with offset](#16-playing-with-offset)

# 1. Setting up xstream from oracle to gcp kafka Non-cdc and cdc – db rac/non-rac.
## RAC: 
see https://staging-docs-independent.confluent.io/docs-kafka-connect-oracle-xstream-cdc-source/PR/11/0.2/getting-started.html#connect-to-an-oracle-real-application-cluster-rac-database
Configure the database.hostname property to the Oracle RAC database SCAN address.
Configure the database.service.name property to the auto-created Oracle XStream service.
In an Oracle RAC environment, only the owner instance can have a buffer for a queue,
but different instances can have buffers for different queues. A buffered queue is
System Global Area (SGA) memory associated with a queue.
You set the capture process parameter use_rac_service to Y to specify ownership of
the queue table or the primary and secondary instance for a given queue table.

The main different is:

- Outbound Server: 
   ```sql
   BEGIN
     DBMS_CAPTURE_ADM.SET_PARAMETER( capture_name => 'Name of capture Process',
                                     parameter => 'use_rac_service',
                                     value => 'Y');
   END;  
   /
   ```
   see https://staging-docs-independent.confluent.io/docs-kafka-connect-oracle-xstream-cdc-source/PR/11/0.2/cp-oracle-xstream-cdc-source-includes/prereqs-validation.html#capture-changes-from-oracle-rac

## DB Prerequisites:
different setup for supplemental logging, 
NON-CDB: Different setup, mainly without container set. Outbound Server without     source_container_name =>  'XEPDB1',   
CDB: with container setup, Outbound server with     source_container_name =>  'XEPDB1',   
   
## Connector:
CDB: set "database.pdb.name": "ORCLPDB1",
NON-CDB: do not set "database.pdb.name": "ORCLPDB1",

CDB: See https://staging-docs-independent.confluent.io/docs-kafka-connect-oracle-xstream-cdc-source/PR/11/0.2/getting-started.html#container-database-cdb
NON-CDB: https://staging-docs-independent.confluent.io/docs-kafka-connect-oracle-xstream-cdc-source/PR/11/0.2/getting-started.html#non-container-database-non-cdb
Should be straight forward.

# 2. After creation and initial load make changes to the table (DML operations) and validate if those changes reflect in the topic.
Should be straight forward. DB Setup is given.

## Create Outbound Server as ADMIN:

```sql
DECLARE
  tables  DBMS_UTILITY.UNCL_ARRAY;
  schemas DBMS_UTILITY.UNCL_ARRAY;
BEGIN
    tables(1)   := 'pub.dba_userstest';
    schemas(1)  := 'PUB';        
  DBMS_XSTREAM_ADM.CREATE_OUTBOUND(
    capture_name          =>  'confluent_xout1',
    server_name           =>  'xout',
    table_names           =>  tables,
    schema_names          =>  schemas,
    comment               => 'Confluent Xstream CDC Connector' );
-- set rentention
    DBMS_CAPTURE_ADM.ALTER_CAPTURE(
      capture_name => 'confluent_xout1',
      checkpoint_retention_time => 3
    );
-- set capture user
    DBMS_XSTREAM_ADM.ALTER_OUTBOUND(
     server_name  => 'xout',
     connect_user => 'cfltuser');

END;
/
```

## Connector:
```bash
{
            "name": "XSTREAMCDC0",
            "config":{
              "connector.class":                                      "io.confluent.connect.oracle.xstream.cdc.OracleXStreamSourceConnector",
              "task.max":                                             1,
              "database.hostname":                                    "35.159.86.95",
              "database.port":                                        1521,
              "database.user":                                        "C##GGADMIN",
              "database.password":                                    "Confluent12!",
              "database.dbname":                                      "ORCLCDB",
              "database.service.name":                                "ORCLCDB",
              "database.out.server.name":                             "XOUT",
              "table.include.list":                                   "PUB[.](DBA_USERSTEST)",
              "topic.prefix":                                         "PUB",
              "snapshot.mode":                                        "initial", 
              "snapshot.fetch.size":                                  10000, 
              "snapshot.max.threads":                                 4,
              "query.fetch.size":                                     10000,
              "max.queue.size":                                       65536,
              "max.batch.size":                                       16384,
              "producer.override.batch.size":                         204800,
              "producer.override.linger.ms":                          50,
              "heartbeat.interval.ms":                                300000,              
              "schema.history.internal.kafka.bootstrap.servers":      "pkc-7xoy1.eu-central-1.aws.confluent.cloud:9092",
              "schema.history.internal.kafka.sasl.jaas.config":       "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"KEY\" password=\"SECRET\";",
              "schema.history.internal.kafka.security.protocol":      "SASL_SSL",
              "schema.history.internal.kafka.sasl.mechanism":         "PLAIN",
              "schema.history.internal.consumer.security.protocol":   "SASL_SSL",
              "schema.history.internal.consumer.ssl.endpoint.identification.algorithm": "https",
              "schema.history.internal.consumer.sasl.mechanism":     "PLAIN",
              "schema.history.internal.consumer.sasl.jaas.config":   "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"KEY\" password=\"SECRET\";",
              "schema.history.internal.producer.security.protocol":  "SASL_SSL",
              "schema.history.internal.producer.ssl.endpoint.identification.algorithm": "https",
              "schema.history.internal.producer.sasl.mechanism":     "PLAIN",
              "schema.history.internal.producer.sasl.jaas.config":   "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"KEY\" password=\"SECRET\";",
              "schema.history.internal.kafka.topic":                  "__orcl-schema-changes.PUB",
              "confluent.topic.replication.factor":                   "3",
              "topic.creation.default.replication.factor":            "3",
              "topic.creation.default.partitions":                    "1",
              "confluent.topic.bootstrap.servers":                    "pkc-7xoy1.eu-central-1.aws.confluent.cloud:9092",
              "confluent.topic.sasl.jaas.config":                     "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"KEY\" password=\"SECRET\";",
              "confluent.topic.security.protocol":                    "SASL_SSL",
              "confluent.topic.sasl.mechanism":                       "PLAIN",
              "key.converter":                                        "org.apache.kafka.connect.storage.StringConverter",
              "value.converter":                                      "org.apache.kafka.connect.json.JsonConverter",
              "value.converter.basic.auth.credentials.source":        "USER_INFO",
              "value.converter.schema.registry.basic.auth.user.info": "KEY:SECRET",
              "value.converter.schema.registry.url":                  "https://psrc-pg0kmy.eu-central-1.aws.confluent.cloud",          
              "enable.metrics.collection":                            "true"
            }
}
```

check if Connector is attached to XOUT Server

```sql
-- Get XOUT 
SELECT CAPTURE_NAME, STATUS FROM ALL_XSTREAM_OUTBOUND WHERE SERVER_NAME = 'XOUT';
```


## Change DML
Best way would be to write a short procedure call like
Run order inserts, see [code](https://github.com/ora0600/confluent-new-cdc-connector/blob/main/oraclexe21c/docker/scripts/06_data_generator.sql)

```sql
SQL> Connect sys/confluent123@orclpdb1 as sysdba
-- check which tables are run outbound support
SQL> SELECT OWNER, OBJECT_NAME, SUPPORT_MODE
 FROM DBA_XSTREAM_OUT_SUPPORT_MODE
 ORDER BY OBJECT_NAME;
SQL> connect ordermgmt/kafka@ORCPDB1 
SQL> begin
   produce_orders;
end;
/

-- as c##ggadmin check current transaction
-- # Current transaction
SQL> SELECT SERVER_NAME,
       XIDUSN ||'.'|| 
       XIDSLT ||'.'||
       XIDSQN "Transaction ID",
       COMMITSCN,
       COMMIT_POSITION,
       LAST_SENT_POSITION,
       MESSAGE_SEQUENCE
  FROM V$XSTREAM_OUTBOUND_SERVER;
-- Statistics, what was sent
SQL> SELECT SERVER_NAME,
       TOTAL_TRANSACTIONS_SENT,
       TOTAL_MESSAGES_SENT,
       (BYTES_SENT/1024)/1024 BYTES_SENT,
       (ELAPSED_SEND_TIME/100) ELAPSED_SEND_TIME,
       LAST_SENT_MESSAGE_NUMBER,
       TO_CHAR(LAST_SENT_MESSAGE_CREATE_TIME,'HH24:MI:SS MM/DD/YY') 
          LAST_SENT_MESSAGE_CREATE_TIME
  FROM V$XSTREAM_OUTBOUND_SERVER;
-- # Capture latency
SQL> SELECT CAPTURE_NAME,
      ((SYSDATE - CAPTURE_MESSAGE_CREATE_TIME)*86400) LATENCY_SECONDS
FROM V$XSTREAM_CAPTURE;
```

You can stop the connector via UI or API call.

```bash
curl -s -X PUT -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/pause | jq
```

Wait a while and write down the offset. Then resume the connector. The connector should continue, from the last offset.

```bash
curl -s -X PUT -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/resume | jq
```

Try to update, insert and delete a messahe

```sql
sqlplus ordermgmt/kafka@orclpdb1
SQL> delete from orders where order_id = 44;
SQL> commit;
```

You should see in topic viewner

```json
  "payload": {
    "before": {
      "ORDER_ID": 44,
      "CUSTOMER_ID": 2,
      "STATUS": "Pending",
      "SALESMAN_ID": 55,
      "ORDER_DATE": 1487548800000
    },
    "after": null,
```

Check logs and topic message viewer.

# 3. Evaluate, if we can add multiple tables in single connector.

See [multiples tables](https://staging-docs-independent.confluent.io/docs-kafka-connect-oracle-xstream-cdc-source/PR/11/0.2/cp-oracle-xstream-cdc-source-includes/examples.html#capture-multiple-tables)
See [Add tables to the capture set](https://staging-docs-independent.confluent.io/docs-kafka-connect-oracle-xstream-cdc-source/PR/11/0.2/cp-oracle-xstream-cdc-source-includes/examples.html#add-tables-to-the-capture-set)

# 4. Evaluate, if we can add multiple tables with different owner’s in the single connector 
See [multiples tables and schemas](https://staging-docs-independent.confluent.io/docs-kafka-connect-oracle-xstream-cdc-source/PR/11/0.2/cp-oracle-xstream-cdc-source-includes/examples.html#capture-multiple-tables-and-schemas)
See [remove table](https://staging-docs-independent.confluent.io/docs-kafka-connect-oracle-xstream-cdc-source/PR/11/0.2/cp-oracle-xstream-cdc-source-includes/examples.html#remove-tables-from-the-capture-set)

# 5. Include multiple tables for capture whether multiple capture process/xstream outbound servers are required.

Scale on bigger tables and divide big table to one outbound server. See [example](https://staging-docs-independent.confluent.io/docs-kafka-connect-oracle-xstream-cdc-source/PR/11/0.2/cp-oracle-xstream-cdc-source-includes/examples.html#add-an-outbound-server-to-an-existing-capture-process)

This sample create one capture and outbound server. And add an additional outbound server to the existing capture process with existing queue.

# 6. Pause/stop capture/xstream outbound server.

The connector pause and resume is straight forward.
So, what happened if you Pause/stop capture/xstream outbound server?

```sql
sqlplus c##ggadmin@orclcdb
SQL> BEGIN
 DBMS_XSTREAM_ADM.STOP_OUTBOUND(
 server_name => 'xout');
END;
/
-- # Infos, when servers started
SQL>SELECT STREAMS_NAME,
       PROCESS_TYPE,
       EVENT_NAME,
       DESCRIPTION,
       EVENT_TIME
  FROM DBA_REPLICATION_PROCESS_EVENTS where trunc(event_time) > sysdate -1 
  order by event_time;
-- start outbound 
SQL> BEGIN
 DBMS_XSTREAM_ADM.START_OUTBOUND(
 server_name => 'xout');
END;
/
```

You can the same with the capture process:

```sql
-- Get XOUT 
SQL> SELECT CAPTURE_NAME, STATUS FROM ALL_XSTREAM_OUTBOUND WHERE SERVER_NAME = 'XOUT';

-- stop capture
SQL> BEGIN
 DBMS_CAPTURE_ADM.STOP_CAPTURE(
 capture_name => 'CONFLUENT_XOUT1');
END;
/

-- # Infos, when servers started
SQL> SELECT STREAMS_NAME,
       PROCESS_TYPE,
       EVENT_NAME,
       DESCRIPTION,
       EVENT_TIME
  FROM DBA_REPLICATION_PROCESS_EVENTS where trunc(event_time) > sysdate -1 
  order by event_time;
```

no changes are visible in topic viewer. No error in connect log.

Start again:

```sql
-- start capture
SQL> BEGIN
 DBMS_CAPTURE_ADM.START_CAPTURE(
 capture_name => 'CONFLUENT_XOUT1');
END;
/

-- # Infos, when servers started
SQL> SELECT STREAMS_NAME,
       PROCESS_TYPE,
       EVENT_NAME,
       DESCRIPTION,
       EVENT_TIME
  FROM DBA_REPLICATION_PROCESS_EVENTS where trunc(event_time) > sysdate -1 
  order by event_time;
```

Data is again visible in topic viewer. And data will continue from lats offset.

# 7. Switch redo logs to generate archives and try resume/start capture/xstream server and see if it picks from archives.

Connect as sysdba and switch log file:

```sql
sqlplus sys/confluent123@orclcdb as sysdba
SQL> ALTER SYSTEM SWITCH LOGFILE;
```

No error in connect log. Everything is working stable.
No stop capture, switch log and start capture again.

```sql
-- stop capture
sqlplus c##ggadmin@orclcdb
SQL> BEGIN
 DBMS_CAPTURE_ADM.STOP_CAPTURE(
 capture_name => 'CONFLUENT_XOUT1');
END;
/
sqlplus sys/confluent123@orclcdb as sysdba
SQL> ALTER SYSTEM SWITCH LOGFILE;
sqlplus c##ggadmin@orclcdb
SQL> BEGIN
 DBMS_CAPTURE_ADM.START_CAPTURE(
 capture_name => 'CONFLUENT_XOUT1');
END;
/
```

No errors in log file. Connector stopped az 9442 offset and continued with 9443 offset.

Now, stop outbound, switch log and start again:

```sql
sqlplus c##ggadmin@orclcdb
-- stop outbound 
SQL> BEGIN
 DBMS_XSTREAM_ADM.STOP_OUTBOUND(
 server_name => 'xout');
END;
/
sqlplus sys/confluent123@orclcdb as sysdba
SQL> ALTER SYSTEM SWITCH LOGFILE;
sqlplus c##ggadmin@orclcdb
-- start outbound 
BEGIN
 DBMS_XSTREAM_ADM.START_OUTBOUND(
 server_name => 'xout');
END;
/
```

In my case it takes a while, till I see a change in topic viewer, need to refresh. But no errors. Stopped at 9451 and continues with offset 9452.

# 8. Alter capture to start from specific scn/time

I assume there is one running outbound server, and you will stop the capture process and start from a specific SCN.
If you would like to create an Outbound Server for a specific SVN, please follow this [sample](https://docs.confluent.io/cloud/current/connectors/cc-oracle-xstream-cdc-source/oracle-xstream-cdc-setup-includes/examples.html#create-a-capture-process-and-an-outbound-server-starting-from-a-specific-scn).

First, how to get a scn of a transaction?

```sql
sqlplus ordermgmt/kafka@ORCLPDB1
SQL> insert into region (region_name) values ('East-Europe');
SQL> commit;
SQL> insert into region (region_name) values ('North-Europe');
SQL> commit;
sqlplus sys/confluent123@ORCLCDB as sysdba
SQL> select current_scn from v$database;
 -- after 1. insert region 2315285
 -- after 2. insert region 2315354
```

We will now start the connector with an outbound server. This guy is doing the initial load, and later we do capture back to a SCN and see what is happening.
Start the outbound server first:

Login into Database via ssh in my case `ssh -i ~/keys/cmawsdemoxstream.pem ec2-user@X.X.X.X` and then:

```sql
sqlplus c##ggadmin@ORCLCDB
Password is Confluent12!
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
    source_container_name =>  'ORCLPDB1',   
    table_names           =>  tables,
    schema_names          =>  schemas,
    comment               => 'Confluent Xstream CDC Connector' );
-- set rentention
    DBMS_CAPTURE_ADM.ALTER_CAPTURE(
      capture_name => 'confluent_xout1',
      checkpoint_retention_time => 7
    );
END;
/
```

Before I start the connector, I do have the following SCNs

```sql
sqlplus sys@orclcdb as sysdba
SQL> select current_scn from v$database;
-- 2362861 before starting the connector
SQL> SELECT capture_name, first_scn, start_scn FROM ALL_CAPTURE where CAPTURE_NAME = 'CONFLUENT_XOUT1';
-- and capture process running first and start SCN = 2324480
```


Now, start the connector. In my case in a container.

Be

```bash
cd ../cdc-connector
# start environment, for Confluent colleques: Shutdown VPN, otherwise the instant client can not be loaded
docker-compose -f docker-compose-cdc-ccloud_new.yml up -d
docker-compose -f docker-compose-cdc-ccloud_new.yml ps
# Are connectors running?
curl -s -X GET -H 'Content-Type: application/json' http://localhost:8083/connectors | jq
# start connector with correct json config
curl -s -X POST -H 'Content-Type: application/json' --data @cdc_ccloud.json http://localhost:8083/connectors | jq
# Check status
curl -s -X GET -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/status | jq
```

Now the connector is running. If you have a look into topic viewer on topic orclpdb1.ordermgmt.regoins then we have 4 records coming from the initial load. All are tagged with `"op": "r"` which means coming from initial load.
If I do an insert now, we will get a new record in topic viewer.

```sql
sqlplus ordermgmt@orclcdb
-- insert
SQL> insert into regions(region_name) values ('North_Europe');
SQL> commit;
```

New entry will be visible in topic viewer. The new entry tagged with `"op": "c",`.

Now, I will try to stop capturing and going back to **SCN=2362861**.

```sql
sqlplus c##ggadmin@orclcdb
-- Get XOUT 
SQL> SELECT CAPTURE_NAME, STATUS FROM ALL_XSTREAM_OUTBOUND WHERE SERVER_NAME = 'XOUT';
-- Connector is attached.

-- stop capture
SQL> BEGIN
 DBMS_CAPTURE_ADM.STOP_CAPTURE(
 capture_name => 'CONFLUENT_XOUT1');
END;
/

-- # Infos, when servers started
SQL> SELECT STREAMS_NAME,
       PROCESS_TYPE,
       EVENT_NAME,
       DESCRIPTION,
       EVENT_TIME
  FROM DBA_REPLICATION_PROCESS_EVENTS where trunc(event_time) > sysdate -1 
  order by event_time;
```

no changes are visible in topic viewer. No error in connect log. 
I do now insert and store the SCN before that:

```sql
sqlplus sys/confluent123@orclcdb as sysdba
SQL> select current_scn from v$database;
-- 2362861
sqlplus ordermgmt/kafka@orclpdb1
SQL> insert into regions (region_name) values ('South-Europe');
SQL> COMMIT;
```

before alter the capturing process we need to know the first SCN of the capture process. The Start SCN value must be greater than or equal to the first SCN for the capture process. Also, the capture process must be stopped before resetting its start SCN.

```sql
sqlplus c##ggadmin@orclcdb
SQL> SELECT capture_name, first_scn, start_scn FROM ALL_CAPTURE where CAPTURE_NAME = 'CONFLUENT_XOUT1';
-- CONFLUENT_XOUT1	2324480    2324480
```

Alter the Capture process to start with **SCN=2362861**, first scn is lower, so altering must work.

```sql
BEGIN
  DBMS_CAPTURE_ADM.ALTER_CAPTURE(
    capture_name => 'CONFLUENT_XOUT1',
    start_scn    => 2362861);
END;
/
```

Start again:

```sql
-- start capture
SQL> BEGIN
 DBMS_CAPTURE_ADM.START_CAPTURE(
 capture_name => 'CONFLUENT_XOUT1');
END;
/
SQL> SELECT capture_name, first_scn, start_scn FROM ALL_CAPTURE where CAPTURE_NAME = 'CONFLUENT_XOUT1';
-- START_SCN should now be 2367935
-- # Infos, when servers started
SQL> SELECT STREAMS_NAME,
       PROCESS_TYPE,
       EVENT_NAME,
       DESCRIPTION,
       EVENT_TIME
  FROM DBA_REPLICATION_PROCESS_EVENTS where trunc(event_time) > sysdate -1 
  order by event_time;
```

Everything worked fine. Region South-Europe is visible in topic viewer, no errors in connect log so far.

> [!IMPORTANT]
> If the capture process is down for longer time, then Connector faile and stopped: `oracle.streams.StreamsException: ORA-26914: Unable to communicate with XStream capture process "CONFLUENT_XOUT1" from outbound server "XOUT".` In my trial it took **3-4 minutes** till the connector failed. The connector will retry up to three times before stopping and entering a failed state, which requires user intervention to resolve.

Do a restart if the connector failed.

```bash
curl -s -X PUT http://localhost:8083/connectors/XSTREAMCDC0/stop| jq
curl -s -X GET -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/status | jq
curl -s -X PUT http://localhost:8083/connectors/XSTREAMCDC0/resume | jq 
```

After restart the connector is working as expected for new DB changes.
But it could be happen, that in such cases (failed connector) you will lose data. So the better way would be to do a controlled maintenance:

1. stop the connector before doing the maintenance 
2. stop capturing, 
3. alter capturing
4. start capturing
5. restart connector

# 9. Alter connector to pick from prior time/scn.

The connector properties do not cover SCN like the old logminer CDC Connector from Confluent did. The correct way would to change SCN in Outbound Server setup. See [sample](https://docs.confluent.io/cloud/current/connectors/cc-oracle-xstream-cdc-source/oracle-xstream-cdc-setup-includes/examples.html#create-a-capture-process-and-an-outbound-server-starting-from-a-specific-scn)

# 10. Stop db/disable/enable archives and steps to restart capture/xstream outbound server and connector required during maintenance.

Connector is running.

Doing the DB stuff, stop DB, disable and enable archive

```bash
ssh -i ~/keys/cmawsdemoxstream.pem ec2-user@X.X.X.X
sudo docker exec -it oracle19c /bin/bash
sqlplus /nolog
CONNECT sys/confluent123 AS SYSDBA
-- disable archive log
shutdown immediate;
startup mount;
alter database noarchivelog;
alter database open;
```

The connector will crash immediately with the command `shutdown immediate` with error `org.apache.kafka.connect.errors.ConnectException: Failed to set session container to ORCLPDB1` and `Caused by: java.sql.SQLRecoverableException: ORA-12514: TNS:listener does not currently know of service requested in connect descriptor` . The connector stopped.

Continue with enablement.

```sql
-- enable archive log
shutdown immediate;
startup mount;
alter database archivelog;
alter database open;
ALTER SESSION SET CONTAINER=cdb$root;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER SESSION SET CONTAINER=ORCLPDB1;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
-- Made Logging asynchronous
ALTER SESSION SET CONTAINER=cdb$root;
ALTER SYSTEM SET commit_logging = 'BATCH' CONTAINER=ALL;
ALTER SYSTEM SET commit_wait = 'NOWAIT' CONTAINER=ALL;
exit;
```

Connector still stopped. OUTBOUND Server aborted as well.

Start Outbound Server:

```sql
sqlplus c##ggadmin@orclcdb
SQL> BEGIN
 DBMS_XSTREAM_ADM.START_OUTBOUND(
 server_name => 'xout');
END;
/
-- Check if everything is started
SQL> SELECT STREAMS_NAME,
       PROCESS_TYPE,
       EVENT_NAME,
       DESCRIPTION,
       EVENT_TIME
  FROM DBA_REPLICATION_PROCESS_EVENTS where trunc(event_time) > sysdate -1 
  order by event_time;
```

Restart Connector:

```bash
curl -s -X PUT http://localhost:8083/connectors/XSTREAMCDC0/stop | jq
curl -s -X GET -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/status | jq
curl -s -X PUT http://localhost:8083/connectors/XSTREAMCDC0/resume | jq 
```

Do an insert into regions table to see if data is moving into topic.

```sql
sqlplus ordermgmt/kafka@orclpdb1
SQL> insert into regions (region_name) values ('test4');
SQL> COMMIT;
```

New record is visible in orclpdb1.ordermgmt.regions topic.

Again, do a controlled maintenance process is the recommendation.

1. stop the connector before doing the maintenance 
2. stop outbound servers
3. do maintenance
4. start ountbound servers
5. restart connector

# 11. Test case, for long running transactions where we won’t commit and then we move or delete archives from the source and then commit. Check the connector status and data.

Test case for long running transactions is documented [here](https://github.com/ora0600/confluent-new-cdc-connector/tree/main?tab=readme-ov-file#long-running-transactions)

# 12. Test case scenario, if we move the archives or delete (Since in prod huge number of archives gets generates and we move the archives regularly via cron) while capture process is running what will be the status and how to manage.

If you run on current redolog files you will have no problems. If you have long running transaction which need archive logs then the connector will generate errors.
check in DB:

```sql
sqlplus sys/confluent123@orclcdb as sysdba
SQL> ARCHIVE LOG LIST
Database log mode              Archive Mode
Automatic archival             Enabled
Archive destination            /opt/oracle/product/19c/dbhome_1/dbs/arch
Oldest online log sequence     11
Next log sequence to archive   13
Current log sequence           13
```

Check on OS in DB, in my case:

```bash
ls -la /opt/oracle/product/19c/dbhome_1/dbs
-rw-r----- 1 oracle dba      254094848 Apr 23 08:25 arch1_10_1192789111.dbf
-rw-r----- 1 oracle dba          24576 Apr 23 08:25 arch1_11_1192789111.dbf
-rw-r----- 1 oracle dba       37450752 Apr 23 08:25 arch1_12_1192789111.dbf
-rw-r----- 1 oracle dba      180258304 Feb 11 10:46 arch1_5_1192789111.dbf
-rw-r----- 1 oracle dba      174172672 Feb 11 10:46 arch1_6_1192789111.dbf
-rw-r----- 1 oracle dba       47665152 Feb 11 10:46 arch1_7_1192789111.dbf
-rw-r----- 1 oracle dba       34589184 Feb 11 11:38 arch1_8_1192789111.dbf
-rw-r----- 1 oracle dba       37703680 Feb 11 11:38 arch1_9_1192789111.dbf
# and delete all
rm arch1*.dbf
```

In my case this would not be a problem, because I am working with current redologs. 
This is something what you can better test in your environment or with case 11.

# 13. Abrupt or normal shut down of source database and check the connector.

see case 10.

# 14. Any parameter to set at capture level to make sure it doesn’t consume much memory while extract/replicate.

Memory is strong performance enabler. 
**Configure Streams Pool and XStream Memory Limits**: As noted, the Streams pool must be large enough to hold buffered queued messages. You can also control how much of the Streams pool an XStream process will use via the MAX_SGA_SIZE parameters. For the capture process, use [DBMS_CAPTURE_ADM.SET_PARAMETER](https://docs.oracle.com/en/database/oracle/oracle-database/21/arpls/DBMS_CAPTURE_ADM.html#GUID-5A56325D-7613-4FDE-BBB9-0704B990E51F) to set MAX_SGA_SIZE(in MB) if you want to cap or guarantee memory for capture. Similarly, for the outbound server (apply), use DBMS_XSTREAM_ADM.SET_PARAMETER to adjust its MAX_SGA_SIZE. By default these may be “infinite” (i.e., up to what the Streams pool can provide) (XStream Guide ) (XStream Guide ), but it’s good to ensure they are not inadvertently too low. If these are too small, the capture process can hit its memory limit and start spilling to disk or throttling. Oracle documentation suggests using these to control memory per process and to ensure the sum for all capture/apply fits in the Streams pool (XStream Guide ). In high-throughput setups, allowing a capture process to use several hundred MB or a few GB in memory is often necessary.

# 15. Need to explore the monitoring of sessions of those connectors and any specific monitoring which needs our attention need to specify by confluent.

```sql
-- # Sessions
SQL> SELECT /*+PARAM('_module_action_old_length',0)*/ ACTION,
       username, 
       SID,
       SERIAL#,
       PROCESS,
       SUBSTR(PROGRAM,INSTR(PROGRAM,'(')+1,4) PROCESS_NAME
  FROM V$SESSION
  WHERE MODULE ='XStream';
-- outbound server
SQL> SELECT SERVER_NAME, 
       CONNECT_USER, 
       CAPTURE_USER, 
       CAPTURE_NAME,
       SOURCE_DATABASE,
       QUEUE_OWNER,
       QUEUE_NAME
  FROM ALL_XSTREAM_OUTBOUND;
-- Statistics, what was sent
SQL> SELECT SERVER_NAME,
       TOTAL_TRANSACTIONS_SENT,
       TOTAL_MESSAGES_SENT,
       (BYTES_SENT/1024)/1024 BYTES_SENT,
       (ELAPSED_SEND_TIME/100) ELAPSED_SEND_TIME,
       LAST_SENT_MESSAGE_NUMBER,
       TO_CHAR(LAST_SENT_MESSAGE_CREATE_TIME,'HH24:MI:SS MM/DD/YY') 
          LAST_SENT_MESSAGE_CREATE_TIME
  FROM V$XSTREAM_OUTBOUND_SERVER;
```  

# 16. Playing with offset 

check offset of current and running XStream Connector

```bash
# Status
# Check status
curl -s -X GET -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/status | jq
# First stop, No Data loss/duplication Requirement (Downtime ok), Stopping ensures that you get the latest offset.
curl -X PUT  http://localhost:8083/connectors/XSTREAMCDC0/stop | jq
curl -X GET http://localhost:8083/connectors/XSTREAMCDC0/status | jq
# Get offset, Get offset of self-managed connector, write down the offset
curl -s -X GET -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/offsets | jq
# Output 
#{
#  "offsets": [
#    {
#      "partition": {
#        "server": "ORCLPDB1"
#      },
#      "offset": {
#        "lcr_position": "000000000024e36b0000000000000000000000000024e36b000000000000000002"
#      }
#    }
#  ]
#}
```

Check to lowest lcr_position in DB

```sql
sqlplus c##ggadmin@orclcdb
SQL> SELECT SERVER_NAME,
       SOURCE_DATABASE,
       PROCESSED_LOW_POSITION,
       TO_CHAR(PROCESSED_LOW_TIME,'HH24:MI:SS MM/DD/YY') PROCESSED_LOW_TIME
FROM ALL_XSTREAM_OUTBOUND_PROGRESS; 
-- 000000000024E36B0000000000000000000000000024E36B000000000000000002 12:44:27 04/23/25
```

Change the offset of connector to the lowest LCR



```bash
# Status
curl -s -X GET -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/status | jq
# Add offset into a file:
echo "{
  \"offsets\": [
    {
      \"partition\": {
        \"server\": \"ORCLPDB1\"
      },
      \"offset\": {
        \"lcr_position\": \"000000000024E36B0000000000000000000000000024E36B000000000000000002\"
      }
    }
  ]
}" > lowest_lcroffset.json


# Patch of to lowest LCR
curl -s -X PATCH -H 'Content-Type: application/json' --data @lowest_lcroffset.json http://localhost:8083/connectors/XSTREAMCDC0/offsets | jq
# Resume connector
curl -s -X PUT http://localhost:8083/connectors/XSTREAMCDC0/resume | jq 
# Status
curl -s -X GET -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/status | jq

# From log
# INFO Found previous offset OracleOffsetContext [scn=null, lcr_position=000000000024E36B0000000000000000000000000024E36B000000000000000002] (io.confluent.connect.oracle.xstream.cdc.OracleXStreamSourceTask)
# INFO A previous offset indicating a completed snapshot has been found. (io.debezium.relational.RelationalSnapshotChangeEventSource)
# INFO Snapshot ended with SnapshotResult [status=SKIPPED, offset=OracleOffsetContext [scn=null, lcr_position=000000000024E36B0000000000000000000000000024E36B000000000000000002]] (io.debezium.pipeline.ChangeEventSourceCoordinator)
# INFO Connected metrics set to 'true' (io.debezium.pipeline.ChangeEventSourceCoordinator)
# INFO Starting streaming (io.debezium.pipeline.ChangeEventSourceCoordinator)
# INFO Starting data capture from XStream server. (io.confluent.connect.oracle.xstream.cdc.streaming.OracleStreamingChangeEventSource)
```
