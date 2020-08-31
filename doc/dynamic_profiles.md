## Dynamic Profiles

Sometimes having a static profile is not enough when it should be applied to a wide range of
machines. In such situation, generating some dynamic content for the profile is needed. Nowadays,
AutoYaST supports three different ways to do it. The first, and the least flexible, are rules and
classes [ TODO link to its documentation ]. The second way is modifying the profile using a
pre-script [ TODO link to its documentation ]. It allows to use a wide range of languages, creating
the profile from scratch or copying and modifying an existing one.

This example uses a shell-based pre-script that selects the two biggest disks for installation:

```xml
<?xml version="1.0"?>
<!DOCTYPE profile>
<profile xmlns="http://www.suse.com/1.0/yast2ns" xmlns:config="http://www.suse.com/1.0/configns">
  <scripts>
    <pre-scripts config:type="list">
      <script>
        <interpreter>shell</interpreter>
        <source><![CDATA[
          # get list of disks. In this case it picks two biggest disks
          # Some details, perl part makes disk info one liner, sed keep just device name and its capacity. Then it is sorted and removed size info
          DISKS=`hwinfo --disk | perl -p0E 'while(s/^(.*)\n /$1 /gm){}' | sed '/^$/d; s/^.*Device File: \([^ ]\+\).*Capacity: [^(]*(\(.*\) bytes).*/\1 \2/' | sort --key 2 -nr | sed 's/ [0-9]*$//' | head -2`
          # final static profile
          TARGET_FILE=/tmp/profile/modified.xml
          echo '<profile xmlns="http://www.suse.com/1.0/yast2ns" xmlns:config="http://www.suse.com/1.0/configns">
            <software>
              <products config:type="list">
                <product>openSUSE</product>
              </products>
            </software>
            <partitioning t="list">' > $TARGET_FILE
          for i in $DISKS; do
            echo "<drive><device>$i</device><initialize t=\"boolean\">true</initialize></drive>" >> $TARGET_FILE
          done
          echo '</partitioning></profile>' >> $TARGET_FILE
          ]]>
        </source>
      </script>
    </pre-scripts>
  </scripts>
</profile>
```

The third way is using templates. From SLE 15 SP3, AutoYaST supports ERB templates [ TOO link to ERB
documentation ]. ERB is the default templating system in Ruby and, basically, it allows
preprocessing of specific directives with the full power of Ruby programming language. You enable
this preprocessing by using the suffix `.erb` in the profile's name.

This ERB template uses the two biggest disks, enables multipath for specific storage controller and
sets udev rules for network cards:

```erb
<profile xmlns="http://www.suse.com/1.0/yast2ns" xmlns:config="http://www.suse.com/1.0/configns">
<%# example how to dynamic force multipath. Here it use storage model and if
    it contain case insensitive word multipath %>
  <% if hardware["storage"].any? { |s| s["model"] =~ /multipath/i } %>
    <general>
      <storage>
        <start_multipath t="boolean">true</start_multipath>
      </storage>
    </general>
  <% end %>
  <software>
    <products config:type="list">
      <product>openSUSE</product>
    </products>
  </software>
  <%# for details about values see libhd %>
  <% disks = hardware["disk"].sort_by { |d| s = d["resource"]["size"].first; s["x"]*s["y"] }.map { |d| d["dev_name"] }.reverse %>
  <partitioning t="list">
    <% disks[0..1].each do |name| %>
      <drive>
        <device>
          <%= name %>
        </device>
        <initialize t="boolean">
          true
        </initialize>
      </drive>
    <% end %>
  </partitioning>
  <%# situation: machine has two network catds. One leads to intranet and other to internet, so here we create udev
    rules to have internet one as eth0 and intranet as eth1. To distinguish in this example intranet one is not active %>
  <networking>
    <net-udev t="list">
      <rule>
        <name>eth0</name>
        <rule>ATTR{address}</rule>
        <value>
          <%= hardware["netcard"].find { |c| c["resource"]["link"].first["state"] }["resource"]["phwaddr"].first["addr"] %>
        </value>
      </rule>
      <rule>
        <name>eth1</name>
        <rule>ATTR{address}</rule>
        <value>
          <%= hardware["netcard"].find { |c| !c["resource"]["link"].first["state"] }["resource"]["phwaddr"].first["addr"] %>
        </value>
      </rule>
    </net-udev>
  </networking>
</profile>
```

### ERB Helpers

For ERB template there are available some helpers. So far only one is method `hardware`
which provides Hash read from libhd [ TODO link to .probe agent documentation ].
