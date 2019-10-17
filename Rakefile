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
