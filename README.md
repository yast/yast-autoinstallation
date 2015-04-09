YaST - The AutoYaST Framework
=============================

[![Travis Build](https://travis-ci.org/yast/yast-autoinstallation.svg?branch=master)](https://travis-ci.org/yast/yast-autoinstallation)
[![Jenkins Build](http://img.shields.io/jenkins/s/https/ci.opensuse.org/yast-autoinstallation-master.svg)](https://ci.opensuse.org/view/Yast/job/yast-autoinstallation-master/)

Testing Environment
===================

There are several possibilities how test an updated code. It also depends on
the fact in which stage of installation it comes into effect. First stage runs
between the start from installation media to reboot (or kexec), then continues
second stage.

### First Stage ###

Either use *StartShell=1* option in [Linuxrc](https://en.opensuse.org/SDB:Linuxrc),
edit the installation system and run *yast* manually or use
a [DriverUpdate](https://en.opensuse.org/SDB:Linuxrc#p_dud) via Linuxrc.

### Second Stage ###

There are two possible ways how to rerun this stage, just keep in mind that
the system might be already configured and thus it might behave
a bit differently:

  ```
  cp /var/lib/YaST2/install.inf /etc/
  touch /var/lib/YaST2/runme_at_boot
  cp /var/adm/autoinstall/cache/installedSystem.xml \
    /var/lib/autoinstall/autoconf/autoconf.xml
  reboot
  ```

or faster without rebooting but with possible side-effects:

  ```
  yast ayast_setup setup filename=/var/adm/autoinstall/cache/installedSystem.xml
  ```
