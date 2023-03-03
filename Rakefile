require "yast/rake"

Yast::Tasks.submit_to :sle15sp5

AUTOINST_DIR = Packaging::Configuration::DESTDIR + "/usr/share/autoinstall/"

Yast::Tasks.configuration do |conf|
  # lets ignore license check for now
  conf.skip_license_check << /.*/
  conf.install_locations["scripts/*.service"] =
    Packaging::Configuration::DESTDIR + "/usr/lib/systemd/system/"
  conf.install_locations["xslt/*.xslt"] = AUTOINST_DIR + "/xslt/"
  conf.install_locations["modconfig/*.desktop"] = AUTOINST_DIR + "/modules/"
  conf.install_locations["control/*.xml"] = Packaging::Configuration::YAST_DIR + "/control/"
end

def make_dir(dir)
  sh "/usr/bin/install -d -m 700 #{Packaging::Configuration::DESTDIR}/#{dir}"
end

# define additional creation of directories during installation
task :install do
  make_dir "/etc/autoinstall"
  make_dir "/var/adm/autoinstall/scripts"
  make_dir "/var/adm/autoinstall/init.d"
  make_dir "/var/adm/autoinstall/logs"
  make_dir "/var/adm/autoinstall/files"
  make_dir "/var/adm/autoinstall/cache"
  make_dir "/var/lib/autoinstall/repository/templates"
  make_dir "/var/lib/autoinstall/repository/rules"
  make_dir "/var/lib/autoinstall/repository/classes"
  make_dir "/var/lib/autoinstall/autoconf"
  make_dir "/var/lib/autoinstall/tmp"
  # remove git only readme
  sh "rm #{Packaging::Configuration::YAST_DIR}/schema/autoyast/rnc/README.md"
end
