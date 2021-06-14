SHELL = /bin/bash

BOX_VERSION ?= $(shell cat VERSION)
BOX_SUFFIX := -$(BOX_VERSION).box
BUILDER_TYPES ?= vmware virtualbox parallels
TEMPLATE_FILENAMES := $(filter-out ubuntu.json,$(wildcard *.json))
BOX_NAMES := $(basename $(TEMPLATE_FILENAMES))
BOX_FILENAMES := $(TEMPLATE_FILENAMES:.json=$(BOX_SUFFIX))
VMWARE_BOX_DIR ?= box/vmware
VMWARE_TEMPLATE_FILENAMES = $(TEMPLATE_FILENAMES)
VMWARE_BOX_FILENAMES := $(VMWARE_TEMPLATE_FILENAMES:.json=$(BOX_SUFFIX))
VMWARE_BOX_FILES := $(foreach box_filename, $(VMWARE_BOX_FILENAMES), $(VMWARE_BOX_DIR)/$(box_filename))
VIRTUALBOX_BOX_DIR ?= box/virtualbox
VIRTUALBOX_TEMPLATE_FILENAMES = $(TEMPLATE_FILENAMES)
VIRTUALBOX_BOX_FILENAMES := $(VIRTUALBOX_TEMPLATE_FILENAMES:.json=$(BOX_SUFFIX))
VIRTUALBOX_BOX_FILES := $(foreach box_filename, $(VIRTUALBOX_BOX_FILENAMES), $(VIRTUALBOX_BOX_DIR)/$(box_filename))
PARALLELS_BOX_DIR ?= box/parallels
PARALLELS_TEMPLATE_FILENAMES = $(TEMPLATE_FILENAMES)
PARALLELS_BOX_FILENAMES := $(PARALLELS_TEMPLATE_FILENAMES:.json=$(BOX_SUFFIX))
PARALLELS_BOX_FILES := $(foreach box_filename, $(PARALLELS_BOX_FILENAMES), $(PARALLELS_BOX_DIR)/$(box_filename))
BOX_FILES := $(VMWARE_BOX_FILES) $(VIRTUALBOX_BOX_FILES) $(PARALLELS_BOX_FILES)

box/vmware/%$(BOX_SUFFIX) box/virtualbox/%$(BOX_SUFFIX) box/parallels/%$(BOX_SUFFIX): %.json
	bin/box build $<

# Ubuntu dev host version numbers
VERSION_UBUNTU_HOST ?= 0.5.1
VERSION_LONG_UBUNTU_HOST ?= v${VERSION_UBUNTU_HOST}

.PHONY: all ansible-* build-* build-cs clean assure dconf-load deliver assure_atlas assure_atlas_vmware assure_atlas_virtualbox assure_atlas_parallels vagrant-*


help:
	@grep -E '^[%0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

all: build assure deliver

build: $(BOX_FILES)

build-%: ## build-(ubuntu1804-desktop|ubuntu1804|ubuntu1604-desktop|ubuntu1604|ubuntu1404-desktop|ubuntu1404) Build the specified box
	@sudo vmware-modconfig --console --install-all; \
	packer build -only=vmware-iso -var 'version=$(VAGRANT_BOX_VERSION)' -var-file=$*.json ubuntu.json

build-cs: build-ubuntu1804-desktop ## WARNING: THIS BUILDS A PUBLIC VAGRANT BOX PUBLISHED TO VAGRANT CLOUD. Build the credit stretcher ubuntu host VMWare VM
	@if [[ -z "${BUILD_CONFIRMATION}" ]]; then \
		read -r -p "WARNING: THIS BUILDS A PUBLIC VAGRANT BOX PUBLISHED TO VAGRANT CLOUD. Make sure it contains no sensitive information. Do you want to continue (yes|no): " BUILD_CONFIRMATION; \
	fi; \
	if [[ "$$BUILD_CONFIRMATION" = "yes" ]]; then \
	  	sudo vmware-modconfig --console --install-all; \
		packer build -var 'version=$(VAGRANT_BOX_VERSION)' -var 'github_oauth_token=853aa89f6459923fad9728f2b95320e2a042273f' -on-error=ask ubuntu-cs.json; \
	fi;

assure: assure_vmware assure_virtualbox assure_parallels

assure_vmware: $(VMWARE_BOX_FILES)
	@for vmware_box_file in $(VMWARE_BOX_FILES) ; do \
		echo Checking $$vmware_box_file ; \
		bin/box test $$vmware_box_file vmware ; \
	done

assure_virtualbox: $(VIRTUALBOX_BOX_FILES)
	@for virtualbox_box_file in $(VIRTUALBOX_BOX_FILES) ; do \
		echo Checking $$virtualbox_box_file ; \
		bin/box test $$virtualbox_box_file virtualbox ; \
	done

assure_parallels: $(PARALLELS_BOX_FILES)
	@for parallels_box_file in $(PARALLELS_BOX_FILES) ; do \
		echo Checking $$parallels_box_file ; \
		bin/box test $$parallels_box_file parallels ; \
	done

assure_atlas: assure_atlas_vmware assure_atlas_virtualbox assure_atlas_parallels

assure_atlas_vmware:
	@for box_name in $(BOX_NAMES) ; do \
		echo Checking $$box_name ; \
		bin/test-vagrantcloud-box box-cutter/$$box_name vmware ; \
		bin/test-vagrantcloud-box boxcutter/$$box_name vmware ; \
	done

assure_atlas_virtualbox:
	@for box_name in $(BOX_NAMES) ; do \
		echo Checking $$box_name ; \
		bin/test-vagrantcloud-box box-cutter/$$box_name virtualbox ; \
		bin/test-vagrantcloud-box boxcutter/$$box_name virtualbox ; \
	done

assure_atlas_parallels:
	@for box_name in $(BOX_NAMES) ; do \
		echo Checking $$box_name ; \
		bin/test-vagrantcloud-box box-cutter/$$box_name parallels ; \
		bin/test-vagrantcloud-box boxcutter/$$box_name parallels ; \
	done

deliver:
	@for box_name in $(BOX_NAMES) ; do \
		echo Uploading $$box_name to Atlas ; \
		bin/register_atlas.sh $$box_name $(BOX_SUFFIX) $(BOX_VERSION) ; \
	done

clean:
	@for builder in $(BUILDER_TYPES) ; do \
		echo Deleting output-*-$$builder-iso ; \
		echo rm -rf output-*-$$builder-iso ; \
	done
	@for builder in $(BUILDER_TYPES) ; do \
		if test -d box/$$builder ; then \
			echo Deleting box/$$builder/*.box ; \
			find box/$$builder -maxdepth 1 -type f -name "*.box" ! -name .gitignore -exec rm '{}' \; ; \
		fi ; \
	done


# Set variables to default values if they aren't already set. To overwrite these pass them in when calling make e.g. 'VM_CPU=1 make up' or set an enviroment variable.
VAGRANT_BOX_VERSION = ${VERSION_UBUNTU_HOST}
VAGRANT_VM_MEMORY := $(or $(VAGRANT_VM_MEMORY),12288)
VAGRANT_VM_CPUS := $(or $(VAGRANT_VM_CPUS),4)
VAGRANT_ANSIBLE_GALAXY_FORCE ?= "--force"
vagrantEnvVars = VAGRANT_BOX_VERSION=$(VAGRANT_BOX_VERSION) VM_MEMORY=$(VAGRANT_VM_MEMORY) VM_CPUS=$(VAGRANT_VM_CPUS) ANSIBLE_GALAXY_FORCE=$(VAGRANT_ANSIBLE_GALAXY_FORCE)
vagrantEnvVarsTesting = VAGRANT_BOX_VERSION=$(VAGRANT_BOX_VERSION) VM_MEMORY=2048 VM_CPUS=1 ANSIBLE_GALAXY_FORCE=$(VAGRANT_ANSIBLE_GALAXY_FORCE)

vagrant-box-add: ## Add the built vagrant box locally so that it can be used by the Vagrantfile
	@vagrant box remove creditstretcher/ubuntu18.04-desktop; \
	vagrant box add --name creditstretcher/ubuntu18.04-desktop box/vmware/cs-ubuntu1804-desktop-$(VAGRANT_BOX_VERSION).box

vagrant-cloud-publish:  ## Publish the packer built vagrant box to vagrant cloud. Vagrant cloud credentials are: development@creditstretcher.com, Z2LrZhte#duU7g#
	@if [[ -z "${PUBLISH_CONFIRMATION}" ]]; then \
		read -r -p "WARNING: THIS PUBLISHES THE VAGRANT VAGRANT CLOUD WITH PUBLIC ACCESS. Make sure the box contains no sensitive information. Do you want to continue (yes|no): " PUBLISH_CONFIRMATION; \
	fi; \
	if [[ "$$PUBLISH_CONFIRMATION" = "yes" ]]; then \
		vagrant cloud publish creditstretcher/ubuntu18.04-desktop $(VAGRANT_BOX_VERSION) vmware_desktop box/vmware/cs-ubuntu1804-desktop-$(VAGRANT_BOX_VERSION).box -d "A VMWare Ubuntu desktop host VM with development tools installed." --version-description "version $(VAGRANT_BOX_VERSION)" --release --short-description "Download me!"; \
	fi;

vagrant-up-testing: ## vagrant up VM with $VAGRANT_VM_MEMORY GB ram (default=2) and $VAGRANT_VM_CPUS (default=1) cpus for testing purposes.
	$(vagrantEnvVarsTesting) vagrant up --debug

vagrant-up: ## vagrant up VM with $VAGRANT_VM_MEMORY GB ram (default=12) and $VAGRANT_VM_CPUS (default=4) cpus.
	$(MAKE) make-empty-directories; $(vagrantEnvVars) vagrant up

vagrant-reload: ## vagrant reload VM with $VAGRANT_VM_MEMORY GB ram (default=12) and $VAGRANT_VM_CPUS (default=4) cpus.
	$(vagrantEnvVars) vagrant reload

vagrant-destroy: ## vagrant destroy VM.
	$(vagrantEnvVars) vagrant destroy -f

vagrant-recreate: ## vagrant destroy and up a VM with $VAGRANT_VM_MEMORY GB ram (default=12) and $VAGRANT_VM_CPUS (default=4) cpus.
	vagrant destroy host -f; \
	$(vagrantEnvVars) vagrant up

vagrant-provision: ## vagrant provision VM
	$(vagrantEnvVars) vagrant provision

vagrant-provision-private: ## vagrant provision VM with private playbook and test.
	$(vagrantEnvVars) vagrant provision --provision-with=ansible-private,tests

vagrant-test: ## Run tests.yml playbook to test playbook.yml playbook on host VM
	$(vagrantEnvVars) vagrant provision --provision-with=tests

vagrant-ssh: ## vagrant ssh to VM.
	vagrant ssh

vagrant-halt: ## vagrant halt, stops the vagrant machine
	vagrant halt

ansible-provision: ## Runs ansible playbook used by packer that provisions generic VM.
	@if [[ -z "${TAGS}" ]]; then \
		read -r -p "Ansible tags to run (command separated list or 'all' to run everything): " TAGS; \
	fi; \
	ansible-galaxy install -p provision/roles -r provision/requirements.yml; \
	PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=true ansible-playbook provision/playbook.yml --tags=$$TAGS --extra-vars "user=${USER}" --extra-vars "github_oauth_token=${GITHUB_OAUTH_TOKEN}"

ansible-provision-private: ## Runs ansible playbook used by vagrant to configure user specific details in generic VM.
	@read -r -p "Ansible tags to run (command separated list or 'all' to run everything): " TAGS; \
	ansible-galaxy collection install -r provision/requirements.yml; \
	ansible-galaxy install -p provision/roles -r provision/requirements.yml; \
	PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=true ansible-playbook provision/playbook-private.yml --tags=$$TAGS --extra-vars "user=${USER}" --extra-vars "github_oauth_token=${GITHUB_OAUTH_TOKEN}"

ansible-provision-packer: ## Runs ansible playbook used by packer.
	@read -r -p "Ansible tags to run (command separated list or 'all' to run everything): " TAGS; \
	ansible-galaxy install -p provision/roles -r provision/requirements.yml; \
	PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=true ansible-playbook provision/playbook-packer.yml --tags=$$TAGS --extra-vars "user=${USER}" --extra-vars "github_oauth_token=${GITHUB_OAUTH_TOKEN}" -vv

ansible-tests: ## runs ansible tests.yml playbook from guest
	@ansible-galaxy install -p provision/roles -r provision/requirements.yml; \
	PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=true ansible-playbook -vv --tags=all provision/tests.yml && \
	PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=true ansible-playbook -vv --tags=all provision/tests-vagrant.yml;

clean-bak-files: ## Remove all .bak files create by sed -i.bak option
	@rm -f .*.bak || true; \
	rm -f *.bak || true;

update-version-ubuntu-host-vm: ## Update the version number for the specified subtree repo.
	@if [[ -z "${NEWVERSION}" ]]; then \
		read -r -p "The current ubuntu-host-vm version is ${VERSION_UBUNTU_HOST} enter the new version: " NEWVERSION; \
	fi; \
	if [[ ! -z "$$NEWVERSION" ]]; then \
		sed -i.bak "s/^VERSION_UBUNTU_HOST ?= ${VERSION_UBUNTU_HOST}/VERSION_UBUNTU_HOST ?= $$NEWVERSION/g" Makefile; \
		echo "Updated ubuntu-host-vm version to $$NEWVERSION"; \
	fi; \
	$(MAKE) clean-bak-files

dconf-load: ## Load ubuntu settings from provision/files/saved_settings.dconf file
	@dconf load / < provision/files/saved_settings.dconf

make-empty-directories: ## Make empty directories that are required by Vagrantfile if they don't exist
	@mkdir -p ~/.ssh ~/.aws ~/OpenVPN
