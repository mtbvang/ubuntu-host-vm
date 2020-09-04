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

.PHONY: all build-* build-cs clean assure deliver assure_atlas assure_atlas_vmware assure_atlas_virtualbox assure_atlas_parallels

help:
	@grep -E '^[%0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

all: build assure deliver

build: $(BOX_FILES)

build-%: ## build-(ubuntu1804-desktop|ubuntu1804|ubuntu1604-desktop|ubuntu1604|ubuntu1404-desktop|ubuntu1404) Build the specified box
	packer build -only=vmware-iso -var-file=$*.json ubuntu.json

build-cs: ## Build the credit stretcher ubuntu host VMWare VM
	version=$(VAGRANT_BOX_VERSION) packer build ubuntu-cs.json

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
VAGRANT_BOX_VERSION = 0.1.0
VAGRANT_VM_MEMORY := $(or $(VAGRANT_VM_MEMORY),12288)
VAGRANT_VM_CPUS := $(or $(VAGRANT_VM_CPUS),4)
VAGRANT_ANSIBLE_GALAXY_FORCE ?= ""
vagrantEnvVars = VM_MEMORY=$(VAGRANT_VM_MEMORY) VM_CPUS=$(VAGRANT_VM_CPUS) ANSIBLE_GALAXY_FORCE=$(VAGRANT_ANSIBLE_GALAXY_FORCE)

vagrant-box-add: ## Add the built vagrant box so that it can be used by the Vagrantfile
	vagrant box add --name "cs/ubuntu18.04-desktop" box/vmware/cs-ubuntu1804-desktop-$(VAGRANT_BOX_VERSION).box

vagant-up: ## vagrant up VM with $VAGRANT_VM_MEMORY GB ram (default=12) and $VAGRANT_VM_CPUS (default=4) cpus.
	$(vagrantEnvVars) vagrant up

vagrant-reload: ## vagrant reload VM with $VAGRANT_VM_MEMORY GB ram (default=12) and $VAGRANT_VM_CPUS (default=4) cpus.
	$(vagrantEnvVars) vagrant reload

vagrant-recreate: ## vagrant destroy and up a VM with $VAGRANT_VM_MEMORY GB ram (default=12) and $VAGRANT_VM_CPUS (default=4) cpus.
	vagrant destroy host -f; \
	$(vagrantEnvVars) vagrant up

vagrant-provision: ## vagrant provision VM
	$(vagrantEnvVars) vagrant provision

vagrant-test: ## Run tests.yml playbook to test playbook.yml playbook on host VM
	$(vagrantEnvVars) vagrant provision --provision-with=tests

vagrant-ssh: ## vagrant ssh to VM.
	vagrant ssh

vagrant-halt: ## vagrant halt, stops the vagrant machine
	vagrant halt

ansible-provision: ## Runs ansible provisioner from guest for host and host2 VM
	@read -r -p "Ansible tags to run (command separated list or 'all' to run everything): " TAGS; \
	cd /vagrant && PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=true ANSIBLE_ROLES_PATH='/vagrant/host/provision/roles' ansible-playbook --limit="host,host2" --inventory-file=/tmp/vagrant-ansible/inventory --become -v --tags=$$TAGS /vagrant/host/provision/playbook.yml

ansible-tests: ## runs ansible tests.yml playbook from guest
	cd /vagrant && PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=true ansible-playbook --limit="host,host2" --inventory-file=/tmp/vagrant-ansible/inventory --become -vv --tags=all /vagrant/host/provision/tests.yml


