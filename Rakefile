require "yast/rake"

Yast::Tasks.configuration do |conf|
  #lets ignore license check for now
  conf.skip_license_check << /.*/

  # submit to CASP
  conf.obs_api = "https://api.suse.de/";
  conf.obs_project = "Devel:YaST:CASP:1.0"
  conf.obs_target = "CASP_1.0"
  conf.obs_sr_project = "Devel:CASP:1.0"
end
