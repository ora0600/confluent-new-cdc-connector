 #!/bin/bash
# First enable Logging
export ORACLE_SID=FREE
echo "enable logging"
sqlplus /nolog @/opt/oracle/scripts/setup/01_setup_database.sql
echo "logging enabled"
# Install user, and data
sqlplus sys/confluent123@FREEPDB1 as sysdba @/opt/oracle/scripts/setup/02_create_user.sql
sqlplus ordermgmt/kafka@FREEPDB1 @/opt/oracle/scripts/setup/03_create_schema_datamodel.sql
sqlplus ordermgmt/kafka@FREEPDB1 @/opt/oracle/scripts/setup/04_load_data.sql
sqlplus ordermgmt/kafka@FREEPDB1 @/opt/oracle/scripts/setup/06_data_generator.sql
# Create CDC User and align all roles
sqlplus sys/confluent123@FREE as sysdba @/opt/oracle/scripts/setup/05_26ai_create_user.sql
sqlplus sys/confluent123@FREEPDB1 as sysdba @/opt/oracle/scripts/setup/05_26ai_privs.sql
