# -*- mode: ruby -*-
# vi: set ft=ruby :

PROJECT_NAME = ENV['PROJECT_NAME'] || File.basename(File.expand_path(File.dirname(__FILE__)))

###
# Variables that can be overriden on vagrant up.
# example:
#   ANSIBLE_TAGS=java vagrant provision --provision-with ansible
# Only run the ansible java tag in playbook.yml and the vagrant ansible provisioner.
###
VB_GUEST = ENV['VB_GUEST'] == 'true' ? true : false                                       # True runs the vagrant vb-guest plugin to update virtubalbox guest additions. Guest additions version needs to be older than the version of virtualbox.
ANSIBLE_VERSION = ENV['ANSIBLE_VERSION'] || '2.8.1'                                       # Version of ansible install on the guest
ANSIBLE_VERBOSITY = ENV['ANSIBLE_VERBOSITY'] || 'v'                                       # Set to vv to get debugging
ANSIBLE_TESTS_VERBOSITY = ENV['ANSIBLE_TESTS_VERBOSITY'] || 'vv'                          # Higher level of verbosity for tests.yml playbook.
ANSIBLE_GALAXY_FORCE = ENV['ANSIBLE_GALAXY_FORCE'] || "--force"                           # Set to "" to not force ansible galaxy run
ANSIBLE_TAGS = ENV['ANSIBLE_TAGS'] || "all"                                               # Set to specific ansible tags to run a subset of tasks and roles.
USERNAME = ENV['USERNAME']                                                                # Windows username passed as a variable into ansible.
VM_CPUS = ENV['VM_CPUS'] || 1                                                             # Number of CPUs for the guest VM.
VM_CPU_CAP = ENV['VM_CPU_CAP'] || 100                                                     # CPU usage cap on the guest OS.
VM_MEMORY = ENV['VM_MEMORY'] || 1024                                                      # RAM on the guest VM.
VM_GUI = ENV['VM_GUI'] == 'false' ? false : true                                          # Whether or not to show the VM GUI.
VM_DISKSIZE = ENV['VM_DISKSIZE'] || '100GB'                                                # Size of the root mount.
VM_IP = ENV['VM_IP'] || '192.168.153.2'                                                   # IP of the guest VM
VM2_CPUS = ENV['VM2_CPUSrsync__exclude'] || 1                                             # Number of CPUs for the guest VM.
VM2_CPU_CAP = ENV['VM_CPU_CAP'] || 100                                                    # CPU usage cap on the guest OS.
VM2_MEMORY = ENV['VM_MEMORY'] || 1024                                                     # RAM on the guest VM.
VM2_GUI = ENV['VM_GUI'] == 'false' ? false : true                                         # Whether or not to show the VM GUI.
VM2_DISKSIZE = ENV['VM_DISKSIZE'] || '20GB'                                               # Size of the root mount.
VM2_IP = ENV['VM_IP'] || '192.168.154.3'                                                  # IP of the guest VM
HOST_BACKEND_PORTFORWARD_PORT = ENV['HOST_BACKEND_PORTFORWARD_PORT'] || 23001             # Port to forward to guest 3000
HOST_DB_PORTFORWARD_PORT = ENV['HOST_DB_PORTFORWARD_PORT'] || 25433                       # Port to forward to guest 5432
HOST_UI_PORTFORWARD_PORT = ENV['HOST_UI_PORTFORWARD_PORT'] || 24201                       # Port to forward to guest 4200
GUEST_BACKEND_PORTFORWARD_PORT = ENV['GUEST_BACKEND_PORTFORWARD_PORT'] || 23000           # Port to forward to guest 3000
GUEST_DB_PORTFORWARD_PORT = ENV['GUEST_DB_PORTFORWARD_PORT'] || 25432                     # Port to forward to guest 5432
GUEST_UI_PORTFORWARD_PORT = ENV['GUEST_UI_PORTFORWARD_PORT'] || 24200                     # Port to forward to guest 4200
VM_TIMEZONE = ENV['VM_TIMEZONE'] || 'Europe/Copenhagen'                                   # Timezone of guest VM

###
# Install plugin dependencies if they don't exist.
###
plugins_dependencies = [['vagrant-reload', '0.0.1'], ['vagrant-vbguest', '0.16.0'], ['vagrant-cachier', '1.2.1'],
                        ['vagrant-disksize', '0.1.3'], ['vagrant-notify-forwarder', '0.5.0']]
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
# - Do port forwarding to be able to access services running in the guest from the host.
# - Copy config files from the host to the guest.
# - Provision the guest VM using the ansible local provisioner.
# - Reload the VM so bash related changes get set for testing.
# - Run the ansible/test.yml playbook for basic verification.
###
Vagrant.configure("2") do |config|

  # config.vm.box = "boxcutter/ubuntu1804-desktop-0.1.0"
  config.vm.box = "fasmat/ubuntu1804-desktop"
  
  ## Configure vagrant plugins
  if Vagrant.has_plugin?("vagrant-disksize")
    config.disksize.size = VM_DISKSIZE
  end

  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = VB_GUEST
  end

  # Cachier plugin is broken on mac at version 1.2.1. So don't use it.
  if Vagrant.has_plugin?("vagrant-cachier") && !Vagrant::Util::Platform::darwin?
    config.cache.scope = :box
    config.cache.synced_folder_opts = {
      owner: "_apt",
    }
  end

  ## Copy config files from the host to the guest.
  ### The parent directory is mounted to the default /vagrant location to give access to the code base from the host.
  if !Vagrant::Util::Platform.windows? then
    config.vm.synced_folder '../', '/vagrant', disabled: false, type: 'nfs', mount_options: ['actimeo=1']
  else
    config.vm.synced_folder '../', '/vagrant', disabled: false, type: 'smb'
  end
  config.vm.synced_folder "~/.ssh", "/home/vagrant/.ssh", type: "rsync",
    rsync__exclude: %w(authorized_keys config)
  config.vm.provision "file", source: "~/.gitconfig", destination: "/home/vagrant/.gitconfig"
  config.vm.provision "shell",
                      inline: "chmod 0600 /home/vagrant/.ssh/*"
  if Vagrant::Util::Platform::darwin?
    config.vm.provision "shell",
                        inline: "sudo apt-get install -y python-pip"
  end
  config.vm.provision :shell,
    :inline => "sudo rm /etc/localtime && sudo ln -s /usr/share/zoneinfo/#{VM_TIMEZONE} /etc/localtime", run: "always"

  ## Provision the guest VM using the ansible local provisioner.
  config.vm.provision "ansible", type: :ansible_local do |ansible|
    ansible.verbose = ANSIBLE_VERBOSITY
    ansible.install_mode = "pip"
    ansible.version = ANSIBLE_VERSION
    ansible.playbook = "/vagrant/#{PROJECT_NAME}/provision/playbook.yml"
    ansible.galaxy_role_file = "/vagrant/#{PROJECT_NAME}/provision/requirements.yml"
    ansible.galaxy_roles_path = "/vagrant/#{PROJECT_NAME}/provision/roles"
    ansible.galaxy_command = "ansible-galaxy install --ignore-certs --role-file=%{role_file} --roles-path=%{roles_path} #{ANSIBLE_GALAXY_FORCE}"
    ansible.become = true
    ansible.tags = ANSIBLE_TAGS
  end

  ## Reload the VM so bash related changes get set for testing.
  config.vm.provision :reload

  ## Run the ansible/test.yml playbook for basic verification. FIXME This is sufficient and flexible enough. It could
  # be replaced by a test framework like GOSS or the tasks in playbook.yml could be refactored out to a proper ansible
  # role and the molecule testing framework used.
  config.vm.provision "tests", type: :ansible_local do |ansible|
    ansible.verbose = ANSIBLE_TESTS_VERBOSITY
    ansible.playbook = "/vagrant/#{PROJECT_NAME}/provision/tests.yml"
    ansible.become = true
    ansible.tags = ANSIBLE_TAGS
  end

  ## Multi machine configuration for first VM localdev.
  config.vm.define "host", primary: true do |ld|
    #ld.vm.network "private_network", ip: VM_IP

    ## Port forwarding
    # http for testing apps running locally on Guest VM.
    ld.vm.network "forwarded_port", auto_correct: true, guest: GUEST_BACKEND_PORTFORWARD_PORT.to_i, host: HOST_BACKEND_PORTFORWARD_PORT.to_i
    ld.vm.network "forwarded_port", auto_correct: true, guest: GUEST_DB_PORTFORWARD_PORT.to_i, host: HOST_DB_PORTFORWARD_PORT.to_i
    ld.vm.network "forwarded_port", auto_correct: true, guest: GUEST_UI_PORTFORWARD_PORT.to_i, host: HOST_UI_PORTFORWARD_PORT.to_i

    ## Set vmware provider configurations
    ld.vm.provider :vmware_workstation do |vm|
      vm.gui = VM_GUI
      # vm.vmx["ethernet0.pcislotnumber"] = "33"
      vm.vmx["memsize"] = VM_MEMORY
      vm.vmx["numvcpus"] = VM_CPUS
    end
  end

end