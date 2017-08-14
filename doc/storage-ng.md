# Storage-ng integration

Starting on 3.3.x version, AutoYaST relies on the new storage-ng library. This
document, which is still **a work in progress**, briefly describes how the
integration works.

## Partitioning

When thinking about partitioning, AutoYaST use cases could be organize into
three different levels:

* Automatic proposal
* Guided proposal
* User defined partitioning

### Level #1: automatic proposal

In this case, no information about the storage is included in the profile.
AutoYaST will ask storage-ng for a proposal with the default settings, which are
defined in the product's control file.

### Level #2: guided proposal

The user can override settings from product's control file through the `general/storage`
section of the profile, influencing on the storage-ng proposal.

```xml
<profile xmlns="http://www.suse.com/1.0/yast2ns" xmlns:config="http://www.suse.com/1.0/configns">
  <general>
    <storage>
      <!-- Override settings from control file  -->
      <try_separate_home config:type="boolean">false</try_separate_home>
      <proposal_lvm config:type="boolean">true</proposal_lvm>
    </storage>
  </general>
</profile>
```

Given the example below, `try_separate_home` and `proposal_lvm` values would be
overriden, so the proposal would use LVM and /home will be in the same filesystem
than /.

### Level #3: user-defined partitioning

Not implemented yet

## AutoYaST Workflow

As many other things, storage set up is initiated by the `inst_autosetup client`
by calling `AutoinstGeneral.Import` and `AutoinstStorage.Import`.

* During the first call, settings under `general/storage` will be imported overriding
the ones from the product's control file.
* On the second call, the `partitioning` section will be imported (level #3). If
that section is not found, AutoYaST will ask storage-ng for a proposal (levels
#1 and #2).
