# Sources for autoinstallation

module_DATA = \
  modules/AutoinstStorage.rb \
  modules/AutoinstPartPlan.rb \
  modules/AutoInstallRules.rb \
  modules/Kickstart.rb \
  modules/Y2ModuleConfig.rb \
  modules/ProfileLocation.rb \
  modules/AutoinstPartition.rb \
  modules/AutoinstClone.rb \
  modules/AutoinstImage.rb \
  modules/AutoinstConfig.rb \
  modules/Profile.rb \
  modules/AutoinstCommon.rb \
  modules/AutoinstFile.rb \
  modules/AutoinstScripts.rb \
  modules/AutoInstall.rb \
  modules/AutoinstGeneral.rb \
  modules/AutoinstSoftware.rb \
  modules/AutoinstDrive.rb \
  modules/AutoinstClass.rb \
  modules/AutoinstFunctions.rb

client_DATA = \
  clients/classes_auto.rb \
  clients/ayast_setup.rb \
  clients/scripts_auto.rb \
  clients/software_auto.rb \
  clients/general_auto.rb \
  clients/inst_autopost.rb \
  clients/storage_auto.rb \
  clients/ayast_probe.rb \
  clients/inst_autoconfigure.rb \
  clients/inst_autosetup_upgrade.rb \
  clients/autoinst_scripts2_finish.rb \
  clients/inst_autosetup.rb \
  clients/inst_autoinit.rb \
  clients/report_auto.rb \
  clients/autoinst_scripts1_finish.rb \
  clients/inst_autoimage.rb \
  clients/inst_store_upgrade_software.rb \
  clients/files_auto.rb \
  clients/autoinst_test_clone.rb \
  clients/autoyast.rb \
  clients/clone_system.rb \
  clients/autoinst_test_stage.rb

yncludedir = @yncludedir@/autoinstall
ynclude_DATA = \
  include/autoinstall/DriveDialog.rb \
  include/autoinstall/io.rb \
  include/autoinstall/wizards.rb \
  include/autoinstall/autoinst_dialogs.rb \
  include/autoinstall/classes.rb \
  include/autoinstall/types.rb \
  include/autoinstall/PartitionDialog.rb \
  include/autoinstall/StorageDialog.rb \
  include/autoinstall/tree.rb \
  include/autoinstall/common.rb \
  include/autoinstall/autopart.rb \
  include/autoinstall/dialogs.rb \
  include/autoinstall/AdvancedPartitionDialog.rb \
  include/autoinstall/ask.rb \
  include/autoinstall/VolgroupDialog.rb \
  include/autoinstall/xml.rb \
  include/autoinstall/script_dialogs.rb \
  include/autoinstall/conftree.rb \
  include/autoinstall/helps.rb \
  include/autoinstall/general_dialogs.rb

ylibdir = @ylibdir@/autoinstall
ylib_DATA = \
  lib/autoinstall/module_config_builder.rb \
  lib/autoinstall/pkg_gpg_check_handler.rb \
  lib/autoinstall/storage_proposal.rb

scrconf_DATA = \
  scrconf/cfg_autoinstall.scr \
  scrconf/autoinstall.scr \
  scrconf/ksimport.scr

agent_SCRIPTS = \
  servers_non_y2/ag_ksimport

schemafilesdir = $(schemadir)/autoyast/rnc
schemafiles_DATA = \
  autoyast-rnc/scripts.rnc \
  autoyast-rnc/rules.rnc \
  autoyast-rnc/common.rnc \
  autoyast-rnc/pxe.rnc \
  autoyast-rnc/classes-use.rnc \
  autoyast-rnc/classes-decl.rnc \
  autoyast-rnc/software.rnc \
  autoyast-rnc/reporting.rnc \
  autoyast-rnc/partitioning.rnc \
  autoyast-rnc/profile-misc.rnc \
  autoyast-rnc/general.rnc \
  autoyast-rnc/files.rnc

ybin_SCRIPTS = \
  bin/autoyast-initscripts.sh \
  bin/fetch_image.sh

desktop_DATA = \
  desktop/autoyast.desktop \
  desktop/clone_system.desktop

fillup_DATA = \
  fillup/sysconfig.autoinstall

EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(scrconf_DATA) $(agent_SCRIPTS) $(schemafiles_DATA) $(ybin_SCRIPTS) $(desktop_DATA) $(fillup_DATA) $(ylib_DATA)

include $(top_srcdir)/Makefile.am.common
