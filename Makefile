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

# # Dremio
# dremio-build:
# 	${CONTAINER_ENGINE} run -d -p 9047:9047 -p 31010:31010 -p 45678:45678 -p 32010:32010 --name dremio dremio/dremio-oss:25.1
# dremio-start:
# 	${CONTAINER_ENGINE} start dremio
# dremio-stop:
# 	${CONTAINER_ENGINE} stop dremio

# Generate token
dremio-token:
	@DREMIO_TOKEN=$(shell curl -X POST '$(DREMIO_HOST)/apiv2/login' \
		--header 'Content-Type: application/json' \
		--data-raw '{ "userName": "$(DREMIO_USERNAME)", "password": "$(DREMIO_PASSWORD)"}' | jq -c ".token"); \
		echo "DREMIO_TOKEN=$$DREMIO_TOKEN" > .DREMIO_TOKEN

# Create drmeio source
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
	--data-raw '{"sql": "SELECT LISTAGG(COLUMN_NAME, '\'','\'' ) columns_filtered FROM INFORMATION_SCHEMA.\"COLUMNS\" WHERE TABLE_SCHEMA = '\''nessie'\'' AND TABLE_NAME = '\''Terrazas_202104'\'' AND (COLUMN_NAME NOT LIKE '\''id_%'\'' OR COLUMN_NAME = '\''id_terraza'\'' ) AND COLUMN_NAME != '\''Escalera'\'' " }'

dremio-sql-detail: columns_filtered = $(shell curl -X GET '$(DREMIO_HOST)/api/v3/job/18f04eba-ef99-bfe4-2fd8-a2d9bf632500/results' \
	--header 'Authorization: $(DREMIO_TOKEN)' \
	--header 'Content-Type: application/json' | jq -r '.rows[0].columns_filtered')

dremio-sql-detail:
	curl -X POST '$(DREMIO_HOST)/api/v3/sql' \
	--header 'Authorization: $(DREMIO_TOKEN)' \
	--header 'Content-Type: application/json' \
	--data-raw '{"sql": "CREATE VIEW "Analista 1".Terraza_001 AS SELECT $(columns_filtered), 1 AS Superficie_TO FROM nessie.\"Terrazas_202104\"}'



# Steps
lakehouse-sources:
	curl -X POST '$(DREMIO_HOST)/api/v3/catalog' \
		--header 'Authorization: $(DREMIO_TOKEN)' \
		--header 'Content-Type: application/json' \
		--data-raw '{"entityType": "source", "type": "NESSIE", "name": "nessie", "config": {"nessieEndpoint": "http://nessie:19120/api/v2", "nessieAuthType": "NONE","credentialType": "ACCESS_KEY", "awsAccessKey": "$(AWS_ACCESS_KEY_ID)", "awsAccessSecret": "$(AWS_SECRET_ACCESS_KEY)", "awsRootPath": "/lakehouse", "secure": false, "propertyList": [{"name": "fs.s3a.path.style.access", "value": true}, {"name": "fs.s3a.endpoint", "value": "minio:9000"}, {"name": "dremio.s3.compat", "value": true}]}}' ; \
	curl -X POST '$(DREMIO_HOST)/api/v3/catalog' \
		--header 'Authorization: $(DREMIO_TOKEN)' \
		--header 'Content-Type: application/json' \
		--data-raw '{"entityType": "source", "type": "S3", "name": "minio-eda",  "config": {"accessKey": "$(AWS_ACCESS_KEY_ID)", "accessSecret": "$(AWS_SECRET_ACCESS_KEY)", "secure": false, "propertyList": [{"name": "fs.s3a.path.style.access", "value": true}, {"name": "fs.s3a.endpoint", "value": "minio:9000"}, {"name": "dremio.s3.compat", "value": true}], "rootPath": "/eda", "compatibilityMode": true, "credentialType": "ACCESS_KEY"}, "metadataPolicy":{"authTTLMs":86400000,"namesRefreshMs":3600000,"datasetRefreshAfterMs":3600000,"datasetExpireAfterMs":10800000,"datasetUpdateMode":"PREFETCH_QUERIED","deleteUnavailableDatasets":true,"autoPromoteDatasets":true}}' ; \
	curl -X POST '$(DREMIO_HOST)/api/v3/catalog' \
		--header 'Authorization: $(DREMIO_TOKEN)' \
		--header 'Content-Type: application/json' \
		--data-raw '{"entityType": "source", "type": "S3", "name": "minio-raw",  "config": {"accessKey": "$(AWS_ACCESS_KEY_ID)", "accessSecret": "$(AWS_SECRET_ACCESS_KEY)", "secure": false, "propertyList": [{"name": "fs.s3a.path.style.access", "value": true}, {"name": "fs.s3a.endpoint", "value": "minio:9000"}, {"name": "dremio.s3.compat", "value": true}], "rootPath": "/raw", "compatibilityMode": true, "credentialType": "ACCESS_KEY"}, "metadataPolicy":{"authTTLMs":86400000,"namesRefreshMs":3600000,"datasetRefreshAfterMs":3600000,"datasetExpireAfterMs":10800000,"datasetUpdateMode":"PREFETCH_QUERIED","deleteUnavailableDatasets":true,"autoPromoteDatasets":true}}'

lakehouse-load-data:
	# books
	curl -X POST '$(DREMIO_HOST)/api/v3/sql' \
	--header 'Authorization: $(DREMIO_TOKEN)' \
	--header 'Content-Type: application/json' \
	--data-raw '{"sql": "CREATE TABLE IF NOT EXISTS nessie.eda.books AS (SELECT * FROM \"minio-eda\".\"books.parquet\");"}'; \
	# Licencias_Locales_202104
	curl -X POST '$(DREMIO_HOST)/api/v3/sql' \
	--header 'Authorization: $(DREMIO_TOKEN)' \
	--header 'Content-Type: application/json' \
	--data-raw '{"sql": "CREATE TABLE IF NOT EXISTS nessie.eda.Licencias_Locales_202104 AS (SELECT * FROM \"minio-eda\".\"Licencias_Locales_202104.parquet\");"}'; \
	# Locales_202104
	curl -X POST '$(DREMIO_HOST)/api/v3/sql' \
	--header 'Authorization: $(DREMIO_TOKEN)' \
	--header 'Content-Type: application/json' \
	--data-raw '{"sql": "CREATE TABLE IF NOT EXISTS nessie.eda.Locales_202104 AS (SELECT * FROM \"minio-eda\".\"Locales_202104.parquet\");"}'; \
	# Terrazas_202104
	curl -X POST '$(DREMIO_HOST)/api/v3/sql' \
	--header 'Authorization: $(DREMIO_TOKEN)' \
	--header 'Content-Type: application/json' \
	--data-raw '{"sql": "CREATE TABLE IF NOT EXISTS nessie.eda.Terrazas_202104 AS (SELECT * FROM \"minio-eda\".\"Terrazas_202104.parquet\");"}'

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

# dremio-create-nessie-folder:
# 	curl -X POST '$(DREMIO_HOST)/api/v3/sql' \
# 	--header 'Authorization: $(DREMIO_TOKEN)' \
# 	--header 'Content-Type: application/json' \
# 	--data-raw '{"sql": "CREATE FOLDER IF NOT EXISTS nessie.etl;"}'

lakehouse-etl:
	$(CONTAINER_ENGINE) compose up etl
	#$(CONTAINER_ENGINE) run -v ./scripts:/home/docker/scripts --env-file ./.env alexmerced/spark33-notebook /bin/bash -c "python3 /home/docker/scripts/ETL.py"


# Remove folders used for create reports and dataset
clean:
	rm -rf eda
	rm -rf data_example
	rm -rf nessie-data

# Steps to make Lakehouse
lakehouse:
	@echo "Creating sources" && \
	$(MAKE) lakehouse-sources && \
	@echo "Creating spaces" && \
	$(MAKE) lakehouse-spaces && \
	@echo "Loading data" && \
	$(MAKE) lakehouse-load-data && \
	@echo "Lakehouse created successfully"
