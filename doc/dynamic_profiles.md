## Dynamic Profiles

Somemtimes having static profile is not enough when it should be applied to wide range
of machines and some dynamic content is useful. Currently autoyast supports
three different ways how to achieve it. The first and the least flexible is 
rules and classes [ TODO link to its documentation ]. The second way is creating
profile via pre script [ TODO link to its documentation ]. It allows to use wide 
range of languages and create profile from scratch or copy existing one and
just modify it. Example of creating profile from scratch using shell is
below. The third way is templates. Autoyast from SLE15 SP3 supports ERB templates
[ TOO link to ERB documentation ]. ERB is default templating system in ruby
and basically do preprocessing of specific directives with full power of ruby
programming language. Example of such template is below. To work it properly it has
to have suffix `.erb`.

Pre script with shell example that use two biggest disks for installation:
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

Example with ERB template that use two biggest disks, enable multipath
for specific storage controller and set udev rules for network cards:

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
