# Profile Handling

This document describes how the profile is handled by AutoYaST during auto-installation/upgrade. If
you are not interested in the details, having a look at the `Overview` section should be enough.

Additionally, Linuxrc can be involved in the process of getting the AutoYaST profile. You can find
the details [in the Linuxrc
repository](https://github.com/openSUSE/linuxrc/blob/ed2699964a9b4305ad37b280a1168901b1f81c78/linuxrc_and_autoyast.md).

## Overview

During the autoinstallation/autoupgrade, an AutoYaST profile goes through different phases:

1. Fetching: the profile is retrieved from the given location and stored in a path, determined by
   `AutoinstConfig.xml_tmpfile` (usually `/tmp/profile/autoinst.xml`). It is possible to
   combine multiple files by using the *rules and classes*.
2. Import: the contents from the profile are imported through the {Yast::ProfileClass#ReadXML
   Profile.ReadXML} method.
3. Runtime modification: the user can alter the profile using *pre-scripts* or the *ask-list
   section*. In case the profile gets modified, it is imported again.
4. Processing: the {Y2Autoinstallation::Clients::InstAutosetup InstAutosetup} and
   {Y2Autoinstallation::Clients::InstAutosetupUpgrade InstAutosetupUpgrade} are responsible for
   processing the profile. They call the *Import* action of different modules/clients with the
   corresponding section of the profile.
5. Saving for 2nd Stage: the profile is stored in the target system so it can be imported (and
   processed) again during the 2nd stage.
6. (Optional) 2nd Stage Configuration: the `inst_autoconfigure` processes the sections that were
   not considered during the 1st stage.

{file:validation.md Profile validation} is performed at different places. Rules and classes are
validated too.

## Phases

### Fetching the Profile

The {Yast::ProfileLocationClass#Process ProfileLocation.Process} fetches the profile, although it
relies on other modules like {Yast::AutoInstallClass AutoInstall} or {Yast::AutoInstallRulesClass
AutoInstallRules} modules. This method asks the {Yast::AutoinstConfigClass AutoinstConfig} module
about the URL to get the profile. This module reads and parses the URL from the `AutoYaST` key in
the `/etc/install.inf` file.

At this point, AutoYaST can face two different scenarios:

* The profile is just a file. In this case, it tries to retrieve the profile using the
  `Yast::Transfer::FileFromUrl#Get` method. If the profile is encrypted, it will ask the user for
  the password to decrypt it.
* The profile URL points to a directory (the URL has a trailing slash). AutoYaST considers that the
  profile must be built using the *rules and classes mechanism*, so it initializes the
  {Yast::AutoInstallRulesClass AutoInstallRules} and processes the rules.
  
In both cases, the resulting profile is stored at `/tmp/profile/autoinst.xml`
(`AutoinstConfig.xml_tmpfile`).

### Runtime Modification

AutoYaST offers two mechanisms to modify a profile at runtime: [pre-install
scripts](https://documentation.suse.com/sles/15-SP2/single-html/SLES-autoyast/#pre-install-scripts)
and [ask
lists](https://documentation.suse.com/sles/15-SP2/single-html/SLES-autoyast/#CreateProfile-Ask). You
can find more details by checking the private `#autoinit_scripts` method in the
{Y2Autoinstallation::Clients::InstAutoinit InstAutoinit} client.

### Processing the Profile

After having retrieved and tuned (if needed) the profile, it is time to process the content. The
{Y2Autoinstallation::Clients::InstAutosetup InstAutosetup} and
{Y2Autoinstallation::Clients::InstAutosetupUpgrade InstAutosetupUpgrade} are responsible for going
through the profile and asking the corresponding clients to import each section. In many cases, the
imported sections are removed from the profile to not be processed again during the 2nd stage.

### Saving the Profile for the 2nd stage

At the end of the 1st stage, the `inst_finish` client writes the profile data to
`/var/adm/autoinstall/cache/autoinst.ycp` (according to
`Yast::AutoinstConfigClass#parsedControlFile`), so AutoYaST can read the profile at the beginning of
the 2nd stage.

The responsible for writing the file is the {Yast::AutoInstallClass#Save AutoInstall.Save} method,
which relies on {Yast::ProfileClass#SaveProfileStructure Profile.SaveProfileStructure} to do that.
The sections that were removed are not included.

### (Optional) Profile Processing during the 2nd Stage

In case the 2nd stage runs, the {Yast::AutoInstallClass#Continue AutoInstall#Continue} reads the
profile data from `/var/adm/autoinstall/cache/autoinst.ycp` using the
{Yast::ProfileClass#ReadProfileStructure Profile.ReadProfileStructure}. The `Continue` method is
invoked when the module is imported as part of {Yast::InstAutopostClient InstAutopostClient}
initialization.

The {Yast::InstAutoconfigureClient InstAutoconfigureClient} client is responsible for processing the
profile by invoking the `Import` and `Write` actions for the corresponding clients.

## Summary of Involved Modules

* {Yast::ProfileClass Profile} : holds the information from the profile which is accessible through
  the {Yast::ProfileClass#current Profile.current} method. Additionally, it offers few methods to
  save/load the profile like {Yast::ProfileClass.ReadXML Profile#ReadXML},
  {Yast::ProfileClass#SaveProfileStructure Profile.SaveProfileStructure} and
  {Yast::ProfileClass#ReadProfileStructure Profile.ReadProfileStructure}.
* {Yast::ProfileLocationClass ProfileLocation}: it is responsible for fetching the profile. It
  features a {Yast::ProfileLocationClass#Process ProfileLocation.Process} that drives this process.
* {Yast::AutoinstConfigClass AutoinstConfig}: stores configuration settings, like the URL to
  retrieve the profile from.
* {Yast::AutoInstallClass AutoInstall}: takes care of saving and reading the profile to be used
  during the 2nd stage.
