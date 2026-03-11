# Adding new Tables to connector automatically

We have two options to run the connector:
1. Table level, all tables are explicite mentioned in connector and outbound server, here you do have an automated setup.
2. Schema Level, every data table in the schema will be synced with CDC Connector, without system tables and without what you mentioned in the connector exclude table list.

Only Option 2 can be implemented in that way, that new tables will be added automatically in the future.

At the end I added a customer use case, which put all 13 Tables into one topic and adding later a table and change the structure.

> [!IMPORTANT]
> We do later DDL changes. Oracle XStream Outbound 21c has [restrictions](https://docs.oracle.com/en/database/oracle/oracle-database/21/xstrm/xstream-out-restrictions.html#GUID-28827DFA-D78F-49AC-9724-9A496B78B695) with DDL. 

## Table Level

Table Level setup is not automated. For better Security we recommend table level setup, because here you explicit implement what should be synched with CDC.
In General connectors are enabled at Table Level. To add tables you would follow [this guide](https://github.com/ora0600/confluent-new-cdc-connector/blob/main/adhoc-snapshot.md#2-use-case-add-tables-in-existing-outbound-server-and-do-ad-hoc-snapshots).

The main playbook would be:

1. Have signal table enabled (if you need ad-hoc snapshot, if not then snapshot_mode=no_data without signal)
2. Add table to outbound: DBMS_XSTREAM_ADM.ALTER_OUTBOUND
3. Check if rule is added correctly, query ALL_XSTREAM_RULES, and maybe check also capture|outbound status
4. Change connector config add table to table.include.list, in CCloud UI, Edit and Apply changes
5. Send the signal to do snapshot; `INSERT INTO cflt_signals (id, type, data) VALUES (random_uuid(), 'execute-snapshot',....`

Done. Table was added, and initial data was loaded

## Schema Level

CDC Connector synched a complete schema, maybe not all tables (use exclude table list here, and no system tables).
This setup will add tables automatically in the future.

Pre-requs:
* Confluent Cloud Cluster is running
* Oracle XE 21c is running

1. First run Outbound Server with DDL enabled and Schema-Only

```bash
ssh -i ~/keys/cmawsdemoxstream.pem ec2-user@<IP_ADDRESS> 
# Wait till you see ...Cloud-init v. 22.2.2 finished at Mon....
sudo tail -f /var/log/cloud-init-output.log
sudo docker exec -it oracle21c /bin/bash
sqlplus c##ggadmin@XE
Password is Confluent12!
# execute The CREATE_OUTBOUND procedure in the DBMS_XSTREAM_ADM package is used to create a capture process, queue, and outbound server in a single database
# Depended on your table.include.list in connector setup you would like to add alle tables here: In my case I do have 13 tables, you can use an arry like I do, or a comma sperated list
SQL> DECLARE
  tables  DBMS_UTILITY.UNCL_ARRAY;
  schemas DBMS_UTILITY.UNCL_ARRAY;
BEGIN
    tables(1)   := NULL;
    schemas(1)  := 'ORDERMGMT';        
    schemas(2)  := NULL;
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

2. Start Connector without include list and schema.history.internal.skip.unparseable.ddl=false

```bash
cd cdc-connector/
# change cflt_connectors.tf
#    "schema.history.internal.skip.unparseable.ddl" = "false"
#    "table.include.list"                           = ""

# Start connector
source .ccloud_env
terraform apply -auto-approve
```

Connector will be deployed successfully and listen to the outbound server for all tables in Schema ORDERMGMT.
Check in Confluent Cloud Cluster UI

3. Check-List

* All 13 Tables were loaded with inital data into topic.
* schema history topic was created `__orcl-schema-changes.XEPDB1.ID`
* heartbeat topic was created `__orcl-heartbeat.ID.XEPDB1`
* All 13 tables are listed in schema history topic `__orcl-schema-changes.XEPDB1.ID`

4. Create a new Table and Add Data into it.

```bash
SQL> connect ordermgmt/kafka@XEPDB1 
SQL> CREATE TABLE CMNEWTABLE (NUMMER NUMBER PRIMARY KEY, TEXT VARCHAR2(50));
SQL> insert into CMNEWTABLE values (1,'TEXT1');
SQL> commit;
```
Check schema history topic. New Table Statement should be synched successfully.
And the one record, should be visible in new created table topic `XEPDB1.ORDERMGMT.CMNEWTABLE` as well. 

This happened automatically.
Because this table was created, there is no need for an initial load, because it is a new table. Every data coming next in DB, is synced via CDC automatically.

4. Do some DDL stuff which can not be parsed. E.g. RESIZE SYSAUX Table 

Try add new datafile to Tablespace

```bash
SQL> connect sys/confluent123@XEPDB1 as sysdba
SQL> SELECT TABLESPACE_NAME, INITIAL_EXTENT, next_extent, MAX_SIZE FROM DBA_TABLESPACES WHERE TABLESPACE_NAME LIKE 'SYSAUX';
SQL> select TABLESPACE_NAME, FILE_NAME,AUTOEXTENSIBLE, MAXBYTES/1024/1024 as MAXMBytes from dba_Data_files where TABLESPACE_NAME like 'SYSAUX';
# Make next extent bigger
SQL> ALTER TABLESPACE SYSAUX ADD DATAFILE '/opt/oracle/oradata/XE/XEPDB1/sysaux02.dbf' SIZE 50M;
# The file is autoextend and has 32 GB on OS
```

This kind of Statement did not make any problems. 
If there are some unparsable DDL statements then it would be better to set "schema.history.internal.skip.unparseable.ddl": "true".

Let's try this:

```bash
SQL> connect ordermgmt/kafka@XEPDB1
SQL> CREATE TABLE SAMPLE_DAIL_LOG
            (MODULE VARCHAR2(2), 
            TRN_REF_NO VARCHAR2(16), 
            EVENT_SR_NO NUMBER, 
            EVENT VARCHAR2(4), 
        SUPPLEMENTAL LOG DATA (ALL) COLUMNS, 
        SUPPLEMENTAL LOG DATA (PRIMARY KEY) COLUMNS, 
        SUPPLEMENTAL LOG DATA (UNIQUE INDEX) COLUMNS, 
        SUPPLEMENTAL LOG DATA (FOREIGN KEY) COLUMNS
   );
```

Also this statement worked. So, I do not have a good sample. If you have one which could not be parsed by the connector, please let me know.

5. Change Table columns

```bash
SQL> connect ordermgmt/kafka@XEPDB1 
SQL> ALTER TABLE CMNEWTABLE ADD last_modified DATE;
SQL> insert into CMNEWTABLE values (2,'TEXT2', sysdate);
SQL> commit;
```

Schema history topic should now know this change. You will find the DDL statement in this topic.
Check is topic `XEPDB1.ORDERMGMT.CMNEWTABLE`
- Schema Version and content: The version number is now 2, and 2 has a new column
- now, we have 2 messages in the topic. Because schema has Compatibility mode = Backward there are no problem with adding column.

Let's try a column rename:
```bash
SQL> connect ordermgmt/kafka@XEPDB1 
SQL> ALTER TABLE CMNEWTABLE RENAME COLUMN TEXT to NR_TEXT;
SQL> DESC CMNEWTABLE
SQL> insert into CMNEWTABLE values (3,'TEXT3', sysdate);
SQL> commit;
```

Again we see
- change in schema history topic
- we have a version 3 of schema
- message was synched into topic
- We have 3 records in topic and each has a different schema id

> [!IMPORTANT]
> I tested with AVRO. Do not change the Primary Key or Unique Key or not null columns. In Oracle this change would work. But this change can not synched with Kafka cluster via CDC Connector. So, please be aware what you will change on a CDC-synched table. An not supported change can bring the system into an unstable state.

See following example:
Let's try a PK column rename:

```bash
SQL> connect ordermgmt/kafka@XEPDB1 
SQL> ALTER TABLE CMNEWTABLE RENAME COLUMN NUMMER to NR;
SQL> DESC CMNEWTABLE
SQL> insert into CMNEWTABLE values (4,'TEXT4', sysdate);
SQL> commit;
SQL> desc CMNEWTABLE
 Name                                      Null?    Type
 ----------------------------------------- -------- ----------------------------
 NR                                        NOT NULL NUMBER
 NR_TEXT                                            VARCHAR2(50)
 LAST_MODIFIED                                      DATE
```

In Oracle this worked pretty well. In Kafka we see the DDL in the schema history. But nothing more. And the Connector failed afterwards.

> [!CAUTION]
> The connector has failed to register a new schema with Schema Registry because it is incompatible with an existing schema for the same subject. Please update Schema Registry compatibility settings globally or for the topic to ensure that it works with the data that the connector is reading.

A Restart would not work. You need somehow fix the problem. The point here is, think first before you doing something at a DDL level. It would be better maybe to change the Schema Evolution first: Compatibility mode = FORWARD.

How you could change the table and still have no breaks in Kafka. Thank you for hint from my colleague David.
Before you alter column you can just set Compatibility mode = NONE in Table topic data contract.

These are the steps if you did fail as mentioned before:

```bash
alter non-option column causing fail
set  Compatibility mode = NONE
restart connector
check table topic 
can see new schema registered and messages that failed are automatically re-processed 
set back to  Compatibility mode = FORWARD
continue as normal
```
It is a bit risky changing to  Compatibility mode = NONE  but the only way I can get it back into a stable state and automatically process failed messages.

## load 13 Tables in one topic and to change on a table.

pre-req
* cluster is running
* Db is running

Start the outbound server
```bash
ssh -i ~/keys/cmawsdemoxstream.pem ec2-user@X.X.X.X 
sudo docker exec -it oracle21c /bin/bash
# Please check redos first
sqlplus c##ggadmin@XE
Password is Confluent12!
# execute The CREATE_OUTBOUND procedure in the DBMS_XSTREAM_ADM package is used to create a capture process, queue, and outbound server in a single database
# Depended on your table.include.list in connector setup you would like to add alle tables here: In my case I do have 13 tables, you can use an arry like I do, or a comma sperated list
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

Now, start the ccloud Connector by `terraform apply`. We use the following setup:

```JSON
# --------------------------------------------------------
# Connector
# --------------------------------------------------------
# Oracle CDC 
resource "confluent_connector" "oraclecdc" {
  environment {
    id = var.envid
  }
  kafka_cluster {
    id = var.clusterid
  }
  config_sensitive = {}
  config_nonsensitive = {
    "connector.class"                   = "OracleXStreamSource"
    "name"                              = "OracleXStreamSourceConnector_0"
    "kafka.auth.mode"                   = "SERVICE_ACCOUNT"
    "kafka.service.account.id"          = var.said
    "schema.context.name"               = "default"
    "database.hostname"                 = var.oracle_host
    "database.port"                     = "1521"
    "database.user"                     = "C##GGADMIN"
    "database.password"                 = "Confluent12!"
    "database.dbname"                   = "XE"
    "database.service.name"             = "XE"
    "database.pdb.name"                 = "XEPDB1"
    "topic.prefix"                      = "XEPDB1"
    "database.out.server.name"          = "XOUT"
    "database.tls.mode"                 = "disable"
    "database.processor.licenses"       = "2"
    "output.key.format"                 = "AVRO"
    "output.data.format"                = "AVRO"
    "table.include.list"                = "ORDERMGMT[.](ORDER_ITEMS|ORDERS|EMPLOYEES|PRODUCTS|CUSTOMERS|INVENTORIES|PRODUCT_CATEGORIES|CONTACTS|NOTES|WAREHOUSES|LOCATIONS|COUNTRIES|REGIONS)"
    "snapshot.mode"                     = "initial"
    "skipped.operations"                = "t"
    "signal.data.collection"            = "XEPDB1.ORDERMGMT.CFLT_SIGNALS"
    "schema.history.internal.skip.unparseable.ddl" = "false"
    "snapshot.database.errors.max.retries"         = "0"
    "tombstones.on.delete"              = "true"
    "schema.name.adjustment.mode"       = "none"
    "field.name.adjustment.mode"        = "none"
    "heartbeat.interval.ms"             = "300000"
    "database.os.timezone"              = "UTC"
    "decimal.handling.mode"             = "precise"
    "time.precision.mode"               = "adaptive"
    "tasks.max"                         =  "1"
    "auto.restart.on.user.error"        = "true"
    "value.converter.decimal.format"    = "BASE64"
    "transforms"                        = "OneTopic"
    "transforms.OneTopic.type"          = "io.confluent.connect.cloud.transforms.TopicRegexRouter"
    "transforms.OneTopic.regex"         = "XEPDB1.ORDERMGMT.*"
    "transforms.OneTopic.replacement"   =  "cm-one-topic"
    "value.converter.value.subject.name.strategy"     = "RecordNameStrategy" 
    "key.converter.key.subject.name.strategy"         = "RecordNameStrategy"
    "value.converter.use.latest.version"              = "true"
  }
  depends_on = [
  ]
  lifecycle {
    prevent_destroy = false
  }
}
```

Connector is running and all 13 tables are now synced into one topic `cm-one-topic`. In total we have now 3 Topics: Heartbeat, Schema history and `cm-one-topic`
Each record uses now different schemass based on the tablestructure.

Schema history topic has all 13 table creation statements.


> [!IMPORTANT]
> We use the Confluent SMT TopicRegexRouter here. This is only available in Confluent Cloud. Be aware that not all SMTs are supported with the Confluent Oracle XStream CDC Source connector. Please the documentation.

Now, we add a table to DB schema, alter the outbound and Apply new include table list to the connector. And then add a column to this new column
This is a real customer use case, we will check if the supported SMT TopicRegexRouter can handle Schema Changes in DB.

Create Table:

```bash
SQL> connect ordermgmt/kafka@XEPDB1 
SQL> CREATE TABLE CMNEWTABLE2 (NUMMER NUMBER PRIMARY KEY, TEXT VARCHAR2(50));
```

Add to Outbound:

```bash
SQL> connect c##ggadmin@XE
# Add table to outbound server
SQL> DECLARE
  tables  DBMS_UTILITY.UNCL_ARRAY;
  schemas DBMS_UTILITY.UNCL_ARRAY;
BEGIN
  tables(1)  := 'ORDERMGMT.CMNEWTABLE2';
  schemas(1) := NULL;
  DBMS_XSTREAM_ADM.ALTER_OUTBOUND(
    server_name           =>  'xout',
    source_container_name =>  'XEPDB1',
    table_names           =>  tables,
    schema_names          =>  schemas,
    add                   =>  true);
END;
/
```

Now, change the include table list parameter in config of the connector. I use the UI of Connector in the Confluent Cloud UI. Edit the property table.include.list to `ORDERMGMT[.](ORDER_ITEMS|ORDERS|EMPLOYEES|PRODUCTS|CUSTOMERS|INVENTORIES|PRODUCT_CATEGORIES|CONTACTS|NOTES|WAREHOUSES|LOCATIONS|COUNTRIES|REGIONS|CMNEWTABLE2)` and click save changes. Now, click apply changes.

The connector should now synch the table.

```bash
SQL> connect ordermgmt/kafka@XEPDB1 
SQL> insert into CMNEWTABLE2 values (2,'TEXT2');
SQL> commit;
```

The record is synced with Kafka und produced into cm-one-topic with Schema ID: 100030

```JSON
{
  "before": null,
  "after": {
    "XEPDB1.ORDERMGMT.CMNEWTABLE2.Value": {
      "NUMMER": {
        "io.debezium.data.VariableScaleDecimal": {
          "scale": 0,
          "value": {
            "0": 2
          }
        }
      },
      "TEXT": {
        "string": "TEXT2"
      }
    }
  },
  "source": {
    "version": "1.3.3-rc-f18e774-cloud",
    "connector": "Oracle XStream CDC",
    "name": "XEPDB1",
    "ts_ms": 1773231472307,
    "snapshot": {
      "string": "false"
    },
    "db": "XEPDB1",
    "sequence": null,
    "ts_us": {
      "long": 1773231472307874
    },
    "ts_ns": {
      "long": 1773231472307874966
    },
    "schema": "ORDERMGMT",
    "table": "CMNEWTABLE2",
    "txId": {
      "string": "2.20.574"
    },
    "scn": {
      "string": "3691126"
    },
    "lcr_position": {
      "string": "000000000038527a00000001000000010000000000385276000000010000000102"
    },
    "user_name": null,
    "row_id": {
      "string": "AAAShbAAMAAAAIkAAA"
    }
  },
  "transaction": null,
  "op": "c",
  "ts_ms": {
    "long": 1773231474630
  },
  "ts_us": {
    "long": 1773231474630085
  },
  "ts_ns": {
    "long": 1773231474630085186
  }
}
```

We see the create statement in Schema history topic now as well (after the first insert, because we did not do an adhoc-snapshot):

```JSON
{
  "source": {
    "server": "XEPDB1"
  },
  "position": {
    "lcr_position": "000000000038527a00000001000000010000000000385276000000010000000102"
  },
  "ts_ms": 1773231474515,
  "databaseName": "XEPDB1",
  "schemaName": "ORDERMGMT",
  "ddl": "CREATE TABLE \"ORDERMGMT\".\"CMNEWTABLE2\" \n   (\t\"NUMMER\" NUMBER, \n\t\"TEXT\" VARCHAR2(50), \n\t PRIMARY KEY (\"NUMMER\")\n  USING INDEX  ENABLE, \n\t SUPPLEMENTAL LOG DATA (PRIMARY KEY) COLUMNS, \n\t SUPPLEMENTAL LOG DATA (UNIQUE INDEX) COLUMNS, \n\t SUPPLEMENTAL LOG DATA (FOREIGN KEY) COLUMNS\n   )",
  "tableChanges": [
   ....
}
```

Change Table in DB:

```bash
SQL> connect ordermgmt/kafka@XEPDB1 
SQL> ALTER TABLE CMNEWTABLE2 ADD last_modified DATE;
SQL> insert into CMNEWTABLE2 values (3,'TEXT3', sysdate);
SQL> commit;
```

The DDL change was synched with Schema history topic.
And the new record was send as well correctly with Schema ID 100031.

```JSON
{
  "before": null,
  "after": {
    "XEPDB1.ORDERMGMT.CMNEWTABLE2.Value": {
      "NUMMER": {
        "io.debezium.data.VariableScaleDecimal": {
          "scale": 0,
          "value": {
            "0": 3
          }
        }
      },
      "TEXT": {
        "string": "TEXT3"
      },
      "LAST_MODIFIED": {
        "long": 1773231646000
      }
    }
  },
  "source": {
    "version": "1.3.3-rc-f18e774-cloud",
    "connector": "Oracle XStream CDC",
    "name": "XEPDB1",
    "ts_ms": 1773231647000,
    "snapshot": {
      "string": "false"
    },
    "db": "XEPDB1",
    "sequence": null,
    "ts_us": {
      "long": 1773231647000000
    },
    "ts_ns": {
      "long": 1773231647000000000
    },
    "schema": "ORDERMGMT",
    "table": "CMNEWTABLE2",
    "txId": {
      "string": "10.23.557"
    },
    "scn": {
      "string": "3691724"
    },
    "lcr_position": {
      "string": "00000000003854d6000000010000000100000000003854cc000000010000000102"
    },
    "user_name": null,
    "row_id": {
      "string": "AAAShbAAMAAAAIkAAB"
    }
  },
  "transaction": null,
  "op": "c",
  "ts_ms": {
    "long": 1773231654905
  },
  "ts_us": {
    "long": 1773231654905953
  },
  "ts_ns": {
    "long": 1773231654905953742
  }
}
```

So, also under this circumstances the connector worked as expected. Schema Handling is done automatically, the only thing what to do is to add new table to outbound server and connector.
