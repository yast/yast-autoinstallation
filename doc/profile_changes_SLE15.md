## Main differences between SLE12 and SLE15 profiles

### Product selection

Starting with SLE15, all products are distributed using one medium.
You need to choose which product to install. To do so explicitly, use the
'product' option.

#### Explicit Product Selection

```xml
<software>
  <products config:type="list">
    <product>SLED</product>
  </products>
</software>
```

 In special cases, the medium might contain only one product. If so, you
 do not need to select a product explicitly as described above. AutoYaST will
 select the only available product automatically.

 For backward compatibility with profiles created for pre-SLE 15 products, AutoYaST
 implements a heuristic that selects products automatically. This heuristic will be
 used when the profile does not contain a 'product' element. This heuristic is based
 on the package and pattern selection in the profile. However, whenever possible,
 avoid using this mechanism and adapt old profiles to use explicit product selection.

### Firewall configuration

In SLE15, SuSEfirewall2 has been replaced by firewalld as the default firewall.

Taking in account that the configuration of both is quite different and that SLE12
profiles were closely coupled to the SuSEfirewall2 configuration, a new syntax
has been added.

Old profiles will continue working although the supported configuration will be very
limited, for that reason we recommend to check the final configuration in order to
avoid an unexpected behavior or network security threats.

This is the list of supported properties:**

- enable_firewall (same behavior)
- start_firewall (same behavior)
- FW_CONFIGURATIONS_{DMZ, EXT, INT}
- FW_DEV_{DMZ, EXT, INT}
- FW_SERVICES_{DMZ, INT, EXT}_{TCP, UDP, IP}
- FW_LOG_ACCEPT_CRIT
- FW_LOG_DROP_CRIT
- FW_LOG_DROP_ALL
- FW_MASQUERADE

The following examples will show with details the conversion of each property.

#### Whether firewalld should be enabled and running after the installation

```xml
  <firewall>
    # These attributes are the only ones that are completely compatible in both schemes
    <enable_firewall>true</enable_firewall>
    <start_firewall>true</start_firewall>
  </firewall>
```

Both firewalls are zone-based with a different predefined set of rules and level
of trust for network connections.

Whereas SuSEfirewall2 has 3 zones by default (DMZ, EXT, INT) firewalld provides
a few more (block, dmz, drop, external, home, internal, public, trusted, work).
In SuSEFirewall2 the default zone is the external one (EXT) but also allows the
use of the special keyword `any` to assign all the interfaces that are not listed
anywhere to a specified zone.

#### Assignation of interfaces to zones

The DMZ zone will be mapped to the 'dmz' zone, the EXT zone will be mapped to
the 'public' zone if FW_MASQUERADE is disabled or to the 'external' if it is
enabled and finally the INT zone will be mapped to the 'internal' zone if
FW_PROTECT_FROM_INT is true or to the 'trusted' zone if not.


**Default assignation**
```xml
<firewall>
  <FW_DEV_DMZ>any eth0</FW_DEV_DMZ>
  <FW_DEV_EXT>eth1 wlan0</FW_DEV_EXT>
  <FW_DEV_INT>wlan1</FW_DEV_INT>
</firewall>
```

```xml
<firewall>
  <default_zone>dmz</default_zone>
  <zones config:type="list">
    <zone>
      <name>dmz</name>
      <interfaces>
        <interface>eth0</interface>
      </interfaces>
    </zone>
    <zone>
      <name>public</name>
      <interfaces>
        <interface>eth1</interface>
      </interfaces>
    </zone>
    <zone>
      <name>trusted</name>
      <interfaces>
        <interface>wlan1</interface>
      </interfaces>
    </zone>
  </zones>
</firewall>
```

**With masquerading and protecting internal zone**

```xml
<firewall>
  <FW_DEV_DMZ>any eth0</FW_DEV_DMZ>
  <FW_DEV_EXT>eth1 wlan0</FW_DEV_EXT>
  <FW_DEV_INT>wlan1</FW_DEV_INT>
  <FW_MASQUERADE>yes</FW_MASQUERADE>
  <FW_PROTECT_FROM_INT>yes</FW_PROTECT_FROM_INT>
</firewall>
```

```xml
<firewall>
  <default_zone>dmz</default_zone>
  <zones config:type="list">
    <zone>
      <name>dmz</name>
      <interfaces config:type="list">
        <interface>eth0</interface>
      </interfaces>
    </zone>
    <zone>
      <name>external</name>
      <interfaces config:type="list">
        <interface>eth1</interface>
      </interfaces>
    </zone>
    <zone>
      <name>internal</name>
      <interfaces config:type="list">
        <interface>wlan1</interface>
      </interfaces>
    </zone>
  </zones>
</firewall>
```

#### Open ports

In SuSEFIrewall2 the FW_SERVICES_{DMZ,EXT,INT}_{TCP,UDP,IP,RPC} variables were
used to open ports in different zones.

In case of **TCP** or **UPD* we were allowed to enter a port number, a port range
or a `/etc/service` name. It will be mapped to ports in the equivalent firewalld
zone.

In case of **IP**, the SuSEFirewall2 definition will be mapped to firewalld
protocols in the equivalent firewalld zone.

Unfortunately firewalld does not support **RPC** configuration.

```xml
<firewall>
  FW_SERVICES_DMZ_TCP="ftp ssh 80 5900:5999"
  FW_SERVICES_EXT_UDP="1723 ipsec-nat-t"
  FW_SERVICES_EXT_IP="esp icmp gre"
  FW_MASQUERADE="yes"
</firewall>
```

```xml
<firewall>
  <zones config:type="list">
    <zone>
      <name>dmz</name>
      <ports config:type="list">
        <port>ftp/tcp</port>
        <port>ssh/tcp</port>
        <port>80/tcp</port>
        <port>5900-5999/tcp</port>
      <ports>
    </zone>
    <zone>
      <name>external</name>
      <ports config:type="list">
        <port>1723/udp</port>
        <port>ipsec-nat-t/udp</port>
      </ports>
      <protocols config:type="list">
        <protocol>esp</protocol>
        <protocol>icmp</protocol>
        <protocol>gre</protocol>
      </protocols>
    </zone>
  </zones>
</firewall>

```

#### Open firewalld services

For opening a combination of ports and/or protocols SuSEFirewall2 provides the
FW_CONFIGURATIONS_{EXT, DMZ, INT} variables which are equivalent to services in
firewalld.

```xml
<firewall>
  <FW_CONFIGURATIONS_EXT>dhcp dhcpv6 samba vnc-server</FW_CONFIGURATIONS_EXT>
  <FW_CONFIGURATIONS_DMZ>ssh</FW_CONFIGURATIONS_DMZ>
</firewall>
```

```xml
<firewall>
  <zones config:type="list">
    <zone>
      <name>dmz</name>
      <services config:type="list">
        <service>ssh</service>
      </services>
    </zone>
    <zone>
      <name>public</name>
      <services config:type="list">
        <service>dhcp</service>
        <service>dhcpv6</service>
        <service>samba</service>
        <service>vnc-server</service>
      </services>
    </zone>
  </zones>
</firewall>
```

**The services definition can be added via packages in both cases:**

- https://en.opensuse.org/SuSEfirewall2/Service_Definitions_Added_via_Packages
- https://en.opensuse.org/Firewalld/RPM_Packaging

Take in account that firewalld already provides most of the more important
services definitions so check the current services before defining a new one.


#### What about the rest of SuSEFirewall2 options?

We would like to continue supporting all the options but unfortunately some
of them do not have a equivalent mapping in firewalld or need some configuration
that is still not supported by AutoYaST or by firewalld.

For the options that are not supported by YaST / AutoYaST but are supported by
firewalld the use of `post-scripts` is probably the best alternative available.

#### Further documentation

- [AutoYaST doc](https://github.com/SUSE/doc-sle/blob/develop/xml/ay_bigfile.xml#L12999)
- [Firewalld official doc](http://www.firewalld.org/documentation/)

### NTP Configuration


The time server synchronization daemon ntpd has been replaced with the more
modern daemon Chrony.

This change means that AutoYaST files with an ntp_client section need to be
updated to a new format for this section.

Instead of containing low level configuration options, is now composed of a set
of high level ones that are applied on top of the default settings.

And here is how the new (and nicer) configuration looks like:


```xml
<ntp-client>
  <ntp_policy>auto</ntp_policy>
  <ntp_servers config:type="list">
    <ntp_server>
      <iburst config:type="boolean">false</iburst>
      <address>cz.pool.ntp.org</address>
      <offline config:type="boolean">true</offline>
    </ntp_server>
  </ntp_servers>
  <ntp_sync>systemd</ntp_sync>
</ntp-client>
```

Check out the latest development online documentation for further information
about each attribute.

- https://susedoc.github.io/doc-sle/develop/SLES-autoyast/html/configuration.html#Configuration.Network.Ntp

### AutoYaST packages are needed for 2nd stage

As you probably already know, a regular installation is performed in a single
stage while an auto-installation needs two stages in most of the cases.

AutoYaST will show a warning if the second stage is needed or enabled and some
mandatory package are missing like `autoyast2-installation` and `autoyast2`.

**Further documentation:**

- [AutoYaST doc](https://github.com/SUSE/doc-sle/blob/deb9fe3b4bc13a54c12cc34f56d22b7f31a22db9/xml/ay_bigfile.xml#L139)


## Ca Management module has been dropped

The module for CA Management (**yast2-ca-management**) has been removed from SLE15,
and for the time being there is no replacement available. It will affect all the
profiles that were using the `ca_mgm` section and which do not remove it.

## New Storage

### Setting partition numbers

AutoYaST will not allow the user to force partition numbers anymore, as it might
not work in some situations. Moreover, GPT is now the preferred partition table
type, so partition numbers are not that relevant.

However, the `partition_nr` is still available in order to specify a partition
to be reused.

### A default subvolume name for each Btrfs filesystem

The new storage layer allows the user to set different default subvolumes (or
none at all) for every Btrfs filesystem. As shown in the example below, a prefix
name can be specified for each partition using the `subvolumes_prefix`
attribute:

```xml
<partition>
  <mount>/</mount>
  <filesystem config:type="symbol">btrfs</filesystem>
  <size>max</size>
  <subvolumes_prefix>@</subvolumes_prefix>
</partition>
```

Given this new approach, the old `btrfs_set_default_subvolume_name` is
deprecated, although it is still supported for backward compatibility reasons.

### GPT is now the default partition type

On x86_64 systems, GPT is now the preferred partition type. However, if you
would like to retain the old behaviour, you could explictly indicate this in
the profile setting the `disklabel` element to `msdos`.

### Reading an existing /etc/fstab filesystem is not supported anymore

For the time being, the ability to read an existing /etc/fstab from a previous
installation when trying to determine the partitioning layout is not supported
anymore.


## Software

The SLE15 installation medium contains only a very minimal set of packages
to install. This minimal set does not include any server applications
or advanced tools.

If you need to install more packages then you need to use additional software
repositories:

- A registration server (the SUSE Customer Center or a SMT/RMT proxy)
- Additional Packages DVD medium with SLE15 modules and extensions. The DVD
  can be shared on the network via a local installation server.

*Note: Using the registration server will grant the access to the maintenance
updates. Maintenance updates are not available when using the DVD medium
without registration.*

### Using Modules or Extensions from the Registration Server

If you want to add a module or extension from the registration server
then add `addons` section to the registration configuration:

```xml
<suse_register>
  <addons config:type="list">
    <addon>
      <name>sle-module-basesystem</name>
      <version>15</version>
      <arch>x86_64</arch>
    </addon>
  </addons>
</suse_register>
```

For extensions which require a registration code write it into the `<reg_code>`
tag for the respective extension. See more details in the [Module and Extension
Dependencies](#module-and-extension-dependencies) section.

### Using the Packages DVD Medium

For using a physical Packages DVD medium use this XML snippet:

```xml
<add-on>
  <add_on_products config:type="list">
    <listentry>
      <media_url><![CDATA[dvd:///]]></media_url>
      <product>sle-module-basesystem</product>
      <product_dir>/Module-Basesystem</product_dir>
    </listentry>
  </add_on_products>
</add-on>
```

*Note: The `product` name must match the internal product name contained in the
repository. If the product name does not match at installation AutoYaST
will report an error.*

If you have multiple physical DVD drives you can select a specific device
using `devices` parameter in the URL, e.g. `dvd:///?devices=/dev/sr1`.

### Using the Packages Medium from a Local Server

You can share the DVD content on the local network via a NFS, FTP or HTTP server.

In that case use the same XML snippet as above, just edit the `media_url`
tag so it points to root of the medium on the server.


### Renamed Software Patterns

The software patterns have been also changed in SLE15. Some patterns have been
renamed, a short summary is in the following table.

| Old SLE12 Pattern | New SLE15 Pattern |
| :---------------- | :---------------- |
| Basis-Devel       | devel_basis       |
| gnome-basic       | gnome_basic       |
| Minimal           | enhanced_base     |
| printing          | print_server      |
| SDK-C-C++         | devel_basis       |
| SDK-Doc           | technical_writing |
| SDK-YaST          | devel_yast        |

#### Notes

- The pattern renames in the table above are not 1:1 replacements, the content
  of some patterns has been changed as well, some packages were moved to
  a different pattern or even removed from SLE15.
- Check that the required packages are still included in the used patterns,
  optionally use the `<packages>` tag to specify the required packages.
- The list might be incomplete, some products have not been released for SLE15 yet.

## Registration

### Module and Extension Dependencies

<!--
Copied from the latest development online documentation:
https://susedoc.github.io/doc-sle/develop/SLES-autoyast/single-html/#CreateProfile.Register.Extension
-->

Since SLES 15 AutoYaST automatically reorders the extensions according to their
dependencies during registration. That means the order of the extensions in
the AutoYaST profile is not important.

Also AutoYaST automatically registers the dependent extensions even though they
are missing in the profile. That means you are not required to fill the
extensions list completely.

However, if the dependent extension requires a registration key it must be
specified in the profile, including the registration key. Otherwise the
registration would fail.
