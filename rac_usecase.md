# XStream and Real Application Cluster

Follow Oracle Documentation [here](https://docs.oracle.com/en/database/oracle/oracle-database/19/xstrm/xstream-out-concepts.html#GUID-A058CE29-4D13-4EB2-ACDE-29DC6B7F2CDE).

Oracle recommends that you configure Oracle RAC database clients to use the SCAN to connect to the database instead of configuring the tnsnames.ora file. See [here](https://docs.oracle.com/en/database/oracle/oracle-database/18/rilin/about-connecting-to-an-oracle-rac-database-using-scans.html).

How to setup database connections with SCAN addresses is documented [here](https://docs.oracle.com/en/database/oracle/oracle-database/18/rilin/how-database-connections-are-created-when-using-scans.html#GUID-DDA82589-44DB-4681-B0BC-32898D3083BA). The documentation uses EZCONNECT method.

## Confluent Connector properties

`database.service.name`
Name of the database service to which to connect. In a multitenant container database, this is the service used to connect to the container database (CDB). **For Oracle Real Application Clusters (RAC), use the service created by Oracle XStream.**

* Type: string
* Valid Values: Must match the regex ^([a-zA-Z][a-zA-Z0-9$#._]*)*$
* Importance: high

Configure the `database.hostname` property to the Oracle RAC database SCAN address.

See documentation for [Confluent Cloud](https://docs.confluent.io/cloud/current/connectors/cc-oracle-xstream-cdc-source/cc-oracle-xstream-cdc-source.html#connect-to-an-oracle-real-application-cluster-rac-database) or [Confluent Platform](https://docs.confluent.io/kafka-connectors/oracle-xstream-cdc-source/current/getting-started.html#connect-to-an-oracle-real-application-cluster-rac-database) Connector.


## Database 

on the database side you need to add use_rac_service see [Confluent Documentation](https://docs.confluent.io/cloud/current/connectors/cc-oracle-xstream-cdc-source/oracle-xstream-cdc-setup-includes/prereqs-validation.html#capture-changes-from-oracle-rac).

```bash
SQL> BEGIN
  DBMS_CAPTURE_ADM.SET_PARAMETER(
    capture_name => '<CAPTURE_NAME>',
    parameter    => 'use_rac_service',
    value        => 'Y');
END;
/
```

## What if one instances of the RAC crashed?

Confluent[documentation](https://docs.confluent.io/cloud/current/connectors/cc-oracle-xstream-cdc-source/oracle-xstream-cdc-setup-includes/prereqs-validation.html#capture-changes-from-oracle-rac) says:
`If the current owner instance of the queue becomes unavailable, ownership of the queue is automatically transferred to another instance in the cluster. The capture process and the outbound server are restarted automatically on the new owner instance. The connector will restart and attempt to reconnect to the cluster using the configured connection properties.`

And Oracle [documentation](https://docs.oracle.com/en/database/oracle/oracle-database/19/xstrm/xstream-out-concepts.html#GUID-A058CE29-4D13-4EB2-ACDE-29DC6B7F2CDE) says:
`If the value for the capture process parameter use_rac_service is set to Y, then each capture process is started and stopped on the owner instance for its ANYDATA queue, even if the start or stop procedure is run on a different instance. Also, a capture process follows its queue to a different instance if the current owner instance becomes unavailable. The queue itself follows the rules for primary instance and secondary instance ownership....If the owner instance for a queue table containing a queue used by a capture process becomes unavailable, then queue ownership is transferred automatically to another instance in the cluster. In addition, if the capture process was enabled when the owner instance became unavailable, then the capture process is restarted automatically on the new owner instance. If the capture process was disabled when the owner instance became unavailable, then the capture process remains disabled on the new owner instance...f the owner instance for a queue table containing a queue used by an outbound server becomes unavailable, then queue ownership is transferred automatically to another instance in the cluster. Also, an outbound server will follow its queue to a different instance if the current owner instance becomes unavailable. The queue itself follows the rules for primary instance and secondary instance ownership. In addition, if the outbound server was enabled when the owner instance became unavailable, then the outbound server is restarted automatically on the new owner instance. If the outbound server was disabled when the owner instance became unavailable, then the outbound server remains disabled on the new owner instance.` 