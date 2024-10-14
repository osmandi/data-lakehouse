CONTAINER_ENGINE := docker

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

# Run allways
#.PHONY: eda
