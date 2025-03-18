#!/bin/bash

## Internal variables
pwd > basedir
export BASEDIR=$(cat basedir)
echo $BASEDIR

export pubip=$1
export oracle_host=$1

source .aws_env

# Replace Parameters cdc_ccloud.json.template
# we need the srrestpoint without https://
broker="${bootstrap:11}"

cd ../cdc-connector/
# make a copy from template
cp cdc_ccloud.json.template cdc_ccloud.json
SCRIPT1="sed -i -e 's|##oracle_host##|$oracle_host|g' cdc_ccloud.json;"
SCRIPT2="sed -i -e 's|##oracle_host##|$oracle_host|g' cdc_ccloud.json;"
SCRIPT2="sed -i -e 's|##bootstrap##|$broker|g' cdc_ccloud.json;"
SCRIPT3="sed -i -e 's|##connectorkey##|$connectorkey|g' cdc_ccloud.json;"
SCRIPT4="sed -i -e 's|##connectorsecret##|$connectorsecret|g' cdc_ccloud.json;"
SCRIPT5="sed -i -e 's|##srkey:srsecret##|$srkey:$srsecret|g' cdc_ccloud.json;"
SCRIPT6="sed -i -e 's|##srrestpoint##|$srrestpoint|g' cdc_ccloud.json;"

# Change values
bash -c "$SCRIPT1"
bash -c "$SCRIPT2"
bash -c "$SCRIPT3"
bash -c "$SCRIPT4"
bash -c "$SCRIPT5"
bash -c "$SCRIPT6"
# Execute again because srrest was not changes
bash -c "$SCRIPT6"

mv cdc_ccloud.json-e cdc_ccloud.json

# Change the docker compose template
# make a copy from template
cp docker-compose-cdc-ccloud.yml.template docker-compose-cdc-ccloud_new.yml

SSCRIPT2="sed -i -e 's|##bootstrap##|$broker|g' docker-compose-cdc-ccloud_new.yml;"
SSCRIPT3="sed -i -e 's|##connectorkey##|$connectorkey|g' docker-compose-cdc-ccloud_new.yml;"
SSCRIPT4="sed -i -e 's|##connectorsecret##|$connectorsecret|g' docker-compose-cdc-ccloud_new.yml;"
SSCRIPT5="sed -i -e 's|##srkey:srsecret##|$srkey:$srsecret|g' docker-compose-cdc-ccloud_new.yml;"
SSCRIPT6="sed -i -e 's|##srrestpoint##|$srrestpoint|g' docker-compose-cdc-ccloud_new.yml;"
                       

# Change values
bash -c "$SSCRIPT2"
bash -c "$SSCRIPT3"
bash -c "$SSCRIPT4"
bash -c "$SSCRIPT5"
bash -c "$SSCRIPT6"
# Execute again because srrest was not changes
bash -c "$SSCRIPT6"

mv docker-compose-cdc-ccloud_new.yml-e docker-compose-cdc-ccloud_new.yml


