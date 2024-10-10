# Check for the existence of Docker and Podman
DOCKER := docker
PODMAN := podman

ifeq ($(shell command -v $(DOCKER) > /dev/null 2>&1 && echo true), true)
    CONTAINER_ENGINE := $(DOCKER)
else ifeq ($(shell command -v $(PODMAN) > /dev/null 2>&1 && echo true), true)
    CONTAINER_ENGINE := $(PODMAN)
else
    $(error Neither container engine (Docker or Podman) is installed. Please install one of them.)
endif

# EDA reports
eda:
	@echo "Hello eda"
	${CONTAINER_ENGINE} run hello-world
	@echo "The container engine in use is: $(CONTAINER_ENGINE)"
