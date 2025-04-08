#! /usr/bin/bash

# Load environment variables
. ./.env

# Get Dremio token
DREMIO_TOKEN=$(curl -X POST "$DREMIO_HOST/apiv2/login" \
 --header 'Content-Type: application/json' \
 --data-raw '{ "userName": "'"$DREMIO_USERNAME"'", "password": "'"$DREMIO_PASSWORD"'"}' | jq -r ".token")

# Create Dremio space with the name Demo 
curl -X POST "$DREMIO_HOST/api/v3/catalog" \
--header "Authorization: $DREMIO_TOKEN" \
--header 'Content-Type: application/json' \
--data-raw '{"entityType": "space", "name": "Demo"}'

# Create Minio as Dremio source
curl -X POST "$DREMIO_HOST/api/v3/catalog" \
  --header "Authorization: $DREMIO_TOKEN" \
  --header 'Content-Type: application/json' \
  --data-raw '{"entityType": "source", "type": "S3", "name": "minio",  "config": {"accessKey": "'"$AWS_ACCESS_KEY_ID"'", "accessSecret": "'"$AWS_SECRET_ACCESS_KEY"'", "secure": false, "propertyList": [{"name": "fs.s3a.path.style.access", "value": true}, {"name": "fs.s3a.endpoint", "value": "minio:9000"}, {"name": "dremio.s3.compat", "value": true}], "rootPath": "/raw", "compatibilityMode": true, "credentialType": "ACCESS_KEY"}, "metadataPolicy":{"authTTLMs":86400000,"namesRefreshMs":3600000,"datasetRefreshAfterMs":3600000,"datasetExpireAfterMs":10800000,"datasetUpdateMode":"PREFETCH_QUERIED","deleteUnavailableDatasets":true,"autoPromoteDatasets":true}}'

# Create Nessie as Dremio Source
curl -X POST "$DREMIO_HOST/api/v3/catalog" \
  --header "Authorization: $DREMIO_TOKEN" \
  --header 'Content-Type: application/json' \
  --data-raw '{"entityType": "source", "type": "NESSIE", "name": "nessie", "config": {"nessieEndpoint": "http://nessie:19120/api/v2", "nessieAuthType": "NONE","credentialType": "ACCESS_KEY", "awsAccessKey": "'"$AWS_ACCESS_KEY_ID"'", "awsAccessSecret": "'"$AWS_SECRET_ACCESS_KEY"'", "awsRootPath": "/metadata", "secure": false, "propertyList": [{"name": "fs.s3a.path.style.access", "value": true}, {"name": "fs.s3a.endpoint", "value": "minio:9000"}, {"name": "dremio.s3.compat", "value": true}]}}'
