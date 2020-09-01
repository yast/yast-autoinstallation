# encoding: utf-8

# File:	include/autoinstall/xml.ycp
# Package:	Autoinstallation Configuration System
# Summary:	XML handling
# Authors:	Anas Nashif<nashif@suse.de>
#
# $Id$
module Yast
  module AutoinstallXmlInclude
    def initialize_autoinstall_xml(include_target)
      Yast.import "XML"
    end

    # Setup the profile tags
    # @return [void]
    def profileSetup
      doc = {}
      Ops.set(
        doc,
        "listEntries",
        {
          "users"                    => "user",
          "archives"                 => "archive",
          "schemes"                  => "schema",
          "fetchmail"                => "fetchmail_entry",
          "aliases"                  => "alias",
          "nfs_exports"              => "nfs_export",
          "allowed"                  => "allowed_clients",
          "classes"                  => "class",
          "denyusers"                => "denyuser",
          "allowusers"               => "allowuser",
          "modules"                  => "module_entry",
          "trusteddomains"           => "trusteddomain",
          "ppd_options"              => "ppd_option",
          "inetd_services"           => "inetd_service",
          "initrd_modules"           => "initrd_module",
          "nfs_entries"              => "nfs_entry",
          "ntp_servers"              => "ntp_server",
          "netd_conf"                => "conf",
          "raid"                     => "device",
          "hosts"                    => "hosts_entry",
          "names"                    => "name",
          "device_map"               => "device_map_entry",
          "device_map_entry"         => "device",
          "sections"                 => "section",
          "section"                  => "section_entry",
          "global"                   => "global_entry",
          "partitions"               => "partition",
          "partitioning"             => "drive",
          "selections"               => "selection",
          "nis_servers"              => "nis_server",
          "pre-scripts"              => "script",
          "post-scripts"             => "script",
          "chroot-scripts"           => "script",
          "init-scripts"             => "script",
          "postpartitioning-scripts" => "script",
          "local_domains"            => "domains",
          "masquerade_other_domains" => "domain",
          "masquerade_users"         => "masquerade_user",
          "virtual_users"            => "virtual_user",
          "services"                 => "service",
          # services-manager -> (hash) services -> (list) enable/disable -> service
          "enable"                   => "service",
          "disable"                  => "service",
          "modules_conf"             => "module_conf",
          "interfaces"               => "interface",
          "routes"                   => "route",
          "printers"                 => "printer",
          "sysconfig"                => "sysconfig_entry",
          "shares"                   => "share",
          "options"                  => "option",
          "addons"                   => "addon",
          "groups"                   => "group",
          "packages"                 => "package",
          "remove-packages"          => "package",
          "post-patterns"            => "pattern",
          "post-packages"            => "package",
          "searchlist"               => "search",
          "nameservers"              => "nameserver",
          "region"                   => "region_entry",
          "printcap"                 => "printcap_entry",
          "lvm"                      => "lvm_group",
          "logical_volumes"          => "lv",
          "volume_settings"          => "volume_entry",
          "volume_entry"             => "volume_component",
          "volume_component"         => "volume_component_settings",
          "settings"                 => "settings_entry",
          "allowed_interfaces"       => "allowed_interface",
          "children"                 => "child",
          "nis_other_domains"        => "nis_other_domain",
          "files"                    => "file",
          "securenets"               => "securenet",
          "maps_to_serve"            => "nis_map",
          "slaves"                   => "slave",
          "smtp_auth"                => "smtp_auth_entry",
          "patterns"                 => "pattern",
          "dont_merge"               => "element",
          "keys"                     => "keyid",
          "pathlist"                 => "path",
          "proposals"                => "proposal",
          "net-udev"                 => "rule",
          "ask-list"                 => "ask",
          "device_order"             => "device",
          "param-list"               => "param",
          "semi-automatic"           => "module",
          "ports"                    => "port",
          "sources"                  => "source",
          "zones"                    => "zone",
          "authorized_keys"          => "authorized_key",
          "products"                 => "product",
          "subvolumes"               => "subvolume"
        }
      )

      # media_url needed for ISO files on NFS
      Ops.set(
        doc,
        "cdataSections",
        [
          "source",
          "info_file",
          "file_contents",
          "pxelinux-config",
          "location",
          "script_source",
          "media_url",
          "subvolumes_prefix"
        ]
      )
      #            doc["systemID"] = "/usr/share/autoinstall/dtd/profile.dtd";
      Ops.set(doc, "rootElement", "profile")
      Ops.set(doc, "nameSpace", "http://www.suse.com/1.0/yast2ns")
      Ops.set(doc, "typeNamespace", "http://www.suse.com/1.0/configns")

      XML.xmlCreateDoc(:profile, doc)
      nil
    end

    # Setup XML for classes
    # @return void
    #
    def classSetup
      doc = {}
      Ops.set(doc, "listEntries", { "classes" => "class" })
      Ops.set(doc, "rootElement", "autoinstall")
      #            doc["systemID"] = "/usr/share/autoinstall/dtd/classes.dtd";
      Ops.set(doc, "nameSpace", "http://www.suse.com/1.0/yast2ns")
      Ops.set(doc, "typeNamespace", "http://www.suse.com/1.0/configns")
      XML.xmlCreateDoc(:class, doc)
      nil
    end
  end
end
