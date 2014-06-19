### Comments and code created by Michael Morgoev
### mmg@sfedu.ru

### This manifest allows to do some useful actions
### with configs or file system in LXC-containers
### with the following schema: 
### «puppetmaster <—> puppetagent <—> set of LXC-containers on agent».
### So puppetmaster doesn't know any information about containers
### and vice versa. It allows to master work with
### many containers like with slaves. Here agent is a kind of
### proxy in this manifest.
### You do not need network connection between agent and containers.
### Note, that you need puppet and nsenter from util-linux (version >=2.23)
### as dependencies to this manifest.
### Archive contains: this manifest, script getos.sh to find out name of distr,
### script nsenter.sh to compile and install util-linux/nsenter on your Debian and
### script setup.sh to install getos.sh as command.
### BE CAREFUL! All functions require root privileges for executing!

#Default path to containers
$LXC_ENV_PATH = '/var/lib/lxc/'

# This variable contains string with name of current machine distr.
# There is some hack with copying getos.sh to /usr/bin/getos to get absolute path
$os = generate("/usr/bin/getos", "/etc/os-release")

# This is some like a helloworld function to test efficiency
define test_files($fname, $owner='root', $group='root', $mode='0644', 
	$content = "HELLO WORLD!", $lxc_path = $LXC_ENV_PATH)
{
	file { "${LXC_ENV_PATH}${title}/rootfs/${fname}":
		ensure 	=> file,
		content => $content,
		owner 	=> $owner,
		group 	=> $group,
		mode 	=> $mode,
	}	
}

# This function provides adding and removing users in containers
define manage_users($user_name, $action = "create", $m_groups = "sudo,ubuntu",
	$lxc_path = $LXC_ENV_PATH)
{
	if $os == "Ubuntu" or "Debian" {
		$cg_path = "/sys/fs/cgroup/cpu/${title}/"
	}
	elsif $os == "Arch Linux" {
		$cg_path = "/sys/fs/cgroup/cpu/lxc/${title}/"
	}
	else { #equals default
		$cg_path = "/sys/fs/cgroup/cpu/${title}/"
	}
	
	#according to puppet man — `if` is not a command so you need to add `true && ` in the beginning of command to exec
	$nsenter = "true && if [ -d ${cg_path} ] ; then nsenter -p -t `head -n 1 ${cg_path}tasks` ; else true ; fi"
	$path = "export PATH=\$PATH:/sbin:/bin"
	
	if $action == "create" {
		$command = "useradd -b /home/ -G ${m_groups} -m -s /bin/bash -U ${user_name}"
		exec {"${nsenter} && chroot ${LXC_ENV_PATH}${title}/rootfs /bin/bash -c '${path} && ${command}'":
			path 	=> ["/usr/sbin", "/usr/bin", "/bin"],
		}
	} #delete user
	else {
		if $os == "Ubuntu" or "Debian" {
			$command = "deluser --remove-all-files ${user_name}"
		}
		elsif $os == "Arch Linux" {
			$command = "userdel --remove ${user_name}"
		}
		else {
			$command = "deluser --remove-all-files ${user_name}"
		}
		exec {"${nsenter} && chroot ${LXC_ENV_PATH}${title}/rootfs /bin/bash -c '${path} && ${command}'":
			path 	=> ["/usr/sbin", "/usr/bin", "/bin"],
			onlyif 	=> "test -d ${LXC_ENV_PATH}/${title}/rootfs/home/$user_name",
		}
	}
}

# This function provides (un)installing packages in containers
# Note, that packages and all their dependencies will fully uninstalled on Arch Linux! BE CAREFUL
define manage_packages($packages, $action = "install", $lxc_path = $LXC_ENV_PATH)
{
	$path = "export PATH=\$PATH:/sbin:/bin"
	
	if $action == "install" {
		if $os == "Ubuntu" or "Debian" {
			$cg_path = "/sys/fs/cgroup/cpu/${title}/"
			$manager = "apt-get install -qq --force-yes"
		}
		elsif $os == "Arch Linux" {
			$cg_path = "/sys/fs/cgroup/cpu/lxc/${title}/"
			$manager = "pacman -S --noconfirm"
		}
		else {
			$cg_path = "/sys/fs/cgroup/cpu/${title}/"
			$manager = "apt-get install -qq --force-yes"
		}
		
		$nsenter = "true && if [ -d ${cg_path} ] ; then nsenter -p -t `head -n 1 ${cg_path}/tasks` ; else true ; fi"
		$command = "${manager} ${packages}"
		
		exec {"${nsenter} && chroot ${LXC_ENV_PATH}${title}/rootfs /bin/bash -c '${path} && ${command}'":
			path 	=> ["/usr/sbin", "/usr/bin", "/bin"],
		}
	}
	else { #uninstall packages with their confs and dependencies (for Arch Linux)
		if $os == "Ubuntu" or "Debian" {
			$cg_path = "/sys/fs/cgroup/cpu/${title}/"
			$manager = "apt-get purge -qq --force-yes"
		}
		elsif $os == "Arch Linux" {
			$cg_path = "/sys/fs/cgroup/cpu/lxc/${title}/"
			$manager = "pacman -Rscn --noconfirm"
		}
		else {
			$cg_path = "/sys/fs/cgroup/cpu/${title}/"
			$manager = "apt-get purge -qq --force-yes"
		}
		
		$nsenter = "true && if [ -d ${cg_path} ] ; then nsenter -p -t `head -n 1 ${cg_path}/tasks` ; else true ; fi"
		$command = "${manager} ${packages}"
		
		exec {"${nsenter} && chroot ${LXC_ENV_PATH}${title}/rootfs /bin/bash -c '${path} && ${command}'":
			path 	=> ["/usr/sbin", "/usr/bin", "/bin"],
		}
	}
}

# This function provides updating DB of packages and upgrading packages in containers
define upgrade_packages($lxc_path = $LXC_ENV_PATH) {
	
	$path = "export PATH=\$PATH:/sbin:/bin"
	
	if $os == "Ubuntu" or "Debian" {
		$cg_path = "/sys/fs/cgroup/cpu/${title}/"
		$deb_upgrade = "DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -q -y -o 'Dpkg::Options::=--force-confdef' -o 'Dpkg::Options::=--force-confold' upgrade"
		$deb_update = "DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -q -y -o 'Dpkg::Options::=--force-confdef' -o 'Dpkg::Options::=--force-confold' update"
		$manager = "${deb_update} ; ${deb_upgrade}"
	}
	elsif $os == "Arch Linux" {
		$cg_path = "/sys/fs/cgroup/cpu/lxc/${title}/"
		$manager = "pacman -Syyu --noconfirm"
	}
	else {
		$cg_path = "/sys/fs/cgroup/cpu/${title}/"
		$deb_upgrade = "DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -q -y -o 'Dpkg::Options::=--force-confdef' -o 'Dpkg::Options::=--force-confold' upgrade"
		$deb_update = "DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -q -y -o 'Dpkg::Options::=--force-confdef' -o 'Dpkg::Options::=--force-confold' update"
		$manager = "${deb_update} ; ${deb_upgrade}"
	}
	
	$nsenter = "true && if [ -d ${cg_path} ] ; then nsenter -p -t `head -n 1 ${cg_path}/tasks` ; else true ; fi"
	
	exec {"${nsenter} && chroot ${LXC_ENV_PATH}${title}/rootfs /bin/bash -c '${path} && ${manager}'":
		path 	=> ["/usr/sbin", "/usr/bin", "/bin"],
	}
}

# This function allows you to change configs of different services on some containers
# at the same time. Note, that you need to specify name of service, path to config file and name of config itself.
# After that service will restart to apply changes. You will be notified if something goes wrong (e.g. wrong service config or 
# fails after restarting service etc.)
define manage_configs($servicename, $path_to_conf, $conffname, 
	$owner='root', $group = 'root', $mode = '0600',
	$content, $lxc_path = $LXC_ENV_PATH)
{
	$path = "export PATH=\$PATH:/sbin:/bin"
	
	file { "${LXC_ENV_PATH}${title}/rootfs/${path_to_conf}/${conffname}":
		notify 	=> Exec[$servicename],
		ensure => present,
		mode	=> $mode,
		owner	=> $owner,
		group 	=> $group,
		content => $content,
	}
	
	if $os == "Ubuntu" or "Debian" {
		$cg_path = "/sys/fs/cgroup/cpu/${title}/"
		$nsenter = "true && if [ -d ${cg_path} ] ; then nsenter -p -t `head -n 1 ${cg_path}/tasks` ; else true ; fi"
		$command = "service ${servicename} restart"
		exec {$servicename:
			path 	=> ["/usr/sbin", "/usr/bin", "/bin"],
			command => "${nsenter} && chroot ${LXC_ENV_PATH}${title}/rootfs /bin/bash -c '${path} && ${command}'",
			onlyif	=> "test -d ${cg_path}",
		}
	}
	elsif $os == "Arch Linux" {
		$cg_path = "/sys/fs/cgroup/cpu/lxc/${title}/"
		$nsenter = "true && if [ -d ${cg_path} ] ; then nsenter -p -t `head -n 1 ${cg_path}/tasks` ; else true ; fi"
		$command = "systemctl restart ${servicename}.service"
		exec {$servicename:
			path 	=> ["/usr/sbin", "/usr/bin", "/bin"],
			command => "${nsenter} && chroot ${LXC_ENV_PATH}${title}/rootfs /bin/bash -c '${path} && ${command}'",
			onlyif	=> "test -d ${cg_path}",
		}
	}
	else { #default choice — Debian-like
		$cg_path = "/sys/fs/cgroup/cpu/${title}/"
		$nsenter = "true && if [ -d ${cg_path} ] ; then nsenter -p -t `head -n 1 ${cg_path}/tasks` ; else true ; fi"
		$command = "service ${servicename} restart"
		exec {$servicename:
			path 	=> ["/usr/sbin", "/usr/bin", "/bin"],
			command => "${nsenter} && chroot ${LXC_ENV_PATH}${title}/rootfs /bin/bash -c '${path} && ${command}'",
			onlyif	=> "test -d ${cg_path}",
		}
	}
}

### Some examples of implmented functions:

# test_files { ["u1", "u2"]: fname => "test_file.txt" }
#
# manage_users { ["u1", "u2"]: user_name => "test6", action => "create" }
#
# manage_users { "u1": user_name => "test6", action => "delete" }
#
# manage_packages { "u1": packages => "htop links" }
#
# manage_packages { "u1": packages => "htop links", action => "delete" }
#
# upgrade_packages { [ "u1", "u2" ]: }

# manage_configs { "u1": 
# 	servicename	=> "puppetmaster", 
# 	path_to_conf	=> "/etc/puppet/", 
# 	conffname	=> "puppet.conf", 
# 	content		=> 
# "
# [main]
# logdir=/var/log/puppet
# vardir=/var/lib/puppet
# ssldir=/var/lib/puppet/ssl
# rundir=/var/run/puppet
# factpath=$vardir/lib/facter
# templatedir=$confdir/templates
#
# [master]
# # These are needed when the puppetmaster is run by passenger
# # and can safely be removed if webrick is used.
# #THIS IS TEST COMMENT TO ENSURE OF WORKING0
# ssl_client_header = SSL_CLIENT_S_DN 
# ssl_client_verify_header = SSL_CLIENT_VERIFY
# #THIS IS TEST COMMENT TO ENSURE OF WORKING1
# #TEST COMMENT2
# " }

