Networking Scenarios
====================

This document tries to clarify some doubts and expectations related to AutoYaST network
configuration, specially regarding the `keep_install_network` option.

We put special attemption to that flag because there was a bug in SP1 which caused the
 network configuration being saved always even with `keep_install_network=false`. After
 the bug was fixed, users who were using a SP1 profile started reporting bugs for SP2.

The current documentation explains that the network configuration is done during the second
stage (imported from the profile) as it can be seen in the image below.

<p align="center">
  <img src="https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/images/autoyast-oview.png" />
</p>

Nevertheless, during the first stage the network would be required. The configuration 
can be copied to the installed system if `keep_install_network` is set to true.

Let's go with some scenarios and examples...

Scenarios
=========

First of all, what happens during the **first stage** will be explained, and then what 
happens during the **second stage** if not skipped. 

For the examples below consider this linuxrc options if not mentioned different ones:

**Linuxrc options:** autoyast=http://....sle12_minimal.xml ifcfg=eth0=dhcp

First Stage
-----------

The network configuration for the first stage currently defined in the control 
file takes part in these clients (**inst_autoinit**, **inst_autosetup** and 
**inst_finish**).

- **inst_autoinit:** Autoinit will call iSCSI or FCOE clients if they are 
  enabled in Linuxrc and will try to fetch and process the profile.

- **inst_autosetup:** This client checks the profile and writes the network 
  configuration files only if there is a network section defined 'and' (the
  setup_before_proposal flag is true 'or' if there is a semi-automatic section)

- **inst_finish:** At the end it will call **save_network** client which copies
  udev rules and ifcfg files from the running system and is also responsible 
  for writing several proposals like virtualization, dns and network service.

Enough theory by now, it's time to the examples:

1. **Autoinstallation without network section. (minimal configuration)**

  Just consider the profile below as the used for this scenario.

  ```xml
<profile xmlns="http://www.suse.com/1.0/yast2ns" xmlns:config="http://www.suse.com/1.0/configns">
  <general>
    <mode>
      <confirm config:type="boolean">false</confirm>
    </mode>
  </general>
  <software>
    <install_recommended config:type="boolean">true</install_recommended>
    <patterns config:type="list">
      <pattern>Minimal</pattern>
      <pattern>base</pattern>
    </patterns>
  </software>
</profile>
```

  **Results:**

  With this configuration autoinit won't write anything because there is no networking section,
  but as linuxrc network configuration was given the ifcfg-file exists in the running system.

  ```xml
# /etc/sysconfig/network/ifcfg-eth0 
BOOTPROTO='dhcp'
STARTMODE='auto'
DHCLIENT_SET_HOSTNAME='yes' ## THIS IS NOT PRESENT IN SP3 or SP2 versions with last yast2-network package
```

  Therefore, when `save_network` is called by `inst_finish` it will copy the 
  udev rules and sysconfig network configuration files because by default `keep_net_config?` is
  considered as **true**.

  And about DNS, as no network section is provided, it will write the configuration proposed by 
  NetworkAutoconfiguration. It's important to point it out because in case of exists it won't
  be written.
  
2. **Autoinstallation with `keep_install_network = true`**

  In case that the networking section contains the `keep_install_network=true` the result should be 
  the same as previously. The profile has been modified with a static configuration for the `eth0`
  interface, a default route and with the addition of DNS configuration.
  
   ```xml
<profile xmlns="http://www.suse.com/1.0/yast2ns" xmlns:config="http://www.suse.com/1.0/configns">
  <networking>
    <keep_install_network config:type="boolean">true</keep_install_network>
    <interfaces config:type="list">
      <interface>
        <bootproto>static</bootproto>
        <device>eth0</device>
        <ipaddr>192.168.122.69</ipaddr>
	      <netmask>255.255.255.0</netmask>
	      <startmode>auto</startmode>
      </interface>
    </interfaces>
    <routing>
      <routes config:type="list">
        <route>
          <destination>default</destination>
          <device>-</device>
          <gateway>192.168.122.1</gateway>
          <netmask>-</netmask>
        </route>
      </routes>
    </routing>
  </networking>
</profile>
```

  **Results**
  
  As commented in the introduction of the present documentation, the network configuration is
  mainly done during the `Second Stage`, and the configuration of the interfaces is the linuxrc
  one, this is again:
  
   ```bash
# /etc/sysconfig/network/ifcfg-eth0 
BOOTPROTO='dhcp'
STARTMODE='auto'
DHCLIENT
```

  But there is a difference in case of DNS. If the DNS subsection is present then it will not be 
  configured with the proposed one, wich means that for example `resolv.conf` does not exists yet.
  
  Of course there is two special cases permitted, the most common is with `setup_before_proposal` used
  to run the network configuration before the registration during the 1st stage and the other one
  is with a semi-automatic configuration but I will let it out of the scope of this document anyway
  you can see more about both [here](https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#CreateProfile.Register).
  
  **With `setup_before_proposal=true`**
  
   ```bash
# /etc/sysconfig/network/ifcfg-eth0 
BOOTPROTO='static'
STARTMODE='auto'
DHCLIENT_SET_HOSTNAME='yes'
IPADDR=192.168.122.69
NETMASK=255.255.255.0
PREXIXLEN=24

# /etc/sysconfig/network/routes 
default 192.168.122.1 - - 

# /etc/hostname 
vikingo.suse.com
```

  But it will not create the resolv.conf 
  
  In case of no **Second Stage** the configuration could be written from the profile as 
  it is done with the `setup_before_proposal` flag ([code](https://github.com/yast/yast-autoinstallation/blob/fd73e52db5d6574351ac4596bfea4836e143ae8a/src/clients/inst_autosetup.rb#L165)]
  and also write the DNS configuration (it was already commented in the [code](https://github.com/yast/yast-autoinstallation/blob/fd73e52db5d6574351ac4596bfea4836e143ae8a/src/clients/inst_autosetup.rb#L165)).
  
3. **Autoinstallation with `keep_install_network = false`**

  The profile used will be the same that above just modifying `keep_install_network` setting it as **false**.
  
  ```xml
<profile xmlns="http://www.suse.com/1.0/yast2ns" xmlns:config="http://www.suse.com/1.0/configns">
  <networking>
    <keep_install_network config:type="boolean">false</keep_install_network>
    <interfaces config:type="list">
      <interface>
        <bootproto>static</bootproto>
        <device>eth0</device>
        <ipaddr>192.168.122.69</ipaddr>
	      <netmask>255.255.255.0</netmask>
	      <startmode>auto</startmode>
      </interface>
    </interfaces>
    <routing>
      <routes config:type="list">
        <route>
          <destination>default</destination>
          <device>-</device>
          <gateway>192.168.122.1</gateway>
          <netmask>-</netmask>
        </route>
      </routes>
    </routing>
  </networking>
</profile>
```

  And as expected after the 1st stage installation the configuration will not be copied from the 
  inst-sys, https://github.com/yast/yast-network/blob/SLE-12-SP2/src/clients/save_network.rb#L87
  
  ```bash
  ls /mnt/etc/sysconfig/network/
config  dhcp  ifcfg-lo  ifcfg.template  if-down.d  if-up.d  providers  scripts
  
  cat /mnt/etc/resolv.conf
cat: /mnt/etc/resolv.conf: No such file or directory

  cat /mnt/etc/hostname 
linux.suse
```

  About this comment in the PBI that this document was for:

  <quote>The user has the option that the installation network can be available until YAST has been 
  finished completely (AFTER the second stage) and will be removed if keep_install_network has been
  set to false. Currently it will be removed before booting into system and starting the second 
  installation stage.</quote>
  
  It is currently documented in the [network section](https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#CreateProfile.Network) 
  and has been updated recently clarifying some aspects.
  
  This is the paragraph explaining exactly that issue.
  
  <quote>During the second stage, installation of additional packages will take place before the 
  network, as described in the profile, is configured. keep_install_network is set by default to 
  true to ensure that a network is available in case it is needed to install those packages. If 
  all packages are installed during the first stage and the network is not needed early during the
  second one, setting keep_install_network to false will avoid copying the configuration.</quote>

  And regarding to post scripts (see this bug https://bugzilla.suse.com/show_bug.cgi?id=1014859), 
  the download part has been moved from second stage to the first stage in this [PR](https://github.com/yast/yast-autoinstallation/pull/274),
  fixing the problem with post scripts and no network configuration during the earlier part of 
  the `second stage`.
  
Second Stage
-----------------

In this stage is where most of the system configuration take place, it is the default and most
commonly used for SLE and openSUSE (but not for CaaSP). 

The network configuration is done by the `inst_autoconfigure` client.

From the autoyast network documentation:
<quote>
This client will read the desktop configuration files of all the installed modules and will 
parse the section as well will launch the corresponding client based on what was defined in 
the file.

Concerning to networking the most important one is the lan.desktop file which defines the 
networking profile's resource to be parsed and as it does not define a specific client to 
be called it will use the default value lan_auto.

And finally lan_auto will write our network config.</quote>

1. **Without network section. (minimal configuration)**

  If no network section is defined then the `inst_autoconfigure` client will remove all the 
  interfaces configuration and lan_auto will not be called.

  ** profile **
  ```xml
<profile xmlns="http://www.suse.com/1.0/yast2ns" xmlns:config="http://www.suse.com/1.0/configns">
  <general>
    <mode>
      <confirm config:type="boolean">false</confirm>
    </mode>
  </general>
</profile>
```
  
  This could be an alternative to **keep_install_network=false** and installing  packages during
  the second stage (needing networking).
  
2. **With `keep_install_network = true` (default)**

   Taking in account that the installation was launched with this profile:
   
   ```xml
<profile xmlns="http://www.suse.com/1.0/yast2ns" xmlns:config="http://www.suse.com/1.0/configns">
  <networking>
    <keep_install_network config:type="boolean">true</keep_install_network>
    <interfaces config:type="list">
      <interface>
        <bootproto>static</bootproto>
        <device>eth0</device>
        <ipaddr>192.168.122.69</ipaddr>
	      <netmask>255.255.255.0</netmask>
	      <startmode>auto</startmode>
      </interface>
    </interfaces>
    <routing>
      <routes config:type="list">
        <route>
          <destination>default</destination>
          <device>-</device>
          <gateway>192.168.122.1</gateway>
          <netmask>-</netmask>
        </route>
      </routes>
    </routing>
  </networking>
</profile>
```
  **Results**
  
  At the end of the the first stage the configuration was copied from the inst-sys. 
  
  And that will be the network configuration for installing extra packages during the 
  second stage, after that, `inst_autoconfigure` will call `lan_auto` which will configure
  the network and DNS replacing the linuxrc config.
  
  ```bash
  # /etc/sysconfig/network/ifcfg-eth0
  BOOTPROTO='static'
  STARTMODE='auto'
  DHCLIENT_SET_HOSTNAME='yes'
  IPADDR=192.168.122.69
  NETMASK=255.255.255.0
  PREXIXLEN=24

  # /etc/sysconfig/network/routes 
  default 192.168.122.1 - - 

  # /etc/hostname 
  vikingo.suse.com
  ```
  
3. **With `keep_install_network = false`**

  The profile used in the **First Stage** scenario was:
  
  ```xml
<profile xmlns="http://www.suse.com/1.0/yast2ns" xmlns:config="http://www.suse.com/1.0/configns">
  <networking>
    <keep_install_network config:type="boolean">false</keep_install_network>
    <interfaces config:type="list">
      <interface>
        <bootproto>static</bootproto>
        <device>eth0</device>
        <ipaddr>192.168.122.69</ipaddr>
	      <netmask>255.255.255.0</netmask>
	      <startmode>auto</startmode>
      </interface>
    </interfaces>
    <routing>
      <routes config:type="list">
        <route>
          <destination>default</destination>
          <device>-</device>
          <gateway>192.168.122.1</gateway>
          <netmask>-</netmask>
        </route>
      </routes>
    </routing>
  </networking>
</profile>
```

  And the state after first installation (no config copyed from inst-sys):
  
  ```bash
  ls /mnt/etc/sysconfig/network/
config  dhcp  ifcfg-lo  ifcfg.template  if-down.d  if-up.d  providers  scripts
  
  cat /mnt/etc/resolv.conf
cat: /mnt/etc/resolv.conf: No such file or directory

  cat /mnt/etc/hostname 
linux.suse
```

  Which means that the network will not be available at the beggining of the **Second stage**.
  
  For this test I used 
  
  **LinuxRC options:** autoyast=http://..sle12_minimal.xml ifcfg=eth0=dhcp install=http://dist.suse.de/install/SLP/SLE-12-SP2-Server-LATEST/x86_64/DVD1
  
  and added to the profile:
  ```xml
  <software>
    <post-patterns config:type="list">
      <pattern>apparmor</pattern>
    </post-patterns>
  </software>
  ```
  
  which reports an error not being able to fetch the packages for **apparmor** pattern.
  
  Then `inst_autoconfigure` will remove all the interfaces configuration not configured in the profile
  and finally, `lan_auto` will configure our network.
  
  ```bash
# /etc/sysconfig/network/ifcfg-eth0 
BOOTPROTO='static'
STARTMODE='auto'
DHCLIENT_SET_HOSTNAME='yes'
IPADDR=192.168.122.69
NETMASK=255.255.255.0
PREXIXLEN=24

# /etc/sysconfig/network/routes 
default 192.168.122.1 - - 

# /etc/hostname 
vikingo.suse.com
  ```
  
  In the case of additional packages or extra packages that needs network before
  the network is configured in the second stage then `setup_before_proposal` flag
  could be used .
