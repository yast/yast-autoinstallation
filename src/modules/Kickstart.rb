# encoding: utf-8

# File:	modules/Kickstart.ycp
# Package:	Autoinstallation Configuration System
# Summary:	Imports older and foreign formats
# Authors:	Anas Nashif<nashif@suse.de>
#
# $Id$
require "yast"

module Yast
  class KickstartClass < Module
    def main
      textdomain "autoinst"
      Yast.import "AutoinstConfig"
      Yast.import "AutoinstStorage"
      Yast.import "Popup"
      Yast.import "Profile"
      Yast.import "Y2ModuleConfig"
      Yast.import "FileSystems"

      Yast.include self, "autoinstall/xml.rb"


      @ksConfig = {}

      @ksfile = ""
      Kickstart()
    end

    # Constructor
    def Kickstart
      nil
    end

    # Read a Kickstart file
    # @return [Hash] kickstart configuration.
    def Read
      @ksConfig = Convert.to_map(SCR.Read(path(".kickstart"), @ksfile))
      SCR.UnmountAgent(path(".kickstart"))

      Builtins.y2debug("Kickstart config raw: %1", @ksConfig)
      return {} if @ksConfig == {} || @ksConfig == nil

      nil
    end

    # Users()
    # Read KS Users (root)
    # @return [Array] user list
    def Users
      ks_user = Ops.get_map(@ksConfig, "users", {})
      users = []
      root = {}
      Ops.set(root, "username", "root")
      Ops.set(root, "user_password", Ops.get_string(ks_user, "password", ""))
      Ops.set(root, "encrypted", Ops.get_integer(ks_user, "iscrypted", 0) == 1)

      users = Builtins.add(users, root)
      deep_copy(users)
    end

    # X11
    # Read KS X11
    # @return [Hash] x11 configuration
    def X11
      if Ops.get_integer(@ksConfig, "skipx", 0) != 1 &&
          Builtins.haskey(@ksConfig, "xconfig")
        x11 = {}
        ks_x = Ops.get_map(@ksConfig, "xconfig", {})

        if Builtins.haskey(ks_x, "depth")
          Ops.set(x11, "color_depth", Ops.get_integer(ks_x, "depth", 0))
        end

        if Builtins.haskey(ks_x, "resolution")
          Ops.set(x11, "resolution", Ops.get_string(ks_x, "resolution", ""))
        end

        if Builtins.haskey(ks_x, "startxonboot")
          Ops.set(x11, "startxonboot", Ops.get_string(ks_x, "startxonboot", ""))
        end

        if Builtins.haskey(ks_x, "defaultdesktop")
          Ops.set(
            x11,
            "default_desktop",
            Ops.get_string(ks_x, "defaultdesktop", "")
          )
        end

        monitor = {}
        if Builtins.haskey(ks_x, "vsync") ||
            Ops.get_string(ks_x, "monitor", "") != ""
          display = {}
          hsync = Builtins.splitstring(Ops.get_string(ks_x, "hsync", ""), "-")
          vsync = Builtins.splitstring(Ops.get_string(ks_x, "vsync", ""), "-")
          Ops.set(display, "min_hsync", Ops.get_string(hsync, 0, ""))
          Ops.set(display, "min_vsync", Ops.get_string(vsync, 0, ""))
          Ops.set(display, "max_hsync", Ops.get_string(hsync, 1, ""))
          Ops.set(display, "max_vsync", Ops.get_string(vsync, 1, ""))
          m = Builtins.splitstring(Ops.get_string(ks_x, "monitor", ""), " ")
          Ops.set(monitor, "monitor_vendor", Ops.get(m, 0, ""))
          Ops.set(monitor, "monitor_device", Ops.get(m, 1, ""))
          Ops.set(monitor, "display", display)
        end
        if Ops.greater_than(Builtins.size(monitor), 0)
          Ops.set(x11, "monitor", monitor)
        end
        Ops.set(x11, "configure_x11", true)
        return deep_copy(x11)
      else
        return {}
      end
    end

    # KS General
    # @return [Hash] general configuration
    def General
      general = {}

      # Language
      Ops.set(general, "language", Ops.get_string(@ksConfig, "language", ""))

      # Keyboard
      keyboard = {}
      if Builtins.haskey(@ksConfig, "keyboard")
        Yast.import "Keyboard"
        keyboards = Keyboard.keymap2yast
        Ops.set(
          keyboard,
          "keymap",
          Ops.get_string(
            keyboards,
            Ops.get_string(@ksConfig, "keyboard", ""),
            ""
          )
        )
      end

      Ops.set(general, "keyboard", keyboard)

      # Clock
      clock = {}
      if Builtins.haskey(@ksConfig, "timezone")
        ks_clock = Ops.get_map(@ksConfig, "timezone", {})
        Ops.set(clock, "timezone", Ops.get_string(ks_clock, "timezone", ""))
        Ops.set(
          clock,
          "hwclock",
          Ops.get_string(ks_clock, "utc", "") == "1" ? "GMT" : "localtime"
        )
      end
      Ops.set(general, "clock", clock)


      # Mode
      mode = {}
      Ops.set(
        mode,
        "confirm",
        Ops.get_integer(@ksConfig, "interactive", 0) == 1
      )
      Ops.set(general, "mode", mode)


      deep_copy(general)
    end

    # KS Scripts
    # @return [Hash]
    def Scripts
      scripts = {}
      postscripts = []
      prescripts = []

      if Builtins.haskey(@ksConfig, "post-script")
        script = {}
        Ops.set(
          script,
          "source",
          Convert.to_string(
            SCR.Read(
              path(".target.string"),
              Ops.get_string(@ksConfig, "post-script", "")
            )
          )
        )
        post = Ops.get_map(@ksConfig, "post", {})
        Ops.set(
          script,
          "interpreter",
          Ops.get_string(post, "interpreter", "shell")
        )
        Ops.set(script, "filename", "kspost")
        postscripts = Builtins.add(postscripts, script)
      end
      Ops.set(scripts, "post-scripts", postscripts)
      if Builtins.haskey(@ksConfig, "pre-script")
        script = {}
        Ops.set(
          script,
          "source",
          Convert.to_string(
            SCR.Read(
              path(".target.string"),
              Ops.get_string(@ksConfig, "pre-script", "")
            )
          )
        )

        Ops.set(script, "interpreter", "/bin/sh")
        Ops.set(script, "filename", "kspre")
        prescripts = Builtins.add(prescripts, script)
      end
      Ops.set(scripts, "pre-scripts", prescripts)
      deep_copy(scripts)
    end




    # KS Partitioning
    # @return [Array]
    def Partitioning
      Builtins.y2milestone(
        "KS Partitioning: %1",
        Ops.get_map(@ksConfig, "partitioning", {})
      )
      Yast.import "Partitions"

      drives = []
      part1 = Builtins.maplist(Ops.get_map(@ksConfig, "partitioning", {})) do |k, v|
        drive = {}
        if Builtins.haskey(v, "ondisk")
          Ops.set(
            drive,
            "device",
            Builtins.sformat("/dev/%1", Ops.get_string(v, "ondisk", ""))
          )
        end
        Ops.set(drive, "partitions", [])
        drives = Builtins.add(drives, drive)
      end

      # sort and make unique entries
      drives = Builtins.toset(drives)
      Builtins.y2debug("Drives: %1", drives)
      Builtins.foreach(Ops.get_map(@ksConfig, "partitioning", {})) do |k, v|
        partition = {}
        mountlist = Builtins.splitstring(k, "_")
        mount = Ops.get_string(mountlist, 0, "/data")
        order = Builtins.tointeger(Ops.get_string(mountlist, 1, "0"))
        fstype = mount == "swap" ? "swap" : Ops.get_string(v, "fstype", "")
        partition_id = Partitions.fsid_native
        raiddevice = 0
        if Builtins.regexpmatch(mount, "^raid..*")
          Builtins.y2milestone("device: %1", mount)
          partition_id = Partitions.fsid_raid
          Ops.set(partition, "partition_id", partition_id)
          raiddevice = Builtins.tointeger(Builtins.substring(mount, 5, 1))

          Ops.set(
            partition,
            "raid_name",
            Builtins.sformat("/dev/md%1", raiddevice)
          )
          Ops.set(partition, "format", false)
        else
          Ops.set(partition, "mount", mount)
          Ops.set(partition, "order", order)
          Ops.set(partition, "format", Ops.get_string(v, "noformat", "") == "")
          Ops.set(partition, "filesystem", FileSystems.FsToSymbol(fstype))
        end
        Ops.set(
          partition,
          "size",
          Builtins.sformat("%1mb", Ops.get_string(v, "size", ""))
        )
        # Remove those later
        if Ops.get_string(v, "maxsize", "") != ""
          Ops.set(
            partition,
            "maxsize",
            Builtins.sformat("%1mb", Ops.get_string(v, "maxsize", ""))
          )
        end
        Ops.set(partition, "grow", true) if Ops.get_string(v, "grow", "") == "1"
        drives = Builtins.maplist(drives) do |d|
          dev = Builtins.sformat("/dev/%1", Ops.get_string(v, "ondisk", ""))
          if dev == Ops.get_string(d, "device", "")
            part = Ops.get_list(d, "partitions", [])
            part = Builtins.add(part, partition)
            Ops.set(d, "partitions", Builtins.sort(part) do |x, y|
              Ops.less_than(
                Ops.get_integer(x, "order", -1),
                Ops.get_integer(y, "order", -1)
              )
            end)
          elsif Ops.get_string(d, "device", "") == ""
            part = Ops.get_list(d, "partitions", [])
            part = Builtins.add(part, partition)
            Ops.set(d, "partitions", Builtins.sort(part) do |x, y|
              Ops.less_than(
                Ops.get_integer(x, "order", -1),
                Ops.get_integer(y, "order", -1)
              )
            end)
          end
          Builtins.y2milestone("KS Drive: %1", d)
          deep_copy(d)
        end
      end

      newdrives = Builtins.maplist(drives) do |drive|
        numpart = Builtins.size(Ops.get_list(drive, "partitions", []))
        Builtins.y2milestone("partitions count: %1", numpart)
        ismax = false
        # clean up
        dp = Builtins.maplist(Ops.get_list(drive, "partitions", [])) do |p|
          p = Builtins.remove(p, "order")
          deep_copy(p)
        end
        clearpart = Ops.get_map(@ksConfig, "clearpart", {})
        d = Builtins.splitstring(Ops.get_string(drive, "device", ""), "/")
        devicetok = Ops.get(d, 1, "")
        if devicetok != "" && Ops.get_string(clearpart, "drives", "") != ""
          if Builtins.issubstring(
              Ops.get_string(clearpart, "drives", ""),
              devicetok
            )
            if Ops.get_integer(clearpart, "all", -1) == 1
              Ops.set(drive, "use", "all")
            elsif Ops.get_integer(clearpart, "linux", -1) == 1
              Ops.set(drive, "use", "linux")
            elsif Ops.get_integer(clearpart, "initlabel", -1) == 1
              Ops.set(drive, "initialize", true)
            end
          end
        elsif Ops.get_string(clearpart, "drives", "") == ""
          if Ops.get_integer(clearpart, "all", -1) == 1
            Ops.set(drive, "use", "all")
          elsif Ops.get_integer(clearpart, "linux", -1) == 1
            Ops.set(drive, "use", "linux")
          elsif Ops.get_integer(clearpart, "initlabel", -1) == 1
            Ops.set(drive, "initialize", true)
          end
        elsif devicetok == "" && Ops.get_string(clearpart, "drives", "") != ""
          alldrives = Builtins.splitstring(
            Ops.get_string(clearpart, "drives", ""),
            ","
          )
          if Builtins.size(alldrives) == 1
            Ops.set(
              drive,
              "device",
              Builtins.sformat("/dev/%1", Ops.get_string(alldrives, 0, ""))
            )
            if Ops.get_string(clearpart, "all", "") == "1"
              Ops.set(drive, "use", "all")
            elsif Ops.get_string(clearpart, "linux", "") == "1"
              Ops.set(drive, "use", "linux")
            elsif Ops.get_string(clearpart, "initlabel", "") == "1"
              Ops.set(drive, "initialize", true)
            end
          end
        end
        Ops.set(drive, "partitions", dp)
        deep_copy(drive)
      end
      Builtins.y2milestone("Drives: %1", newdrives)
      deep_copy(newdrives)
    end

    # KS RAID
    # @return [Array]
    def Raid
      raid = Builtins.maplist(Ops.get_map(@ksConfig, "raid", {})) do |d, data|
        r = {}
        Ops.set(r, "mount", d)
        Ops.set(
          r,
          "format",
          Ops.get_integer(data, "nofromat", 0) == 1 ? false : true
        )
        Ops.set(
          r,
          "name",
          Builtins.sformat("/dev/%1", Ops.get_string(data, "device", "md0"))
        )
        Ops.set(
          r,
          "raid_level",
          Builtins.sformat("raid%1", Ops.get_integer(data, "level", 0))
        )
        deep_copy(r)
      end
      deep_copy(raid)
    end


    # KS Network
    # @return [Array]
    def Network
      Yast.import "IP"
      init = {}
      networking = {}
      dns = {}

      nameserver = []
      gateway = ""

      routing = {}
      rawNet = Ops.get_map(@ksConfig, "networking", {})
      interfaces = Builtins.maplist(rawNet) do |iface, data|
        interface = {}
        if Ops.get_string(data, "bootproto", "") == "dhcp"
          Ops.set(interface, "bootproto", "dhcp")
          Ops.set(interface, "device", iface)
          Ops.set(interface, "startmode", "onboot")
          Ops.set(init, "usedhcp", true)
        else
          Ops.set(interface, "device", iface)
          Ops.set(interface, "bootproto", "static")
          Ops.set(
            interface,
            "network",
            IP.ComputeNetwork(
              Ops.get_string(data, "ip", ""),
              Ops.get_string(data, "netmask", "")
            )
          )
          Ops.set(interface, "ipaddr", Ops.get_string(data, "ip", ""))
          Ops.set(interface, "netmask", Ops.get_string(data, "netmask", ""))
          Ops.set(interface, "startmode", "onboot")
          Ops.set(
            interface,
            "broadcast",
            IP.ComputeBroadcast(
              Ops.get_string(data, "ip", ""),
              Ops.get_string(data, "netmask", "")
            )
          )

          Ops.set(init, "ip", Ops.get_string(data, "ip", ""))
          Ops.set(init, "nameserver", Ops.get_string(data, "nameserver", ""))
          Ops.set(init, "netmask", Ops.get_string(data, "netmask", ""))
          Ops.set(init, "gateway", Ops.get_string(data, "gateway", ""))
          Ops.set(init, "netdevice", Ops.get_string(data, "device", ""))
          nameserver = [Ops.get_string(data, "nameserver", "")]
          gateway = Ops.get_string(data, "gateway", "")
        end
        deep_copy(interface)
      end

      searchlist = []

      hostname = ""
      domain = ""

      Ops.set(dns, "hostname", hostname)
      Ops.set(dns, "domain", domain)
      Ops.set(dns, "searchlist", searchlist)
      Ops.set(dns, "nameservers", nameserver)

      routes = []
      route = {}

      if gateway != ""
        Ops.set(route, "destination", "default")
        Ops.set(route, "device", "-")
        Ops.set(route, "gateway", gateway)
        Ops.set(route, "netmask", "-")
        routes = Builtins.add(routes, route)
      end
      routing = Builtins.add(routing, "routes", routes)
      routing = Builtins.add(routing, "ip_forwarding", false)

      Ops.set(networking, "interfaces", interfaces)
      Ops.set(networking, "dns", dns)
      Ops.set(networking, "routing", routing)


      # init
      if Builtins.haskey(@ksConfig, "nfs")
        nfs = Ops.get_map(@ksConfig, "nfs", {})
        Ops.set(init, "instmode", "nfs")
        Ops.set(init, "server", Ops.get_string(nfs, "server", ""))
        Ops.set(init, "serverdir", Ops.get_string(nfs, "dir", ""))
      end

      if Ops.get_integer(@ksConfig, "textmode", 0) == 1
        Ops.set(init, "textmode", true)
      end

      [networking, init]
    end


    # KS Authentication
    # @return [Array]
    def Authentication
      auth = Ops.get_map(@ksConfig, "auth", {})

      # NIS
      nis = {}
      security = {}
      ldap = {}


      if Ops.get_integer(auth, "enablenis", 0) == 1
        Ops.set(nis, "start_nis", true)
        if Builtins.haskey(auth, "nisdomain")
          Ops.set(nis, "nis_domain", Ops.get_string(auth, "nisdomain", ""))
        end
        if Builtins.haskey(auth, "nisserver")
          nisserver = [Ops.get_string(auth, "nisserver", "")]
          Ops.set(nis, "nis_servers", nisserver)
        end
      end

      if Ops.get_string(auth, "enablemd5", "0") == "1"
        Ops.set(security, "encryption", "md5")
      end


      if Ops.get_string(auth, "enableldapauth", "0") == "1"
        Ops.set(ldap, "start_ldap", true)
        if Builtins.haskey(auth, "nisdomain")
          Ops.set(ldap, "ldap_domain", Ops.get_string(auth, "ldapbasedn", ""))
        end
        if Builtins.haskey(auth, "ldapserver")
          Ops.set(ldap, "ldap_server", Ops.get_string(auth, "ldapserver", ""))
        end
        if Ops.get_integer(auth, "enableldaptls", 0) == 1
          Ops.set(ldap, "ldap_tls", true)
        end
      end

      [nis, ldap, security]
    end

    # KS Bootloader
    # @return [Hash]
    def Bootloader
      bl = Ops.get_map(@ksConfig, "bootloader", {})
      bootloader = {}
      if Ops.get_string(bl, "location", "") != "none"
        Ops.set(bootloader, "location", Ops.get_string(bl, "location", ""))
      else
        Ops.set(bootloader, "write_bootloader", false)
      end

      Ops.set(bootloader, "kernel_parameters", Ops.get_string(bl, "append", ""))
      if Builtins.haskey(bl, "linear") || Builtins.haskey(bl, "nolinear")
        Ops.set(
          bootloader,
          "linear",
          Ops.get_integer(bl, "linear", 0) == 1 ||
            Ops.get_integer(bl, "nolinear", 0) != 1
        )
      end
      # FIXME
      Ops.set(bootloader, "lba_support", Ops.get_integer(bl, "lba32", 0) == 1)
      deep_copy(bootloader)
    end



    # KS Software
    # @return [Hash]
    def Software
      software = {}
      all = Ops.get_list(@ksConfig, "packages", [])


      rhsel = {
        "Core"                      => { "base" => "Minimal", "addon" => [] },
        "Base"                      => { "base" => "Minimal", "addon" => [] },
        "Printing Support"          => {
          "base"     => "Minimal",
          "addon"    => [],
          "packages" => [
            "a2ps",
            "ghostscript-mini",
            "hp-officeJet",
            "yast2-printer",
            "cups-client",
            "cups",
            "cups-libs",
            "cups-drivers"
          ]
        },
        "Cups"                      => {
          "base"     => "Minimal",
          "addon"    => [],
          "packages" => ["cups-client", "cups", "cups-libs", "cups-drivers"]
        },
        "X Window System"           => {
          "base"     => "Minimal+X11",
          "addon"    => [],
          "packages" => []
        },
        "Dialup Networking Support" => {
          "base"     => "Minimal",
          "addon"    => [],
          "packages" => [
            "ppp",
            "minicom",
            "wvdial",
            "i4l-base",
            "i4lfirm",
            "i4l-isdnlog"
          ]
        },
        "GNOME Desktop Environment" => {
          "base"     => "Minimal+X11",
          "addon"    => ["Gnome"],
          "packages" => []
        },
        "KDE Desktop Environment"   => {
          "base"     => "Minimal+X11",
          "addon"    => ["Kde-Desktop"],
          "packages" => []
        },
        "Graphical Internet"        => {
          "base"     => "Minimal+X11",
          "addon"    => ["Network"],
          "packages" => []
        },
        "Text-based Internet"       => {
          "base"     => "Minimal",
          "addon"    => ["Network"],
          "packages" => []
        },
        "Sound and Video"           => {
          "base"     => "Minimal+X11",
          "addon"    => ["Multimedia", "Basis-Sound"],
          "packages" => []
        },
        "Graphics"                  => {
          "base"     => "Minimal+X11",
          "addon"    => [],
          "packages" => [
            "ImageMagick",
            "xsane",
            "gimp",
            "netpbm",
            "dia",
            "gtkam"
          ]
        },
        "Office/Productivity"       => {
          "base"     => "Minimal+X11",
          "addon"    => ["Office"],
          "packages" => []
        },
        "Mail Server"               => {
          "base"     => "Minimal",
          "addon"    => [
            "postfix",
            "imap",
            "mailman",
            "spamassassin",
            "squirrelmail",
            "squirrelmail-plugins"
          ],
          "packages" => []
        },
        "Network Servers"           => {
          "base"     => "Minimal",
          "addon"    => ["Network"],
          "packages" => []
        },
        "News Server"               => {
          "base"     => "Minimal",
          "addon"    => ["Network"],
          "packages" => []
        },
        "Windows File Server"       => {
          "base"     => "Minimal",
          "addon"    => ["Network"],
          "packages" => []
        },
        "Web Server"                => {
          "base"     => "Minimal",
          "addon"    => ["LAMP"],
          "packages" => []
        },
        "Games and Entertainment"   => {
          "base"     => "Minimal",
          "addon"    => ["Games"],
          "packages" => []
        },
        "Development Tools"         => {
          "base"     => "Minimal",
          "addon"    => ["Basis-Devel"],
          "packages" => []
        },
        "Development Libraries"     => {
          "base"     => "Minimal",
          "addon"    => ["Advanced-Devel"],
          "packages" => []
        }
      }

      selections = Builtins.maplist(Builtins.filter(all) do |s|
        Builtins.issubstring(s, "@")
      end) do |s|
        sel1 = Builtins.substring(s, 1, Builtins.size(s))
        sel2 = Builtins.substring(
          sel1,
          Builtins.findfirstof(
            Builtins.tolower(sel1),
            "0123456789abcdefghijklmnopqrstuvwxyz"
          ),
          Builtins.size(sel1)
        )
        sel2
      end

      Builtins.y2milestone("RH Selections: %1", selections)
      bases = []
      addons = []
      selpacs = []
      Builtins.foreach(selections) do |sel|
        currentsel = Ops.get(rhsel, sel, {})
        Builtins.y2milestone("current sel: %1", currentsel)
        bases = Builtins.add(bases, Ops.get_string(currentsel, "base", ""))
        addons = Builtins.toset(
          Builtins.union(addons, Ops.get_list(currentsel, "addon", []))
        )
        selpacs = Builtins.toset(
          Builtins.union(selpacs, Ops.get_list(currentsel, "packages", []))
        )
      end

      Builtins.y2milestone(
        "bases: %1, addons: %2. pacakges: %3",
        bases,
        addons,
        selpacs
      )

      packages = Builtins.filter(all) { |s| !Builtins.issubstring(s, "@") }
      packages = Builtins.filter(packages) do |s|
        !Builtins.regexpmatch(s, "^-.*")
      end

      nopackages = Builtins.maplist(Builtins.filter(all) do |s|
        Builtins.regexpmatch(s, "^-.*")
      end) { |pac| Builtins.substring(pac, 1, Builtins.size(pac)) }

      Ops.set(software, "base", "Minimal")
      Ops.set(software, "addons", addons)
      Ops.set(
        software,
        "packages",
        Builtins.toset(Builtins.union(Builtins.filter(packages) { |pac| pac != "" }, selpacs))
      )
      Ops.set(software, "remove-packages", Builtins.filter(nopackages) do |pac|
        pac != ""
      end)


      deep_copy(software)
    end

    # Kickstart to AutoYaST main
    # @return [Hash]
    def KS2AY
      profile = {}

      # Scripts
      Ops.set(profile, "scripts", Scripts())
      Ops.set(profile, "networking", Ops.get_map(Network(), 0, {}))
      Ops.set(profile, "nis", Ops.get_map(Authentication(), 0, {}))
      Ops.set(profile, "ldap", Ops.get_map(Authentication(), 1, {}))
      Ops.set(profile, "security", Ops.get_map(Authentication(), 2, {}))
      Ops.set(profile, "users", Users())

      Ops.set(profile, "init", Ops.get_map(Network(), 1, {}))
      Ops.set(profile, "software", Software())
      Ops.set(profile, "partitioning", Partitioning())
      Ops.set(profile, "raid", Raid())
      Ops.set(profile, "bootloader", Bootloader())
      Ops.set(profile, "general", General())

      Profile.changed = true

      Builtins.y2debug("Profile : %1", profile)
      deep_copy(profile)
    end

    publish :variable => :ksfile, :type => "string"
    publish :function => :Kickstart, :type => "void ()"
    publish :function => :Read, :type => "map ()"
    publish :function => :KS2AY, :type => "map <string, any> ()"
  end

  Kickstart = KickstartClass.new
  Kickstart.main
end
