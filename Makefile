.PHONY: help up reload recreate provision ssh ansible-provision ansible-tests halt

# Set variables to default values if they aren't already set. To overwrite these pass them in when calling make e.g. 'VM_CPU=1 make up' or set an enviroment variable.
VM_MEMORY := $(or $(VM_MEMORY),16384)
VM_CPUS := $(or $(VM_CPUS),6)
vagrantEnvVars = VM_MEMORY=$(VM_MEMORY) VM_CPUS=$(VM_CPUS)

help:
	@grep -E '^[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

up: ## vagrant up VM with $VM_MEMORY GB ram (default=32) and $VM_CPUS (default=8) cpus.
	$(vagrantEnvVars) vagrant up

reload: ## vagrant reload VM with $VM_MEMORY GB ram (default=32768) and $VM_CPUS (default=8) cpus.
	$(vagrantEnvVars) vagrant reload

recreate: ## vagrant destroy and up a VM with $VM_MEMORY GB ram (default=8) and $VM_CPUS (default=2) cpus.
	vagrant destroy host -f; \
	$(vagrantEnvVars) vagrant up

provision: ## vagrant provision VM
	$(vagrantEnvVars) vagrant provision

test: ## Run tests.yml playbook to test playbook.yml playbook on host VM
	$(vagrantEnvVars) vagrant provision --provision-with=tests

ssh: ## vagrant ssh to VM.
	vagrant ssh

ansible-provision: ## Runs ansible provisioner from guest for host and host2 VM
	@read -r -p "Ansible tags to run (command separated list or 'all' to run everything): " TAGS; \
	cd /vagrant && PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=true ANSIBLE_ROLES_PATH='/vagrant/host/provision/roles' ansible-playbook --limit="host,host2" --inventory-file=/tmp/vagrant-ansible/inventory --become -v --tags=$$TAGS /vagrant/host/provision/playbook.yml

ansible-tests: ## runs ansible tests.yml playbook from guest
	cd /vagrant && PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=true ansible-playbook --limit="host,host2" --inventory-file=/tmp/vagrant-ansible/inventory --become -vv --tags=all /vagrant/host/provision/tests.yml

halt: ## vagrant halt, stops the vagrant machine
	vagrant halt

box-create: ## create a vagrant box from the existing vm
	packer build ubuntu.json