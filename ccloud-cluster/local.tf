resource "null_resource" "create_env_files" {
  depends_on = [
    resource.confluent_environment.cc_handson_env,
    data.confluent_schema_registry_cluster.advanced,
    resource.confluent_kafka_cluster.cc_kafka_cluster,
    resource.confluent_service_account.app_manager,
    resource.confluent_service_account.sr,
    resource.confluent_service_account.clients,
    resource.confluent_service_account.connectors,
    resource.confluent_api_key.app_manager_kafka_cluster_key,
    resource.confluent_api_key.sr_cluster_key,
    resource.confluent_api_key.clients_kafka_cluster_key,
    resource.confluent_api_key.connector_key,
  ]
  provisioner "local-exec" {
    command = "bash ./00_create_client.properties.sh ${confluent_environment.cc_handson_env.id} ${confluent_kafka_cluster.cc_kafka_cluster.id} ${confluent_service_account.connectors.id} ${confluent_kafka_cluster.cc_kafka_cluster.bootstrap_endpoint} ${confluent_api_key.connector_key.id} ${confluent_api_key.connector_key.secret} ${data.confluent_schema_registry_cluster.advanced.rest_endpoint} ${confluent_api_key.sr_cluster_key.id} ${confluent_api_key.sr_cluster_key.secret}"
  }
}