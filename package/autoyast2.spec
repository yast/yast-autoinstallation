#
# spec file for package autoyast2
#
# Copyright (c) 2012 SUSE LINUX Products GmbH, Nuernberg, Germany.
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
Version:        3.1.3
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        autoyast2-%{version}.tar.bz2


Group:	System/YaST
License:        GPL-2.0
Source1:        autoyast_en_html.tar.bz2
BuildRequires:	yast2-devtools >= 3.1.10
BuildRequires:  update-desktop-files
# /usr/share/YaST2/control/control.rng
BuildRequires:  yast2-installation
# xmllint
BuildRequires:  libxml2-tools

Requires:	yast2 >= 2.16.36
Requires:	yast2-core yast2-xml libxslt
Requires:	autoyast2-installation = %{version}
Requires:	yast2-schema yast2 yast2-country
Requires:	yast2-storage >= 3.0.5
Requires:	yast2-transfer >= 2.21.0

Provides:	yast2-module-autoinst yast2-config-autoinst
Obsoletes:	yast2-module-autoinst yast2-config-autoinst
Provides:	yast2-lib-autoinst
Obsoletes:	yast2-lib-autoinst

PreReq:		%insserv_prereq %fillup_prereq

BuildArchitectures:	noarch

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:	YaST2 - Automated Installation

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

Summary:	YaST2 - Auto Installation Modules
Group:		System/YaST
# API for Disabled Modules (ProductControl)
Requires:	yast2 >= 2.16.36
# After API cleanup
Requires:	yast2-update >= 2.18.3
Requires:	yast2-xml yast2-core yast2 yast2-country yast2-packager yast2-storage yast2-slp yast2-bootloader yast2-ncurses
Requires:	yast2-services-manager
Requires:	yast2-transfer >= 2.21.0
Provides:	yast2-trans-autoinst
Obsoletes:	yast2-trans-autoinst
%description installation
This package performs auto-installation relying on a control file
generated with the autoyast2 package.

%prep
%setup -n autoyast2-%{version}

%build
%{_prefix}/bin/y2tool y2autoconf
%{_prefix}/bin/y2tool y2automake
autoreconf --force --install

export CFLAGS="$RPM_OPT_FLAGS -DNDEBUG"
export CXXFLAGS="$RPM_OPT_FLAGS -DNDEBUG"

./configure --libdir=%{_libdir} --prefix=%{_prefix} --mandir=%{_mandir}
# V=1: verbose build in case we used AM_SILENT_RULES(yes)
# so that RPM_OPT_FLAGS check works
make %{?jobs:-j%jobs} V=1

%install
make install DESTDIR="$RPM_BUILD_ROOT"
[ -e "%{_prefix}/share/YaST2/data/devtools/NO_MAKE_CHECK" ] || Y2DIR="$RPM_BUILD_ROOT/usr/share/YaST2" make check DESTDIR="$RPM_BUILD_ROOT"
for f in `find $RPM_BUILD_ROOT/%{_prefix}/share/applications/YaST2/ -name "*.desktop"` ; do
    d=${f##*/}
    %suse_update_desktop_file -d ycc_${d%.desktop} ${d%.desktop}
done

for d in `ls $RPM_BUILD_ROOT/usr/share/autoinstall/modules/*.desktop`; do
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

%clean
rm -rf "$RPM_BUILD_ROOT"

%post
%{fillup_only -n autoinstall}


%files
%defattr(-,root,root)
%dir /etc/autoinstall
%dir /usr/share/YaST2/include/autoinstall
%dir /var/lib/autoinstall/repository
%dir /var/lib/autoinstall/repository/templates
%dir /var/lib/autoinstall/repository/rules
%dir /var/lib/autoinstall/repository/classes
%dir /var/lib/autoinstall/tmp
%doc %{_prefix}/share/doc/packages/autoyast2


%{_prefix}/share/applications/YaST2/autoyast.desktop
/usr/share/autoinstall/modules/*.desktop
/usr/share/YaST2/include/autoinstall/classes.rb
/usr/share/YaST2/include/autoinstall/conftree.rb
/usr/share/YaST2/include/autoinstall/dialogs.rb
/usr/share/YaST2/include/autoinstall/script_dialogs.rb
/usr/share/YaST2/include/autoinstall/general_dialogs.rb
/usr/share/YaST2/include/autoinstall/wizards.rb
/usr/share/YaST2/include/autoinstall/helps.rb
/usr/share/YaST2/schema/autoyast/rnc/*.rnc

/usr/share/YaST2/clients/general_auto.rb
/usr/share/YaST2/clients/report_auto.rb
/usr/share/YaST2/clients/classes_auto.rb
/usr/share/YaST2/clients/scripts_auto.rb
/usr/share/YaST2/clients/software_auto.rb
/usr/share/YaST2/clients/storage_auto.rb
/usr/share/YaST2/clients/autoyast.rb
/usr/share/YaST2/clients/clone_system.rb
/usr/share/YaST2/clients/ayast_setup.rb

/usr/share/YaST2/scrconf/ksimport.scr


/usr/share/YaST2/modules/AutoinstClass.rb
/usr/share/YaST2/modules/Kickstart.rb
/usr/lib/YaST2/servers_non_y2/ag_ksimport



# additional files

/var/adm/fillup-templates/sysconfig.autoinstall


%files installation
%defattr(-,root,root)
/usr/share/YaST2/scrconf/autoinstall.scr
/usr/share/YaST2/scrconf/cfg_autoinstall.scr
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

/usr/share/YaST2/modules/AutoinstClone.rb
%dir /usr/share/YaST2/include/autoinstall
/usr/share/YaST2/include/autoinstall/autopart.rb
/usr/share/YaST2/include/autoinstall/io.rb
/usr/share/YaST2/include/autoinstall/autoinst_dialogs.rb
/usr/share/YaST2/include/autoinstall/AdvancedPartitionDialog.rb
/usr/share/YaST2/include/autoinstall/DriveDialog.rb
/usr/share/YaST2/include/autoinstall/PartitionDialog.rb
/usr/share/YaST2/include/autoinstall/StorageDialog.rb
/usr/share/YaST2/include/autoinstall/VolgroupDialog.rb
/usr/share/YaST2/include/autoinstall/common.rb
/usr/share/YaST2/include/autoinstall/tree.rb
/usr/share/YaST2/include/autoinstall/types.rb

/usr/share/YaST2/control/*.xml

/usr/share/YaST2/modules/AutoInstall.rb
/usr/share/YaST2/modules/AutoinstScripts.rb
/usr/share/YaST2/modules/AutoinstGeneral.rb
/usr/share/YaST2/modules/AutoinstImage.rb
/usr/share/YaST2/modules/Y2ModuleConfig.rb
/usr/share/YaST2/modules/Profile.rb
/usr/share/YaST2/modules/AutoinstFile.rb
/usr/share/YaST2/modules/AutoinstConfig.rb
/usr/share/YaST2/modules/AutoinstSoftware.rb
/usr/share/YaST2/modules/AutoinstLVM.rb
/usr/share/YaST2/modules/AutoinstRAID.rb
/usr/share/YaST2/modules/AutoinstStorage.rb
/usr/share/YaST2/modules/AutoInstallRules.rb
/usr/share/YaST2/modules/ProfileLocation.rb
/usr/share/YaST2/modules/AutoinstCommon.rb
/usr/share/YaST2/modules/AutoinstDrive.rb
/usr/share/YaST2/modules/AutoinstPartPlan.rb
/usr/share/YaST2/modules/AutoinstPartition.rb

#clients
/usr/share/YaST2/clients/inst_autoinit.rb
/usr/share/YaST2/clients/inst_autoimage.rb
/usr/share/YaST2/clients/inst_autosetup.rb
/usr/share/YaST2/clients/inst_autoconfigure.rb
/usr/share/YaST2/clients/inst_autopost.rb
/usr/share/YaST2/clients/files_auto.rb
/usr/share/YaST2/clients/autoinst_test_clone.rb
/usr/share/YaST2/clients/autoinst_test_stage.rb
/usr/share/YaST2/clients/autoinst_scripts1_finish.rb
/usr/share/YaST2/clients/autoinst_scripts2_finish.rb
/usr/share/YaST2/clients/ayast_probe.rb
/usr/share/YaST2/clients/inst_autosetup_upgrade.rb
/usr/share/YaST2/clients/inst_store_upgrade_software.rb

/usr/share/YaST2/include/autoinstall/xml.rb
/usr/share/YaST2/include/autoinstall/ask.rb

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


