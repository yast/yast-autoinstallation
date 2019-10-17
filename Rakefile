require "yast/rake"

AUTOINST_DIR = Packaging::Configuration::DESTDIR + "/usr/share/autoinstall/"

Yast::Tasks.configuration do |conf|
  #lets ignore license check for now
  conf.skip_license_check << /.*/
  conf.install_locations["scripts/*.service"] =
    Packaging::Configuration::DESTDIR + "/usr/lib/systemd/system/"
  conf.install_locations["xslt/*.xslt"] = AUTOINST_DIR + "/xslt/"
  conf.install_locations["modconfig/*.desktop"] = AUTOINST_DIR + "/modules/"
  conf.install_locations["control/*.xml"] = Packaging::Configuration::YAST_DIR + "/control/"
end

# define additional creation of directories during installation
task :install do
  sh "/usr/bin/install -d -m 700 #{Packaging::Configuration::DESTDIR}/etc/autoinstall"
  sh "/usr/bin/install -d -m 700 #{Packaging::Configuration::DESTDIR}/var/adm/autoinstall/scripts"
  sh "/usr/bin/install -d -m 700 #{Packaging::Configuration::DESTDIR}/var/adm/autoinstall/init.d"
  sh "/usr/bin/install -d -m 700 #{Packaging::Configuration::DESTDIR}/var/adm/autoinstall/logs"
  sh "/usr/bin/install -d -m 700 #{Packaging::Configuration::DESTDIR}/var/adm/autoinstall/files"
  sh "/usr/bin/install -d -m 700 #{Packaging::Configuration::DESTDIR}/var/adm/autoinstall/cache"
  sh "/usr/bin/install -d -m 700 #{Packaging::Configuration::DESTDIR}/var/lib/autoinstall/repository/templates"
  sh "/usr/bin/install -d -m 700 #{Packaging::Configuration::DESTDIR}/var/lib/autoinstall/repository/rules"
  sh "/usr/bin/install -d -m 700 #{Packaging::Configuration::DESTDIR}/var/lib/autoinstall/repository/classes"
  sh "/usr/bin/install -d -m 700 #{Packaging::Configuration::DESTDIR}/var/lib/autoinstall/autoconf"
  sh "/usr/bin/install -d -m 700 #{Packaging::Configuration::DESTDIR}/var/lib/autoinstall/tmp"
end
