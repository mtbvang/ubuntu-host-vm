## Ansible provisioning of localdev contaiiner

Ansible scripts and files used to provision/configure the docker container Dockerfile-localdev.

The provisioning will be run by the Dockerfile-localdev dockerfile when the make file target `up-localdev` is run.

The provisioning can also be run on an existing container by running the makefile target `provision-localdev`.


```
make attach-localdev
# from /app directory run
make provision-localdev
```

NOTE: You need to remove any old versions of tools you want upgraded or reinstalled before reprovisioning otherwise they 
will not be upgraded/reinstalled.

### SSH and AWS configs and credentials

The `up-localdev` target will use the ~/.ssh/config and ~/.aws config and credentials files on your host machine. These 
files will be copied over to the container, but changes in them in the container will not be reflected on the host. This 
required for various reasons such as the 


