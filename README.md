# Packer templates for Ubuntu

### Overview

This repository contains 
1. [Packer](https://packer.io/) templates for creating Ubuntu Vagrant boxes and the .
1. The Vagrantfile and Ansible provisioning scripts to provision and configure the Fellow Pay development Virtual Machine.

It is a private copy of the https://github.com/boxcutter/ubuntu repo. We use this to build the vagrant box published to
vagrant cloud.

We then use Vagrant and VMWare to spin up a ubuntu virtual machine that contains all the development tools and requirements.

WARNING: THE CONTENT OF THIS PROJECT BUILD A PUBLIC VAGRANT BOX PUBLISHED TO VAGRANT CLOUD. Make sure there is no sensitive 
information in the provision/playbook.yml and files used in the provisioning steps.

## Vagrant up requirements

To run the `make vagrant-up` command the following is required on your host machine.

1. ~/OpenVPN folder containing the OpenVPN certificates. These are issued by a developer with devops access.
1. ~/.ssh folder containing the SSH key added to your AWS IAM user to give you access to the AWS environments.
1. GITHUB_OAUTH_TOKEN environment variable containing a token generated in your github account with access to the gruntwork repos.   


## Updating and Testing the Ansible provisioning scripts

It is intended the development VM is ephemeral and any persistent changes are to be written as Infrastructure as Code in
the Ansible playbooks found in the provision directory used by the Vagrantfile.

The process for updating and testing the Ansible scripts are:

1. Update Ansible playbooks in the git subtree ubuntu-host-vm repo in the cs-fullstack repo.
1. Test the changes by running `make ansible-provision` target from the makefile in this directory during development 
inside the VM. The ansible scripts need to be idempotent and this is the way that developers will get your changes into 
their VM.
1. If you have enough RAM on your host test the creation of a new VM:
    1. From your cs-fullstack feature branch `make git-subtree-push-ubuntu-host-vm`.
    1. On your windows host `git clone git@github.com:creditstretcher/ubuntu-host-vm.git ubuntu-host-vm-testing` into your code directory.
    1. `cd ubuntu-host-vm-testng`
    1. `git checkout <YOUR BRANCH NAME>`
    1. `VAGRANT_VM_MEMORY=2024 VAGRANT_VM_CPUS=1 VERSI ON_UBUNTU_HOST=0.1.0 make vagrant-up`. Note, replace VERSION_UBUNTU_HOST=0.1.0 with the latest  https://vagrantcloud.com/creditstretcher/ubuntu18.04-desktop vagrant box
    1. When your testing is finished delete your feature branch from the origin ubuntu-host-vm repo. Do this manually from [https://github.com/creditstretcher/ubuntu-host-vm/branches](https://github.com/creditstretcher/ubuntu-host-vm/branches) 
 
## Building the Vagrant boxes with Packer

To build the CreditStretcher box you will need [VMware Fusion](https://www.vmware.com/products/fusion)/[VMware Workstation](https://www.vmware.com/products/workstation)

    $ make build-cs
    
To build all the boxes, you will need [VirtualBox](https://www.virtualbox.org/wiki/Downloads), 
[VMware Fusion](https://www.vmware.com/products/fusion)/[VMware Workstation](https://www.vmware.com/products/workstation) and
[Parallels](http://www.parallels.com/products/desktop/whats-new/) installed.

Parallels requires that the
[Parallels Virtualization SDK for Mac](http://www.parallels.com/downloads/desktop)
be installed as an additional prerequisite.

We make use of JSON files containing user variables to build specific versions of Ubuntu.
You tell `packer` to use a specific user variable file via the `-var-file=` command line
option.  This will override the default options on the core `ubuntu.json` packer template,
which builds Ubuntu 18.04 by default.

For example, to build Ubuntu 18.04, use the following:

    $ packer build -var-file=ubuntu1804.json ubuntu.json
    
If you want to make boxes for a specific desktop virtualization platform, use the `-only`
parameter.  For example, to build Ubuntu 18.04 for VirtualBox:

    $ packer build -only=virtualbox-iso -var-file=ubuntu1804.json ubuntu.json

The boxcutter templates currently support the following desktop virtualization strings:

* `parallels-iso` - [Parallels](http://www.parallels.com/products/desktop/whats-new/) desktop virtualization (Requires the Pro Edition - Desktop edition won't work)
* `virtualbox-iso` - [VirtualBox](https://www.virtualbox.org/wiki/Downloads) desktop virtualization
* `vmware-iso` - [VMware Fusion](https://www.vmware.com/products/fusion) or [VMware Workstation](https://www.vmware.com/products/workstation) desktop virtualization

## Building the Vagrant boxes with the box script

We've also provided a wrapper script `bin/box` for ease of use, so alternatively, you can use
the following to build Ubuntu 18.04 for all providers:

    $ bin/box build ubuntu1804

Or if you just want to build Ubuntu 18.04 for VirtualBox:

    $ bin/box build ubuntu1804 virtualbox

## Building the Vagrant boxes with the Makefile

A GNU Make `Makefile` drives a complete basebox creation pipeline with the following stages:

* `build` - Create basebox `*.box` files
* `assure` - Verify that the basebox `*.box` files produced function correctly
* `deliver` - Upload `*.box` files to [Artifactory](https://www.jfrog.com/confluence/display/RTF/Vagrant+Repositories), [Atlas](https://atlas.hashicorp.com/) or an [S3 bucket](https://aws.amazon.com/s3/)

The pipeline is driven via the following targets, making it easy for you to include them
in your favourite CI tool:

    make build   # Build all available box types
    make assure  # Run tests against all the boxes
    make deliver # Upload box artifacts to a repository
    make clean   # Clean up build detritus

### Proxy Settings

The templates respect the following network proxy environment variables
and forward them on to the virtual machine environment during the box creation
process, should you be using a proxy:

* http_proxy
* https_proxy
* ftp_proxy
* rsync_proxy
* no_proxy

### Tests

Automated tests are written in [Serverspec](http://serverspec.org) and require
the `vagrant-serverspec` plugin to be installed with:

    vagrant plugin install vagrant-serverspec

The `bin/box` script has subcommands for running both the automated tests
and for performing exploratory testing.

Use the `bin/box test` subcommand to run the automated Serverspec tests.
For example to execute the tests for the Ubuntu 18.04 box on VirtualBox, use
the following:

    bin/box test ubuntu1804 virtualbox

Similarly, to perform exploratory testing on the VirtualBox image via ssh,
run the following command:

    bin/box ssh ubuntu1804 virtualbox

### Variable overrides

There are several variables that can be used to override some of the default
settings in the box build process. The variables can that can be currently
used are:

* cpus
* disk_size
* memory
* update

The variable `HEADLESS` can be set to run Packer in headless mode.
Set `HEADLESS := true`, the default is false.

The variable `UPDATE` can be used to perform OS patch management.  The
default is to not apply OS updates by default.  When `UPDATE := true`,
the latest OS updates will be applied.

The variable `PACKER` can be used to set the path to the packer binary.
The default is `packer`.

The variable `ISO_PATH` can be used to set the path to a directory with
OS install images. This override is commonly used to speed up Packer builds
by pointing at pre-downloaded ISOs instead of using the default download
Internet URLs.

The variables `SSH_USERNAME` and `SSH_PASSWORD` can be used to change the
 default name & password from the default `vagrant`/`vagrant` respectively.

The variable `INSTALL_VAGRANT_KEY` can be set to turn off installation of the
default insecure vagrant key when the image is being used outside of vagrant.
Set `INSTALL_VAGRANT_KEY := false`, the default is true.

The variable `CUSTOM_SCRIPT` can be used to specify a custom script
to be executed. You can add it to the `script/custom` directory (content
is ignored by Git).
The default is `custom-script.sh` which does nothing.

## Contributing


1. Fork and clone the repo.
2. Create a new branch, please don't work in your `master` branch directly.
3. Add new [Serverspec](http://serverspec.org/) or [Bats](https://blog.engineyard.com/2014/bats-test-command-line-tools) tests in the `test/` subtree for the change you want to make.  Run `make test` on a relevant template to see the tests fail (like `make test-virtualbox/ubuntu1804`).
4. Fix stuff.  Use `make ssh` to interactively test your box (like `make ssh-virtualbox/ubuntu1804`).
5. Run `make test` on a relevant template (like `make test-virtualbox/ubuntu1804`) to see if the tests pass.  Repeat steps 3-5 until done.
6. Update `README.md` and `AUTHORS` to reflect any changes.
7. If you have a large change in mind, it is still preferred that you split them into small commits.  Good commit messages are important.  The git documentatproject has some nice guidelines on [writing descriptive commit messages](http://git-scm.com/book/ch5-2.html#Commit-Guidelines).
8. Push to your fork and submit a pull request.
9. Once submitted, a full `make test` run will be performed against your change in the build farm.  You will be notified if the test suite fails.

### Would you like to help out more?

Contact moujan@annawake.com 

### Acknowledgments

[Parallels](http://www.parallels.com/) provided a Business Edition license of
their software to run on the basebox build farm.

<img src="http://www.parallels.com/fileadmin/images/corporate/brand-assets/images/logo-knockout-on-red.jpg" width="80">

[SmartyStreets](http://www.smartystreets.com) provided basebox hosting for the box-cutter project since 2015 - thank you for your support!

<img src="https://d79i1fxsrar4t.cloudfront.net/images/brand/smartystreets.65887aa3.png" width="320">
