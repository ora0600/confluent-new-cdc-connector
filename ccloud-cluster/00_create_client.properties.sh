#!/bin/bash

## Internal variables
pwd > basedir
export BASEDIR=$(cat basedir)
echo $BASEDIR

export envid=$1 
export clusterid=$2 
export connectorsa=$3 
export bootstrap=$4 
export connectorkey=$5 
export connectorsecret=$6 
export srrestpoint=$7 
export srkey=$8 
export srsecret=$9 
export ipaddresses=$(echo -e "$(terraform output -json ip_addresses)")
#echo $ipaddresses
# Egress IPs
export ipegress_temp=$(echo $ipaddresses | jq -r '.[].ip_prefix' |  xargs | sed -e 's/ /","/g')
export ipegress=$(echo $ipegress_temp | sed -e 's/"/\\"/g')
#echo $ipegress
export myip=$(dig +short myip.opendns.com @resolver1.opendns.com)
#echo $myip

# Get credentials for aws
source ../.accounts

# Generate .aws_Env for Oracle 19c
echo "export TF_VAR_myip="\"${myip}\""
if [ -z "${ipegress}" ]; then
    export TF_VAR_allowed_cidr_blocks="\"[\\\""${myip}\\\""]\""
else
    export TF_VAR_allowed_cidr_blocks="\"["\\\"${ipegress}\\\"",\\\""${myip}\\\""]\""
fi    
export TF_VAR_aws_access_key="\"${aws_access_key}\""
export TF_VAR_aws_secret_key="\"${aws_secret_key}\""
export TF_VAR_aws_region="\"${aws_region}\""
export TF_VAR_ssh_key_name="\"${ssh_key_name}\""
export TF_VAR_ami_oracle19c="\"${ami_oracle19c}\""
export TF_VAR_owner_email="\"${owner_email}\""
export confluent_cloud_api_key="\"${TF_VAR_confluent_cloud_api_key}\""
export confluent_cloud_api_secret="\"${TF_VAR_confluent_cloud_api_secret}\""
export envid="\"${envid}\""
export clusterid="\"${clusterid}\""
export said="\"${connectorsa}\""
export bootstrap="\"${bootstrap}\""
export connectorkey="\"${connectorkey}\""
export connectorsecret="\"${connectorsecret}\""
export srrestpoint="\"${srrestpoint}\""
export srkey="\"${srkey}\""
export srsecret="\"${srsecret}\"""> ../oracle19c/.aws_env

# Generate .aws_Env for Oracle 21c
echo "export TF_VAR_myip="\"${myip}\""
if [ -z "${ipegress}" ]; then
    export TF_VAR_allowed_cidr_blocks="\"[\\\""${myip}\\\""]\""
else
    export TF_VAR_allowed_cidr_blocks="\"["\\\"${ipegress}\\\"",\\\""${myip}\\\""]\""
fi    
export TF_VAR_aws_access_key="\"${aws_access_key}\""
export TF_VAR_aws_secret_key="\"${aws_secret_key}\""
export TF_VAR_aws_region="\"${aws_region}\""
export TF_VAR_ssh_key_name="\"${ssh_key_name}\""
export TF_VAR_ami_oracle19c="\"${ami_oracle19c}\""
export TF_VAR_owner_email="\"${owner_email}\""
export confluent_cloud_api_key="\"${TF_VAR_confluent_cloud_api_key}\""
export confluent_cloud_api_secret="\"${TF_VAR_confluent_cloud_api_secret}\""
export envid="\"${envid}\""
export clusterid="\"${clusterid}\""
export said="\"${connectorsa}\""
export bootstrap="\"${bootstrap}\""
export connectorkey="\"${connectorkey}\""
export connectorsecret="\"${connectorsecret}\""
export srrestpoint="\"${srrestpoint}\""
export srkey="\"${srkey}\""
export srsecret="\"${srsecret}\"""> ../oraclexe21c//.aws_env


# Generate .aws_Env for Oracle 23ai
echo "export TF_VAR_myip="\"${myip}\""
export TF_VAR_allowed_cidr_blocks="\"["\\\"${ipegress}\\\"",\\\""${myip}\\\""]\""
export TF_VAR_aws_access_key="\"${aws_access_key}\""
export TF_VAR_aws_secret_key="\"${aws_secret_key}\""
export TF_VAR_aws_region="\"${aws_region}\""
export TF_VAR_ssh_key_name="\"${ssh_key_name}\""
export TF_VAR_ami_oracle19c=""
export TF_VAR_owner_email="\"${owner_email}\""
export confluent_cloud_api_key="\"${TF_VAR_confluent_cloud_api_key}\""
export confluent_cloud_api_secret="\"${TF_VAR_confluent_cloud_api_secret}\""
export envid="\"${envid}\""
export clusterid="\"${clusterid}\""
export said="\"${connectorsa}\""
export bootstrap="\"${bootstrap}\""
export connectorkey="\"${connectorkey}\""
export connectorsecret="\"${connectorsecret}\""
export srrestpoint="\"${srrestpoint}\""
export srkey="\"${srkey}\""
export srsecret="\"${srsecret}\"""> ../oracle23ai/.aws_env

