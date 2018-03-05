## Main differences between SLE12 and SLE15 profiles

### Product selection

Starting with SLE15, all products are distributed using one medium.
You need to choose which product to install. To do so explicitly, use the
'product' option.

## Explicit Product Selection

```xml
<software>
  <products config:type="list">
    <product>SLED15</product>
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
profiles were very bound to the SuSEfirewall2 configuration, a new syntax has been added.

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

The following examples will show with defails the conversion of each property.

#### Whether firewalld should be enabled and running after the installation

```xml
  <firewall>
    # These attributes are the only ones that are completely compatible in both schemas
    <enable_firewall>true</enable_firewall>
    <start_firewall>true</start_firewall>
  </>
```

Both firewalls are zone-based with a different predefined set of rules and level
of trust for network connections.

Whereas SuSEfIrewall2 has 3 zones by default (DMZ, EXT, INT) firewalld provides
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
  FW_DEV_DMZ="any eth0"
  FW_DEV_EXT="eth1 wlan0"
  FW_DEV_INT="wlan1"
</firewall>
```

```xml
<firewall>
  <default_zone>dmz</default_zone>
  <zones>
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

```

**With masquerading and protecting internal zone**

```xml
<firewall>
  FW_DEV_DMZ="any eth0"
  FW_DEV_EXT="eth1 wlan0"
  FW_DEV_INT="wlan1"
  FW_MASQUERADE="yes"
  FW_PROTECT_FROM_INT="yes"
</firewall>
```

```xml
<firewall>
  <default_zone>dmz</default_zone>
  <zones>
    <zone>
      <name>dmz</name>
      <interfaces>
        <interface>eth0</interface>
      </interfaces>
    </zone>
    <zone>
      <name>external</name>
      <interfaces>
        <interface>eth1</interface>
      </interfaces>
    </zone>
    <zone>
      <name>internal</name>
      <interfaces>
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

Unfortunately for **RPC** we do not have yet a direct mapping into firewalld
AutoYaST configuration.

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
  <zones>
    <zone>
      <name>dmz</name>
      <ports>
        <port>ftp/tcp</port>
        <port>ssh/tcp</port>
        <port>80/tcp</port>
        <port>5900-5999/tcp</port>
      <ports>
    </zone>
    <zone>
      <name>external</name>
      <ports>
        <port>1723/udp</port>
        <port>ipsec-nat-t/udp</port>
      </ports>
      <protocols>
        <protocol>esp</protocol>
        <protocol>icmp</protocol>
        </protocol>gre</protocol>
      </protocols>
    </zone>
  </zones>
</firewall>

```

#### Open firewalld services

For opening a combination or ports and/or protocols SuSEFirewall2 provides the
FW_CONFIGURATIONS_{EXT, DMZ, INT} variables what is known in firewalld as a
service.

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

- https://en.opensuse.org/SuSEfirewall2/Service_Definitions_Added_via_Packages
- https://en.opensuse.org/Firewalld/RPM_Packaging

#### Further documentation


- [AutoYaST doc](https://github.com/SUSE/doc-sle/blob/develop/xml/ay_bigfile.xml#L12999)
- [Firewalld official doc](http://www.firewalld.org/documentation/)

### NTP Configuration

- https://susedoc.github.io/doc-sle/develop/SLES-autoyast/html/configuration.html#Configuration.Network.Ntp

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
  <ntp_sync>15</ntp_sync>
</ntp-client>
```

### AutoYaST packages are needed for 2nd stage

As you probably already know, a regular installation is performed in a single
stage while an auto-installation needs two stages in most of the cases.

For that reason, AutoYaST will show a warning if the second stage is needed or
enabled and some mandatory package are missing like `autoyast2-installation`
and `autoyast2`.

**Further documentation:**

- [AutoYaST doc](https://github.com/SUSE/doc-sle/blob/deb9fe3b4bc13a54c12cc34f56d22b7f31a22db9/xml/ay_bigfile.xml#L139)



## New Storage
