CONTAINER_ENGINE := docker

build:
	${CONTAINER_ENGINE} build --file ./docker/Dockerfile_eda -t eda ./docker

dev_eda:
	mkdir -p notebooks
	${CONTAINER_ENGINE} build --file ./docker/Dockerfile_dev_eda -t dev_eda ./docker
	${CONTAINER_ENGINE} run -p 8888:8888 -v ./raw_data:/home/jovyan/raw_data -v ./notebooks:/home/jovyan/notebooks dev_eda

# EDA reports
eda:
	mkdir -p eda/dataframes
	mkdir -p eda/reports
	${CONTAINER_ENGINE} build --file ./docker/Dockerfile_dev_eda -t eda ./docker
	${CONTAINER_ENGINE} run --rm -v ./scripts:/scripts -v ./eda:/home/eda -v ./raw_data:/home/raw_data \
		eda \
		python /scripts/EDA.py \
	|| rm -rf eda

# Run allways
#.PHONY: eda
