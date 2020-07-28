# Error Reporting

This document tries to summarize the error reporting mechanisms that, as a developer, you can use
when writing code for AutoYaST. Bear in mind that both mechanisms have different purposes. On the
one hand, the `Yast::Report` module is the way to go when you want to notify a general problem or
ask a Yes/No question. On the other hand, the purpose of the AutoYaST issues mechanism is to notify
semantic issues in the profile.

## Yast::Report Module

The `Yast::Report` module offers a simple and configurable mechanism for error reporting. It relies
on the `Yast::Popup` mechanism but offers a few additional features:

* Show/Hide messages depending on its severity (error, messages, yes/no questions, etc.).
* Messages logging.
* Time-outs.
* Support for the command line interface.

```ruby
Yast.import "Report"
Yast::Report.Error("Something was wrong")
```

Usually, the reporting settings are defined in the AutoYaST profile. For instance, with the
following settings, AutoYaST stops only when an error message is reported. For the rest, it applies
a 10 seconds time-out. Additionally, all messages are logged.

```xml
<report>
  <errors>
    <show config:type="boolean">true</show>
    <timeout config:type="integer">0</timeout>
    <log config:type="boolean">true</log>
  </errors>
  <warnings>
    <show config:type="boolean">true</show>
    <timeout config:type="integer">10</timeout>
    <log config:type="boolean">true</log>
  </warnings>
  <messages>
    <show config:type="boolean">true</show>
    <timeout config:type="integer">10</timeout>
    <log config:type="boolean">true</log>
  </messages>
  <yesno_messages>
    <show config:type="boolean">true</show>
    <timeout config:type="integer">10</timeout>
    <log config:type="boolean">true</log>
  </yesno_messages>
</report>
```

However, this module is not limited to work in AutoYaST, and can be used in any other part of YaST.

## The New AutoYaST Issues Mechanism

In openSUSE Leap 15.0 and SUSE Linux Enterprise SLE 15, AutoYaST introduced a mechanism to report
semantic issues in the profile. At the beginning, it was implemented as part of the storage-ng
initiative, and later it was [generalized](https://github.com/yast/yast-autoinstallation/pull/431)
to be used by other parts of AutoYaST. It is still a work in progress, so expect small changes in
the API.

The core of the implementation lives in the [Installation::AutoinstIssues
module](https://github.com/yast/yast-yast2/blob/5902d449f108bba6edcbccad8394ed93dc9cae39/library/general/src/lib/installation/autoinst_issues).
Each kind of issue is represented by a class which inherits from [Installation::AutoinstIssues::Issue
class](https://github.com/yast/yast-yast2/blob/5902d449f108bba6edcbccad8394ed93dc9cae39/library/general/src/lib/installation/autoinst_issues/issue.rb).
Classes for common problems, like `InvalidValue` and `MissingValue`, are already offered but you are
free to implement your own. For instance, see the
[Y2Storage::AutoinstIssues](https://github.com/yast/yast-storage-ng/tree/master/src/lib/y2storage/autoinst_issues)
for additional examples.

All reported problems are added to an [IssuesList
instance](https://github.com/yast/yast-yast2/blob/5902d449f108bba6edcbccad8394ed93dc9cae39/library/general/src/lib/installation/autoinst_issues/list.rb)
which is accessible through the `Yast::AutoInstall` module. So, in order to register a problem, you
use the `IssuesList#add` method.

```ruby
Yast::AutoInstall.issues_list.add(
  ::Installation::AutoinstIssues::InvalidValue,
  firewall_section, # the firewall section is an instance of a Installation::AutoinstProfile::SectionWithAttributes subclass
  "FW_DEV_INT",
  "1",
  _("It is not supported anymore."))
)
```

An important difference with the `Yast::Report` mechanism is that the messages are not shown when
they are added. Instead, all of them are displayed at the same point, [after the profile is
imported](https://github.com/yast/yast-autoinstallation/blob/2edc7bf7d1cee1310a5c120ce9a131d6ff9a430f/src/clients/inst_autosetup.rb#L430).
Moreover, reporting errors and warning settings are honored when displaying those messages. Check
the
[Yast::AutoInstall#valid_imported_values](https://github.com/yast/yast-autoinstallation/blob/2edc7bf7d1cee1310a5c120ce9a131d6ff9a430f/src/modules/AutoInstall.rb#L329)
for further details.
