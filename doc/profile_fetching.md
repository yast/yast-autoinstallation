# Profile Fetching

Fetching the AutoYaST profile is not a trivial process. Most of the complexity comes from the
rules/classes mechanism that, suprisingly, will come into play even if no rules or classes has been
defined.

Before reading the rest of this document, it is recommended to have a look to the [Rules and
Classes](https://documentation.suse.com/sles/15-SP2/single-html/SLES-autoyast/#rulesandclass)
chapter in the AutoYaST guide.

## The Process 

The {Yast::ProfileLocationClass#Process ProfileLocationClass#Process} method drives the fetching process,
although it cooperates with other modules like {Yast::AutoinstConfigClass AutoinstConfig} or
{Yast::AutoInstallRulesClass AutoInstallRules}.

As a first step, {Yast::ProfileLocationClass#Process ProfileLocationClass#Process} reads the
profile's location from the {Yast::AutoinstConfigClass AutoinstConfig} module and depending on
whether the URL points to a file or a directory, it behaves in a slightly different way.

* If it is a file, it just downloads the file and instructs the {Yast::AutoInstallRulesClass
  AutoInstallRules} module to use only that file. See {Yast::AutoInstallRulesClass#CreateFile
  AutoInstallRulesClass#CreateFile}.
* If it is a directory, it asks {Yast::AutoInstallRulesClass AutoInstallRules} to process the rules
  that are supposed to live in the `rules/rules.xml`, under the given directory. See
  {Yast::AutoInstallRulesClass#Read}.
  
In both cases, the {Yast::AutoInstallRulesClass AutoInstallRules} module comes into play and
generates the final `autoinst.xml`. This logic is implemented in the {Yast::AutoInstallRulesClass
AutoInstallRulesClass#Process} method, which takes care of:

* Merging the files according to the rules to generate the profile, even if just one file was given.
* Processing the classes. If any class definition is found, their definitions will be loaded and
  merged into the final profile.

## Parsing AutoYaST URLs

The {Yast::AutoinstConfigClass AutoinstConfig} module is the responsible, among other things, for
holding the location of the profile. Once the module is imported, it reads the URL from the
`install.inf` directory and extracts the relevant information into a set of separated components
(`scheme`, `host`, etc.).

The URL of the profile can point to a file (like `http://example.net/tumbleweed.xml`) or to a
directory (`http://example.net/profiles/`). The trailing slash is important. 

## Encrypted Profiles

AutoYaST supports PGP-encrypted profiles. Such a scenario is handled in the
{Yast::ProfileLocationClass#Process ProfileLocationClass#Process} method. However, it looks like the
{Yast::ProfileClass#ReadXML ProfileClass#ReadXML} implements its own logic to decrypt profiles, so
extracting this logic to a new class might be the right thing to do.

## Default Rules

In case that not suitable rules are found (because the `rules/rules.xml` file does not exist),
AutoYaST uses a set of default rules. These rules are based in the host ID (the IP in hex format)
and the MAC address of the system. Check the {Yast::AutoInstallRulesClass#CreateDefault
AutoinstallRulesClass#CreateDefault} method for further details.

## Additional Notes

Almost the {Yast::AutoinstConfigClass AutoinstConfig} is responsible for parsing the AutoYaST URL,
some further processing is performed in the {Yast::ProfileLocationClass ProfileLocation} method when
dealing with `relurl` and `file` schemas.
