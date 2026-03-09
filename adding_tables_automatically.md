# Adding new Tables to connector automatically

We have two options to run the connector:
1. Table level, all tables are explicite mentioned in connector and outbound server
2. Schema Level, every data table in the schema will be syncded with CDC Connector, without system tables and what you mentioned in the connector excluse table list.

Only Option 2. can be implemented in that way, that new tables will be added automatically in the future.

> [!IMPORTANT]
> We do later DDL changes. Oracle XStream Outbound 21c has [restrictions](https://docs.oracle.com/en/database/oracle/oracle-database/21/xstrm/xstream-out-restrictions.html#GUID-28827DFA-D78F-49AC-9724-9A496B78B695) with DDL. 

## Table Level
In General connectors are enabled at Table Level. To add tables you would follow [this guide](https://github.com/ora0600/confluent-new-cdc-connector/blob/main/adhoc-snapshot.md#2-use-case-add-tables-in-existing-outbound-server-and-do-ad-hoc-snapshots).

The main playbook would be:

1. Have signal table enabled (if you need ad-hoc snapshot, if not then snapshit_mode=no_data without signal)
2. Add table to outbound: DBMS_XSTREAM_ADM.ALTER_OUTBOUND
3. Check if rule is added correctly, query ALL_XSTREAM_RULES, and maybe check also capture|outbound status
4. Change connector config add table to table.include.list, in CCloud UI, Edit and Apply changes
5. Send the signal to do snapshot; `INSERT INTO cflt_signals (id, type, data) VALUES (random_uuid(), 'execute-snapshot',....`

Done. Table was added, and initial data was loaded

## Schema Level

CDC Connector synched a complete schema, maybe not all tables (use exclude table list here, and no system tables).

Pre-requs:
* Confluent Cloud Cluster is running
* Oracle XE 21c is running

1. First run Outbound Server with DDL enabled and Schema-Only

```bash
ssh -i ~/keys/cmawsdemoxstream.pem ec2-user@<IP_ADDRESS> 
# Wait till you see ...Cloud-init v. 22.2.2 finished at Mon....
sudo tail -f /var/log/cloud-init-output.log
sudo docker exec -it oracle21c /bin/bash
sqlplus sys/confluent123@XE as sysdba
SQL> set lines 200
COLUMN MEMBER FORMAT A40
COLUMN MEMBERS FORMAT 999
SELECT a.group#,b.member,a.members, a.bytes/1024/1024 as MB, a.status FROM v$log a,v$logfile b WHERE a.group# = b.group#;
# now configure Xstream
SQL> connect c##ggadmin@XE
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

Also this statement worked. So, I do not have a good sample. If you have one, please let me know.

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
> Do not change the Primary Key. In Oracle this change would work. But this change can not synched with Confluent.

