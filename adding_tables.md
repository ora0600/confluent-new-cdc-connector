# Adding tables

To add tables to and existing process starts in the DB. See [here](https://github.com/ora0600/confluent-new-cdc-connector/blob/main/README.md#7-add-new-table).

In one customer situation we had a couple of tables added to the capture process but the connector did only have one table.
To not wasting resources you could double check:

```bash
SQL> PROMPT ==== Monitoring XStream Rules for Tables====
COLUMN SCHEMA_NAME HEADING 'Schema|Name' FORMAT A10
COLUMN OBJECT_NAME HEADING 'Object|Name' FORMAT A20
SELECT distinct SCHEMA_NAME,
       OBJECT_NAME
  FROM ALL_XSTREAM_RULES where STREAMS_RULE_TYPE = 'TABLE' order by schema_name, object_name;
# Schema     Object
# Name       Name
# ---------- --------------------
# ORDERMGMT  CONTACTS
# ORDERMGMT  COUNTRIES
# ORDERMGMT  CUSTOMERS
# ORDERMGMT  EMPLOYEES
# ORDERMGMT  INVENTORIES
# ORDERMGMT  LOCATIONS
# ORDERMGMT  NOTES
# ORDERMGMT  ORDERS
# ORDERMGMT  ORDER_ITEMS
# ORDERMGMT  PRODUCTS
# DERMGMT  PRODUCT_CATEGORIES
# ORDERMGMT  REGIONS
# ORDERMGMT  WAREHOUSES
13 rows selected.
```

Then compare what it configured in the connector:

```bash
curl -s -X GET -H 'Content-Type: application/json' http://localhost:8083/connectors/XSTREAMCDC0/config | jq | grep "table.include.list"
#  "table.include.list": "ORDERMGMT.ORDER_ITEMS,ORDERMGMT.ORDERS,ORDERMGMT.EMPLOYEES,ORDERMGMT.PRODUCTS,ORDERMGMT.CUSTOMERS,ORDERMGMT.INVENTORIES,ORDERMGMT.PRODUCT_CATEGORIES",
```

In my case having 13 tables captured on DB, but need only 7 tables for the XStream connector. To remove tables from capture please follow this [link](https://docs.confluent.io/kafka-connectors/oracle-xstream-cdc-source/current/cp-oracle-xstream-cdc-source-includes/examples.html#remove-tables-from-the-capture-set). 


If you want to create a complete solution, you could implement a rest call to connector config in PL/SQL Function and add this to your monitoring query.