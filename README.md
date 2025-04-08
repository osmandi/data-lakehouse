# Data Lakehouse

Tools used:
- `Podman`
- `Dremio`
- `Apache Iceberg`
- `Project Nessie`

## Requirements

- Podman (or Docker if you want): as container manager.
- `jq` CLI: as JSON query filter.

## Create the environment

Steps:
- Create the `.env` file using `.env_example` as example, completing the empty environment variables.
- Run `podman-compose -f docker-compose.yml up` and visit Dremio in [http://localhost:9047/](http://localhost:9047/).
- Create an Dremio account in [http://localhost:9047/](http://localhost:9047/).
- Configure your Dremio running the script `sh ./dremio_setup.sh`.
- Enjoy :)
