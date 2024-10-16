CONTAINER_ENGINE := docker
include ./.env

# Generate data_example folder to unzipt raw_data
data_example:
	${CONTAINER_ENGINE} run --rm -v ./:/home/data alpine:3.20.3 sh -c "cd /home/data && unzip ./otros_origenes_de_datos.zip" \
	|| rm -rf data_example
	
dev-eda:
	mkdir -p notebooks
	${CONTAINER_ENGINE} build --file ./docker/Dockerfile_eda -t dev_eda ./docker
	${CONTAINER_ENGINE} run -p 8888:8888 -v ./raw_data:/home/jovyan/raw_data -v ./notebooks:/home/jovyan/notebooks dev_eda

# EDA reports
eda:
	@if ! [ -d "./data_example" ]; then \
		echo "Error: data_example folder not found"; \
	  exit 1; \
	fi
	mkdir -p eda/dataframes
	mkdir -p eda/reports
	${CONTAINER_ENGINE} build --file ./docker/Dockerfile_eda -t eda ./docker && \
	${CONTAINER_ENGINE} run --rm -v ./scripts:/scripts -v ./eda:/home/eda -v ./data_example:/home/raw_data \
		eda \
		python /scripts/EDA.py \
	|| rm -rf eda

# Dremio
dremio-build:
	${CONTAINER_ENGINE} run -d -p 9047:9047 -p 31010:31010 -p 45678:45678 -p 32010:32010 --name dremio dremio/dremio-oss:25.1
dremio-start:
	${CONTAINER_ENGINE} start dremio
dremio-stop:
	${CONTAINER_ENGINE} stop dremio

# Generate token
# TODO: Improve dremio token creation
dremio-token:
	@DREMIO_TOKEN=$(shell curl -X POST '$(DREMIO_HOST)/apiv2/login' \
		--header 'Content-Type: application/json' \
		--data-raw '{ "userName": "$(DREMIO_USERNAME)", "password": "$(DREMIO_PASSWORD)"}' | jq -c ".token"); \
		echo $$DREMIO_TOKEN > TOKEN

# Create drmeio source
dremio-source-nessie:
	curl -X POST '$(DREMIO_HOST)/api/v3/catalog' \
		--header 'Authorization: $(DREMIO_TOKEN)' \
		--header 'Content-Type: application/json' \
		--data-raw '{"entityType": "source", "type": "NESSIE", "name": "nessie", "config": {"nessieEndpoint": "http://nessie:19120/api/v2", "nessieAuthType": "NONE","credentialType": "ACCESS_KEY", "awsAccessKey": "$(MINIO_ROOT_USER)", "awsAccessSecret": "$(MINIO_ROOT_PASSWORD)", "awsRootPath": "/lakehouse", "secure": false, "propertyList": [{"name": "fs.s3a.path.style.access", "value": true}, {"name": "fs.s3a.endpoint", "value": "minio:9000"}, {"name": "dremio.s3.compat", "value": true}]}}'

dremio-source-minio-eda:
	curl -X POST '$(DREMIO_HOST)/api/v3/catalog' \
		--header 'Authorization: $(DREMIO_TOKEN)' \
		--header 'Content-Type: application/json' \
		--data-raw '{"entityType": "source", "type": "S3", "name": "minio-eda",  "config": {"accessKey": "$(MINIO_ROOT_USER)", "accessSecret": "$(MINIO_ROOT_PASSWORD)", "secure": false, "propertyList": [{"name": "fs.s3a.path.style.access", "value": true}, {"name": "fs.s3a.endpoint", "value": "minio:9000"}, {"name": "dremio.s3.compat", "value": true}], "rootPath": "/eda", "compatibilityMode": true, "credentialType": "ACCESS_KEY"}, "metadataPolicy":{"authTTLMs":86400000,"namesRefreshMs":3600000,"datasetRefreshAfterMs":3600000,"datasetExpireAfterMs":10800000,"datasetUpdateMode":"PREFETCH_QUERIED","deleteUnavailableDatasets":true,"autoPromoteDatasets":true}}'

dremio-source-minio-raw:
	curl -X POST '$(DREMIO_HOST)/api/v3/catalog' \
		--header 'Authorization: $(DREMIO_TOKEN)' \
		--header 'Content-Type: application/json' \
		--data-raw '{"entityType": "source", "type": "S3", "name": "minio-raw",  "config": {"accessKey": "$(MINIO_ROOT_USER)", "accessSecret": "$(MINIO_ROOT_PASSWORD)", "secure": false, "propertyList": [{"name": "fs.s3a.path.style.access", "value": true}, {"name": "fs.s3a.endpoint", "value": "minio:9000"}, {"name": "dremio.s3.compat", "value": true}], "rootPath": "/raw", "compatibilityMode": true, "credentialType": "ACCESS_KEY"}, "metadataPolicy":{"authTTLMs":86400000,"namesRefreshMs":3600000,"datasetRefreshAfterMs":3600000,"datasetExpireAfterMs":10800000,"datasetUpdateMode":"PREFETCH_QUERIED","deleteUnavailableDatasets":true,"autoPromoteDatasets":true}}'


# "metadataPolicy": { "autoPromoteDatasets": true},
# 8421adcf-2e15-43f8-b02a-de1bb32a9614
#		--data-raw '{"entityType": "source", "type": "NESSIE", "name": "nessie", "config": { "rootPath": "lakehouse", "accessKey": "$(MINIO_ROOT_USER)", "accessSecret": "$(MINIO_ROOT_PASSWORD)", "secure": false, "propertyList": [{"name": "fs.s3a.path.style.access", "value": true}, {"name": "fs.s3a.endpoint", "value": "minio:9000"}, {"name": "dremio.s3.compat", "value": true}], "compatibilityMode": true, "defaultCtasFormat": "ICEBERG", "credentialType": "ACCESS_KEY"}}'


dremio-catalog:
	curl -X GET '$(DREMIO_HOST)/api/v3/catalog' \
		--header 'Authorization: $(DREMIO_TOKEN)' \
		--header 'Content-Type: application/json'

dremio-catalog-id:
		curl -X GET '$(DREMIO_HOST)/api/v3/catalog/1795fc88-bcc3-422c-ba8a-7b22ad72d011' \
		--header 'Authorization: $(DREMIO_TOKEN)' \
		--header 'Content-Type: application/json'
	
dremio-create-space:
	curl -X POST '$(DREMIO_HOST)/api/v3/catalog' \
	--header 'Authorization: $(DREMIO_TOKEN)' \
	--header 'Content-Type: application/json' \
	--data-raw '{"entityType": "space", "name": "Analista Grande"}'

dremio-sql:
	curl -X POST '$(DREMIO_HOST)/api/v3/sql' \
	--header 'Authorization: $(DREMIO_TOKEN)' \
	--header 'Content-Type: application/json' \
	--data-raw '{"sql": "CREATE TABLE nessie.books_table AS (SELECT * FROM \"minio-eda\".\"books.parquet\");"}'

dremio-format:
		curl -X POST '$(DREMIO_HOST)/api/v3/catalog/1795fc88-bcc3-422c-ba8a-7b22ad72d011' \
		--header 'Authorization: $(DREMIO_TOKEN)' \
		--header 'Content-Type: application/json' \
		--data-raw '{"entityType": "dataset", "path": ["Licencias_Locales_202104.parquet"], "type": "PHYSICAL_DATASET", "format": {"type": "Parquet"}}'


# Steps
lakehouse-load-data:
	# books
	curl -X POST '$(DREMIO_HOST)/api/v3/sql' \
	--header 'Authorization: $(DREMIO_TOKEN)' \
	--header 'Content-Type: application/json' \
	--data-raw '{"sql": "CREATE TABLE IF NOT EXISTS nessie.books AS (SELECT * FROM \"minio-eda\".\"books.parquet\");"}'; \
	# Licencias_Locales_202104
	curl -X POST '$(DREMIO_HOST)/api/v3/sql' \
	--header 'Authorization: $(DREMIO_TOKEN)' \
	--header 'Content-Type: application/json' \
	--data-raw '{"sql": "CREATE TABLE IF NOT EXISTS nessie.Licencias_Locales_202104 AS (SELECT * FROM \"minio-eda\".\"Licencias_Locales_202104.parquet\");"}'; \
	# Locales_202104
	curl -X POST '$(DREMIO_HOST)/api/v3/sql' \
	--header 'Authorization: $(DREMIO_TOKEN)' \
	--header 'Content-Type: application/json' \
	--data-raw '{"sql": "CREATE TABLE IF NOT EXISTS nessie.Locales_202104 AS (SELECT * FROM \"minio-eda\".\"Locales_202104.parquet\");"}'; \
	# Terrazas_202104
	curl -X POST '$(DREMIO_HOST)/api/v3/sql' \
	--header 'Authorization: $(DREMIO_TOKEN)' \
	--header 'Content-Type: application/json' \
	--data-raw '{"sql": "CREATE TABLE IF NOT EXISTS nessie.Terrazas_202104 AS (SELECT * FROM \"minio-eda\".\"Terrazas_202104.parquet\");"}'

lakehouse-spaces:
	# Analista 1
	curl -X POST '$(DREMIO_HOST)/api/v3/catalog' \
	--header 'Authorization: $(DREMIO_TOKEN)' \
	--header 'Content-Type: application/json' \
	--data-raw '{"entityType": "space", "name": "Analista 1"}'; \
	# Analista 2
	curl -X POST '$(DREMIO_HOST)/api/v3/catalog' \
	--header 'Authorization: $(DREMIO_TOKEN)' \
	--header 'Content-Type: application/json' \
	--data-raw '{"entityType": "space", "name": "Analista 2"}'; \
	# Analista 3
	curl -X POST '$(DREMIO_HOST)/api/v3/catalog' \
	--header 'Authorization: $(DREMIO_TOKEN)' \
	--header 'Content-Type: application/json' \
	--data-raw '{"entityType": "space", "name": "Analista 3"}'


# Remove folders used for create reports and dataset
clean:
	rm -rf eda
	rm -rf data_example

# Run allways
#.PHONY: eda
