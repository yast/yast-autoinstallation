#
# spec file for package autoyast2
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           autoyast2
Version:        3.3.0
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        autoyast2-%{version}.tar.bz2

Source1:        autoyast_en_html.tar.bz2
BuildRequires:  update-desktop-files
BuildRequires:  yast2-devtools >= 3.1.15
# control.rng
BuildRequires:  yast2-installation-control
# xmllint
BuildRequires:  libxml2-tools
# xsltproc for AutoinstClass
BuildRequires:  libxslt
BuildRequires:  rubygem(%{rb_default_ruby_abi}:rspec)
BuildRequires:  yast2
# FileSystems.read_default_subvol_from_target
BuildRequires:  yast2-xml
BuildRequires:  yast2-transfer
BuildRequires:  yast2-services-manager
BuildRequires:  yast2-packager
BuildRequires:  yast2-slp

# %%{_unitdir} macro definition is in a separate package since 13.1
%if 0%{?suse_version} >= 1310
BuildRequires:  systemd-rpm-macros
%else
BuildRequires:  systemd
%endif

Requires:       autoyast2-installation = %{version}
Requires:       libxslt
Requires:       yast2
Requires:       yast2 >= 3.1.183
Requires:       yast2-core
Requires:       yast2-country >= 3.1.13
Requires:       yast2-network >= 3.1.145
Requires:       yast2-schema
Requires:       yast2-transfer >= 2.21.0
Requires:       yast2-xml
Conflicts:      yast2-installation < 3.1.166

Provides:       yast2-config-autoinst
Provides:       yast2-module-autoinst
Obsoletes:      yast2-config-autoinst
Obsoletes:      yast2-module-autoinst
Provides:       yast2-lib-autoinst
Obsoletes:      yast2-lib-autoinst

PreReq:         %insserv_prereq %fillup_prereq

BuildArch:      noarch

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:        YaST2 - Automated Installation
License:        GPL-2.0
Group:          System/YaST

%description
This package is intended for management of the control files and the
AutoYaST2 configurations. This system should only be used by
experienced system administrators. Warning: AutoYaST2 performs the
installation without any user intervention, warnings, or confirmations
(unless specified otherwise in the control file).

This file contains YaST2-independent files needed to create
installation sources.

%package installation
Requires:       yast2-ruby-bindings >= 1.0.0

Summary:        YaST2 - Auto Installation Modules
Group:          System/YaST
# API for Disabled Modules (ProductControl)
Requires:       yast2 >= 2.16.36
# After API cleanup
Requires:       yast2
Requires:       yast2-bootloader
Requires:       yast2-core
Requires:       yast2-country
Requires:       yast2-ncurses
# Packages.default_patterns
Requires:       yast2-packager >= 3.1.10
# ServicesManagerTargetClass::BaseTargets
Requires:       yast2-services-manager >= 3.1.10
Requires:       yast2-slp
Requires:       yast2-transfer >= 2.21.0
Requires:       yast2-update >= 2.18.3
Requires:       yast2-xml
# pkgGpgCheck callback
Requires:       yast2-pkg-bindings >= 3.1.31
Provides:       yast2-trans-autoinst
Obsoletes:      yast2-trans-autoinst

%description installation
This package performs auto-installation relying on a control file
generated with the autoyast2 package.

%prep
%setup -n autoyast2-%{version}

%build
%yast_build

%install
%yast_install

# Do not *blindly* remove the suse_update_desktop_file calls here. It is
# different from the code in the yast_install macro.
for d in $RPM_BUILD_ROOT/usr/share/autoinstall/modules/*.desktop ; do
    %suse_update_desktop_file $d
done

# Class conf
install -d -m 700 $RPM_BUILD_ROOT/etc/autoinstall
# Installation files
install -d -m 700 $RPM_BUILD_ROOT/var/adm/autoinstall/scripts
install -d -m 700 $RPM_BUILD_ROOT/var/adm/autoinstall/init.d
install -d -m 700 $RPM_BUILD_ROOT/var/adm/autoinstall/logs
install -d -m 700 $RPM_BUILD_ROOT/var/adm/autoinstall/files
install -d -m 700 $RPM_BUILD_ROOT/var/adm/autoinstall/cache

# Repository
install -d $RPM_BUILD_ROOT/var/lib/autoinstall/repository
install -d $RPM_BUILD_ROOT/var/lib/autoinstall/repository/templates
install -d $RPM_BUILD_ROOT/var/lib/autoinstall/repository/rules
install -d $RPM_BUILD_ROOT/var/lib/autoinstall/repository/classes
install -d $RPM_BUILD_ROOT/var/lib/autoinstall/autoconf
install -d $RPM_BUILD_ROOT/var/lib/autoinstall/tmp

# Systemd Stuff
mkdir -p $RPM_BUILD_ROOT/%{_unitdir}/
install -m 644 scripts/autoyast-initscripts.service $RPM_BUILD_ROOT/%{_unitdir}/

# Documentation
install -d -m 755 $RPM_BUILD_ROOT/%{_prefix}/share/doc/packages/autoyast2/html
tar xvpfC %{SOURCE1} $RPM_BUILD_ROOT/%{_prefix}/share/doc/packages/autoyast2/html
mv $RPM_BUILD_ROOT/%{_prefix}/share/doc/packages/autoyast2/html/autoyast/* $RPM_BUILD_ROOT/%{_prefix}/share/doc/packages/autoyast2/html/
rmdir $RPM_BUILD_ROOT/%{_prefix}/share/doc/packages/autoyast2/html/autoyast

%post
%{fillup_only -n autoinstall}

%files
%defattr(-,root,root)
%dir /etc/autoinstall
%dir %{yast_yncludedir}/autoinstall
%dir /var/lib/autoinstall/repository
%dir /var/lib/autoinstall/repository/templates
%dir /var/lib/autoinstall/repository/rules
%dir /var/lib/autoinstall/repository/classes
%dir /var/lib/autoinstall/tmp
%doc %{_prefix}/share/doc/packages/autoyast2

%dir %yast_desktopdir
%{yast_desktopdir}/autoyast.desktop
%{yast_desktopdir}/clone_system.desktop
/usr/share/autoinstall/modules/*.desktop
%dir %{yast_yncludedir}
%{yast_yncludedir}/autoinstall/classes.rb
%{yast_yncludedir}/autoinstall/conftree.rb
%{yast_yncludedir}/autoinstall/dialogs.rb
%{yast_yncludedir}/autoinstall/script_dialogs.rb
%{yast_yncludedir}/autoinstall/general_dialogs.rb
%{yast_yncludedir}/autoinstall/wizards.rb
%{yast_yncludedir}/autoinstall/helps.rb
%dir %{yast_schemadir}
%dir %{yast_schemadir}/autoyast
%dir %{yast_schemadir}/autoyast/rnc
%{yast_schemadir}/autoyast/rnc/*.rnc

%dir %{yast_clientdir}
%{yast_clientdir}/general_auto.rb
%{yast_clientdir}/report_auto.rb
%{yast_clientdir}/classes_auto.rb
%{yast_clientdir}/scripts_auto.rb
%{yast_clientdir}/software_auto.rb
%{yast_clientdir}/storage_auto.rb
%{yast_clientdir}/autoyast.rb
%{yast_clientdir}/ayast_setup.rb

%dir %{yast_scrconfdir}
%{yast_scrconfdir}/ksimport.scr

%dir %{yast_moduledir}
%{yast_moduledir}/AutoinstClass.rb
%{yast_moduledir}/Kickstart.rb
%dir %{yast_agentdir}
%{yast_agentdir}/ag_ksimport

# additional files

/var/adm/fillup-templates/sysconfig.autoinstall

%files installation
%defattr(-,root,root)
%dir %{yast_scrconfdir}
%{yast_scrconfdir}/autoinstall.scr
%{yast_scrconfdir}/cfg_autoinstall.scr
# DTD files
%dir /usr/share/autoinstall
#%dir /usr/share/autoinstall/dtd
%dir /usr/share/autoinstall/modules
#/usr/share/autoinstall/dtd/*

# systemd service file
%{_unitdir}/autoyast-initscripts.service

%dir /usr/share/autoinstall/xslt
/usr/share/autoinstall/xslt/merge.xslt
# config file

%dir %{yast_moduledir}
%{yast_moduledir}/AutoinstClone.rb
%dir %{yast_yncludedir}/autoinstall
%{yast_yncludedir}/autoinstall/autopart.rb
%{yast_yncludedir}/autoinstall/io.rb
%{yast_yncludedir}/autoinstall/autoinst_dialogs.rb
%{yast_yncludedir}/autoinstall/AdvancedPartitionDialog.rb
%{yast_yncludedir}/autoinstall/DriveDialog.rb
%{yast_yncludedir}/autoinstall/PartitionDialog.rb
%{yast_yncludedir}/autoinstall/StorageDialog.rb
%{yast_yncludedir}/autoinstall/VolgroupDialog.rb
%{yast_yncludedir}/autoinstall/common.rb
%{yast_yncludedir}/autoinstall/tree.rb
%{yast_yncludedir}/autoinstall/types.rb

%dir %{yast_controldir}
%{yast_controldir}/*.xml

%{yast_moduledir}/AutoInstall.rb
%{yast_moduledir}/AutoinstScripts.rb
%{yast_moduledir}/AutoinstGeneral.rb
%{yast_moduledir}/AutoinstImage.rb
%{yast_moduledir}/Y2ModuleConfig.rb
%{yast_moduledir}/Profile.rb
%{yast_moduledir}/AutoinstFile.rb
%{yast_moduledir}/AutoinstConfig.rb
%{yast_moduledir}/AutoinstSoftware.rb
%{yast_moduledir}/AutoinstStorage.rb
%{yast_moduledir}/AutoInstallRules.rb
%{yast_moduledir}/ProfileLocation.rb
%{yast_moduledir}/AutoinstCommon.rb
%{yast_moduledir}/AutoinstDrive.rb
%{yast_moduledir}/AutoinstPartPlan.rb
%{yast_moduledir}/AutoinstPartition.rb
%{yast_moduledir}/AutoinstFunctions.rb

#clients
%{yast_clientdir}/inst_autoinit.rb
%{yast_clientdir}/inst_autoimage.rb
%{yast_clientdir}/inst_autosetup.rb
%{yast_clientdir}/inst_autoconfigure.rb
%{yast_clientdir}/inst_autopost.rb
%{yast_clientdir}/files_auto.rb
%{yast_clientdir}/autoinst_test_clone.rb
%{yast_clientdir}/autoinst_test_stage.rb
%{yast_clientdir}/autoinst_scripts1_finish.rb
%{yast_clientdir}/autoinst_scripts2_finish.rb
%{yast_clientdir}/ayast_probe.rb
%{yast_clientdir}/inst_autosetup_upgrade.rb
%{yast_clientdir}/inst_store_upgrade_software.rb
%{yast_clientdir}/clone_system.rb

%{yast_yncludedir}/autoinstall/xml.rb
%{yast_yncludedir}/autoinstall/ask.rb

%dir %{yast_libdir}/autoinstall
%{yast_libdir}/autoinstall/*.rb

# scripts
%{_prefix}/lib/YaST2/bin/fetch_image.sh
%{_prefix}/lib/YaST2/bin/autoyast-initscripts.sh

%dir /var/adm/autoinstall/
%dir /var/adm/autoinstall/scripts
%dir /var/adm/autoinstall/init.d
%dir /var/adm/autoinstall/logs
%dir /var/adm/autoinstall/files
%dir /var/adm/autoinstall/cache
%dir /var/lib/autoinstall
%dir /var/lib/autoinstall/autoconf

%changelog
