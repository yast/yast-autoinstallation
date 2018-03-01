## Main differences between SLE12 and SLE15 profiles

### Product selection

- https://github.com/SUSE/doc-sle/blob/develop/xml/ay_bigfile.xml#L4521

### Firewall configuration

https://github.com/SUSE/doc-sle/blob/develop/xml/ay_bigfile.xml#L12999

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
      <interfaces>eth0</interfaces>
    </zone>
    <zone>
      <name>public</name>
      <interfaces>eth1</interfaces>
    </zone>
    <zone>
      <name>internal</name>
      <interfaces>wlan1</interfaces>
    </zone>
  </zones>

```

#### NTP Configuration

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
