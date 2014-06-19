lxc-manager
===========

Allows to automatically manage LXC containers with Puppet

This simple Puppet module contains some useful functions such as package, services and users control, 
that allows you to manage many different LXC containers from Puppet-master. Module already has simple examples
how to use functions.

How to install:
1. create separate directory and copy all files to it;
2. type `./setup.sh`;
2.1. if your distribution has no `nsenter` command from `util-linux`, just type `./nsenter.sh`;
3. move file `class.pp` file to any directory you'd prefer and `import` in your own manifest.

