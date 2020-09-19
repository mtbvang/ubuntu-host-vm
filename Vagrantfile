# -*- mode: ruby -*-
# vi: set ft=ruby :

PROJECT_NAME = ENV['PROJECT_NAME'] || File.basename(File.expand_path(File.dirname(__FILE__)))

###
# Variables that can be overriden on vagrant up.
# example:
#   ANSIBLE_TAGS=java vagrant provision --provision-with ansible
# Only run the ansible java tag in playbook.yml and the vagrant ansible provisioner.
###
VB_GUEST = ENV['VB_GUEST'] == 'true' ? true : false                                           # True runs the vagrant vb-guest plugin to update virtubalbox guest additions. Guest additions version needs to be older than the version of virtualbox.
ANSIBLE_VERBOSITY = ENV['ANSIBLE_VERBOSITY'] || 'v'                                           # Set to vv to get debugging
ANSIBLE_TESTS_VERBOSITY = ENV['ANSIBLE_TESTS_VERBOSITY'] || 'vv'                              # Higher level of verbosity for tests.yml playbook.
ANSIBLE_GALAXY_FORCE = ENV['ANSIBLE_GALAXY_FORCE'] || "--force"                               # Set to "" to not force ansible galaxy run
ANSIBLE_TAGS = ENV['ANSIBLE_TAGS'] || "all"                                                   # Set to specific ansible tags to run a subset of tasks and roles.
USERNAME = ENV['USERNAME']                                                                    # Windows username passed as a variable into ansible.
VM_CPUS = ENV['VM_CPUS'] || 1                                                                 # Number of CPUs for the guest VM.
VM_CPU_CAP = ENV['VM_CPU_CAP'] || 100                                                         # CPU usage cap on the guest OS.
VM_MEMORY = ENV['VM_MEMORY'] || 1024                                                          # RAM on the guest VM.
VM_GUI = ENV['VM_GUI'] == 'false' ? false : true                                              # Whether or not to show the VM GUI.
VM_DISKSIZE = ENV['VM_DISKSIZE'] || '100GB'                                                   # Size of the root mount.
VM_IP = ENV['VM_IP'] || '192.168.153.2'                                                       # IP of the guest VM
VM_TIMEZONE = ENV['VM_TIMEZONE'] || 'Europe/Copenhagen'                                       # Timezone of guest VM
GITHUB_OAUTH_TOKEN = ENV['GITHUB_OAUTH_TOKEN'] || '853aa89f6459923fad9728f2b95320e2a042273f'  # Developer shared token from cs-machine account to access gruntwork code.
BOX_VERSION = ENV['VAGRANT_BOX_VERSION'] || ">= 0"
###
# Install plugin dependencies if they don't exist.
###
plugins_dependencies = [['vagrant-reload', '0.0.1'], ['vagrant-vbguest', '0.16.0'],
                        ['vagrant-disksize', '0.1.3']]
plugin_status = false
plugins_dependencies.each do |plugin|
  unless Vagrant.has_plugin? plugin[0]
    system("vagrant plugin install #{plugin[0]} --plugin-version #{plugin[1]}")
    plugin_status = true
    puts " #{plugin[0]} v#{plugin[1]}  Dependencies installed"
  end
end

## Restart Vagrant if any new plugin installed
if plugin_status === true
  exec "vagrant #{ARGV.join' '}"
else
  puts "All Plugin Dependencies already installed"
end

###
# The main section of the file. We do the following:
# - Configure the vagrant plugins that were installed above.
# - Copy config files from the host to the guest.
# - Provision the guest VM using the ansible local provisioner.
# - Reload the VM so bash related changes get set for testing.
# - Run the ansible/test.yml playbook for basic verification.
###
Vagrant.configure("2") do |config|

  config.vm.box = "creditstretcher/ubuntu18.04-desktop"
  config.vm.box_version = BOX_VERSION

  ## Configure vagrant plugins
  if Vagrant.has_plugin?("vagrant-disksize")
    config.disksize.size = VM_DISKSIZE
  end

  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = VB_GUEST
  end

  ## Copy config files from the host to the guest.
  ### The parent directory is mounted to the default /vagrant location to give access to the code base from the host.
  if !Vagrant::Util::Platform.windows? then
    config.vm.synced_folder './', '/vagrant', disabled: false
  else
    config.vm.synced_folder './', '/vagrant', disabled: false, type: 'smb'
  end

  # Copy .ssh files from host to VM
  config.vm.synced_folder "~/.ssh", "/home/vagrant/.ssh", type: "rsync",
    rsync__exclude: %w(authorized_keys config)

  # Copy OpenVPN certificate files from host to VM
  config.vm.synced_folder "~/OpenVPN", "/home/vagrant/OpenVPN", type: "rsync"

  # Copy AWS credentias from host to VM
  config.vm.synced_folder "~/.aws", "/home/vagrant/.aws", type: "rsync"

  # Copy .gitconfig from host to VM
  config.vm.provision "file", source: "~/.gitconfig", destination: "/home/vagrant/.gitconfig"
  config.vm.provision "shell",
                      inline: "chmod 0600 /home/vagrant/.ssh/*"

  # VM bootstrap steps. (Once this gets too big move to separate bootstrap file)
  if Vagrant::Util::Platform::darwin?
    config.vm.provision "shell",
                        inline: "sudo apt-get install -y python-pip"
  end
  config.vm.provision :shell,
                      :inline => "sudo rm /etc/localtime && sudo ln -s /usr/share/zoneinfo/#{VM_TIMEZONE} /etc/localtime", run: "always"

  config.vm.provision "shell",
                      inline: "sudo chmod -R 0777 /home/vagrant/.ansible"

  ## Provision the guest VM using the public/packer ansible playbook with the local provisioner.
  config.vm.provision "ansible", type: :ansible_local do |ansible|
    ansible.verbose = ANSIBLE_VERBOSITY
    ansible.install = false
    ansible.playbook = "/vagrant/provision/playbook.yml"
    ansible.galaxy_role_file = "/vagrant/provision/requirements.yml"
    ansible.galaxy_roles_path = "/vagrant/provision/roles"
    ansible.galaxy_command = "ansible-galaxy install --ignore-certs --role-file=%{role_file} --roles-path=%{roles_path} #{ANSIBLE_GALAXY_FORCE}"
    ansible.become = true
    ansible.tags = ANSIBLE_TAGS
    ansible.extra_vars = {
        github_oauth_token: GITHUB_OAUTH_TOKEN
    }
  end

  ## Provision the guest VM using the private ansible playbook with the local provisioner.
  config.vm.provision "ansible-private", type: :ansible_local do |ansible|
    ansible.verbose = ANSIBLE_VERBOSITY
    ansible.install = false
    ansible.playbook = "/vagrant/provision/playbook-private.yml"
    ansible.galaxy_role_file = "/vagrant/provision/requirements.yml"
    ansible.galaxy_roles_path = "/vagrant/provision/roles"
    ansible.galaxy_command = "ansible-galaxy install --ignore-certs --role-file=%{role_file} --roles-path=%{roles_path} #{ANSIBLE_GALAXY_FORCE}"
    ansible.become = true
    ansible.tags = ANSIBLE_TAGS
    ansible.extra_vars = {
        github_oauth_token: GITHUB_OAUTH_TOKEN
    }
  end

  ## Reload the VM so bash related changes get set for testing.
  config.vm.provision :reload

  ## Run the tests.yml playbook that tests things common to both packer and vagrant provisioning.
  config.vm.provision "tests", type: :ansible_local do |ansible|
    ansible.verbose = ANSIBLE_TESTS_VERBOSITY
    ansible.playbook = "/vagrant/provision/tests.yml"
    ansible.become = true
    ansible.tags = ANSIBLE_TAGS
    ansible.extra_vars = {
        github_oauth_token: GITHUB_OAUTH_TOKEN
    }
  end

  # Run the tests-vagrant.yml playbook to test vagrant/private provisioning steps
  config.vm.provision "tests-vagrant", type: :ansible_local do |ansible|
    ansible.verbose = ANSIBLE_TESTS_VERBOSITY
    ansible.playbook = "/vagrant/provision/tests-vagrant.yml"
    ansible.become = true
    ansible.tags = ANSIBLE_TAGS
    ansible.extra_vars = {
        github_oauth_token: GITHUB_OAUTH_TOKEN
    }
  end

  ## Multi machine configuration for first VM localdev.
  config.vm.define "host", primary: true do |ld|
    ## Set vmware provider configurations
    ld.vm.provider :vmware_workstation do |vm|
      vm.gui = VM_GUI
      vm.vmx["ethernet0.pcislotnumber"] = "32"
      vm.vmx["memsize"] = VM_MEMORY
      vm.vmx["numvcpus"] = VM_CPUS
    end
  end

end
