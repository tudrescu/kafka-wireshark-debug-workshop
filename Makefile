.PHONY: *

.DEFAULT_GOAL := help

CURRENT_MKFILE := $(abspath $(lastword $(MAKEFILE_LIST)))
CURRENT_DIR := $(realpath $(dir $(CURRENT_MKFILE)))

PROJECT_NAME := $(shell basename $(abspath $(CURRENT_DIR)))
PROJECT_DESCRIPTION := "Decrypt TLS traffic to Kafka using Wireshark"

SHELL=/bin/bash -eu -o pipefail

echo_stdout_header = printf "\n+++++++++++++ $(1)\n"
echo_stdout_footer = printf "+++++++++++++ $(1)\n"
echo_fail = printf "\e[31m✘ \033\e[0m$(1)\n"
echo_pass = printf "\e[32m✔ \033\e[0m$(1)\n"

check-dependency = $(if $(shell command -v $(1)),$(call echo_pass,found $(1)),$(call echo_fail,$(1) not installed);exit 1)

check-var-defined = $(if $(strip $($1)),,$(error "$1" is not defined))

BUILD_DIR := build
DOCKERFILES_DIR ?= dockerfiles

# tcpdump --------------------
TCPDUMP_DOCKERFILE ?= tcpdump.Dockerfile
TCPDUMP_CONTAINER ?= docker-tcpdump

# jsslkeylog -----------------
JSSLKEYLOG_VERSION ?= 1.2
JSSLKEYLOG_NAME ?= jSSLKeyLog
JSSLKEYLOG_ARCHIVE ?= $(JSSLKEYLOG_NAME)-$(JSSLKEYLOG_VERSION)-src.zip
JSSLKEYLOG_DOWNLOAD_URL ?= https://sourceforge.net/projects/jsslkeylog/files/jsslkeylog-$(JSSLKEYLOG_VERSION)/$(JSSLKEYLOG_ARCHIVE)/download

MAVEN_DOCKER_VERSION ?= 3.6.3-jdk-8
JDK_VERSION ?= 1.8

# kafkacat -------------------
KAFKACAT_VERSION ?= 1.5.0
KAFKACAT_DOWNLOAD_URL ?= https://github.com/edenhill/kafkacat.git

KAFKACAT_DOCKERFILE ?= kafkacat.Dockerfile
KAFKACAT_CONTAINER ?= docker-kafkacat

# wireshark -----------------
WIRESHARK_CONTAINER ?= docker-wireshark

help:            ## Show this help.
	@$(call echo_stdout_header)       
	@echo "$(PROJECT_NAME) : $(PROJECT_DESCRIPTION)"
	@$(call echo_stdout_footer, "\\n")
	@echo -e \
		"$$(grep -hE '^\S+:.*##' $(MAKEFILE_LIST) | \
		sed -e 's/:.*##\s*/:/' -e 's/^\(.\+\):\(.*\)/\\x1b[36m\1\\x1b[m:\2/' | \
		column -c2 -t -s :)"


check-dependencies:
	@$(call check-dependency,docker)
	@$(call check-dependency,docker-compose)
	@$(call check-dependency,wget)
	@$(call check-dependency,git)
	@$(call check-dependency,unzip)
	@$(call check-dependency,openssl)
	@$(call check-dependency,keytool)


init: check-dependencies   ## Checks dependencies
	@echo
	@$(call echo_pass,dependency check complete)


build-docker-tcpdump: 	        ## Build docker container with tcpdump
	@$(call echo_stdout_header, Building docker-tcpdump)
	mkdir -p $(CURRENT_DIR)/${BUILD_DIR}/build-docker-tcpdump
	@echo "current path $(CURRENT_DIR)/${BUILD_DIR}/build-docker-tcpdump"
	cd $(CURRENT_DIR)/${BUILD_DIR}/build-docker-tcpdump && \
	docker build -f "${CURRENT_DIR}/${DOCKERFILES_DIR}/${TCPDUMP_DOCKERFILE}" -t "${TCPDUMP_CONTAINER}" --no-cache .
	rm -rf $(CURRENT_DIR)/${BUILD_DIR}/build-docker-tcpdump
	@$(call echo_stdout_footer, Finished building docker-tcpdump)



build-jsslkeylog: 	            ## build jSSLKeyLog.jar from source
	@$(call echo_stdout_header, Building jSSLKeyLog Agent)
	mkdir -p $(CURRENT_DIR)/${BUILD_DIR}/build-jsslkeylog
	@echo "Download $(JSSLKEYLOG_ARCHIVE)"
	wget -q -O $(CURRENT_DIR)/${BUILD_DIR}/build-jsslkeylog/$(JSSLKEYLOG_ARCHIVE) ${JSSLKEYLOG_DOWNLOAD_URL}
	unzip -o $(CURRENT_DIR)/${BUILD_DIR}/build-jsslkeylog/$(JSSLKEYLOG_ARCHIVE) -d $(CURRENT_DIR)/${BUILD_DIR}/build-jsslkeylog/$(JSSLKEYLOG_NAME)-$(JSSLKEYLOG_VERSION)-src
	docker run -it \
		--rm \
		-u `id -u` \
		--name jsslkeylog \
		-v "$(CURRENT_DIR)/${BUILD_DIR}/build-jsslkeylog/${JSSLKEYLOG_NAME}-${JSSLKEYLOG_VERSION}-src":/usr/src/mymaven \
		-w /usr/src/mymaven \
		maven:"${MAVEN_DOCKER_VERSION}" mvn clean install \
		-Dmaven.compiler.source="${JDK_VERSION}" \
		-Dmaven.compiler.target="${JDK_VERSION}"
	@cp "$(CURRENT_DIR)/${BUILD_DIR}/build-jsslkeylog/${JSSLKEYLOG_NAME}-${JSSLKEYLOG_VERSION}-src/${JSSLKEYLOG_NAME}.jar" "$(CURRENT_DIR)/tools/"
	rm -rf $(CURRENT_DIR)/${BUILD_DIR}/build-jsslkeylog
	@$(call echo_stdout_footer, Finished building jSSLKeyLog Agent)


build-docker-kafkacat: 	      ## build docker container with kafkacat
	@$(call echo_stdout_header, Building docker-kafkacat)
	mkdir -p $(CURRENT_DIR)/${BUILD_DIR}/build-docker-kafkacat
	git clone "${KAFKACAT_DOWNLOAD_URL}" --branch="${KAFKACAT_VERSION}" $(CURRENT_DIR)/${BUILD_DIR}/build-docker-kafkacat/kafkacat
	cd $(CURRENT_DIR)/${BUILD_DIR}/build-docker-kafkacat/kafkacat && \
	docker build -f "$(CURRENT_DIR)/${DOCKERFILES_DIR}/${KAFKACAT_DOCKERFILE}" -t "${KAFKACAT_CONTAINER}" --no-cache .
	rm -rf $(CURRENT_DIR)/${BUILD_DIR}/build-docker-kafkacat
	@$(call echo_stdout_footer, Finished building docker-kafkacat)


build-docker-wireshark: 	   ## build docker container with Wireshark and Xpra
	@$(call echo_stdout_header, Building docker-wireshark)
	cd $(CURRENT_DIR)/${DOCKERFILES_DIR}/docker-wireshark && \
	docker build -t ${WIRESHARK_CONTAINER} --no-cache .
	@$(call echo_stdout_footer, Finished building docker-wireshark)


build-all: init                   ## build dependencies
	@make --no-print-directory build-docker-tcpdump
	@make --no-print-directory build-jsslkeylog
	@make --no-print-directory build-docker-kafkacat
	@make --no-print-directory build-docker-wireshark


certs: 	                          ## create certificates for testing
	@$(call echo_stdout_header, Create CA, Sever and clien certificates for testing)
	$(CURRENT_DIR)/certs/./create-certs.sh
	@$(call echo_stdout_footer, Finished creating certificates)


delete-work-files:           ## delete working files (sslkeylog and pcap files)
	@$(call echo_stdout_header, Delete working files)
	find $(CURRENT_DIR)/work/ssl-key-log -type f ! -name '.gitkeep' -delete
	find $(CURRENT_DIR)/work/tcpdump-trace -type f ! -name '.gitkeep' -delete
	@$(call echo_stdout_footer, Finished deleting working files)


clean:                       ## clean build artifacts
	rm -rf $(CURRENT_DIR)/${BUILD_DIR}

