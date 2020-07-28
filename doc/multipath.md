# Old multipath support

Starting on 3.3.x version, AutoYaST relies on the storage-ng library. That
means AutoYaST itself does not contain the logic to process the `<partitioning>`
section of the profile. See the [storage-ng.md](storage-ng.md) file for more
information about how it.

But prior to that version (that is, in the SLE-12 family and before), AutoYaST
contained the logic to process all the `<drive>` entries and to make them match
with the corresponding entries in the TargetMap (the data structure used by the
old libstorage to represent the storage setup of a system). Unfortunately, that
logic had some quirks and in some cases didn't fully match the documented
behavior.

Specially the combination of AutoYaST with the multipath technology has been a
constant source of confusion. The goal of this document is to clarify what's the
real usage of the drive types `CT_DISK` and `CT_DMMULTIPATH` and of the
parameter `general/storage/start_multipath` when importing (i.e. applying) an
AutoYaST profile in SLE-12-SP4, the latest version of SLE-12 available at the
time of writing.

## TL;DR

- Multipath is only activated if `start_multipath` is true. The presence of a
  `CT_DMMULTIPATH` drive has no influence.
- With `start_multipath`, only `CT_DMMULTIPATH` drives should be used.
- Without `start_multipath`, only `CT_DISK` drives should be used.
- Unfortunately, it's not always that straightforward. See below.

## Some Multipath and AutoYaST Facts

- When multipath is activated in a Linux system, all disks in such system are
  grouped into multipath devices. For example, if `sda` is an individual disk
  while `sdb` and `sdc` are actually part of the same multipath, the system will
  contain two multipath block devices (one for `sdb`+`sdc` and another one for
  `sda` only). That's represented in the TargetMap by the corresponding `CT_DISK`
  and `CT_DMMULTIPATH` elements. When using libstorage-ng, all those disks and
  multipath devices are also represented in the devicegraph (the equivalent
  storage-ng structure).
- With AutoYaST, multipath is only activated if `start_multipath` is true. The
  presence of a `CT_DMMULTIPATH` drive has no influence.
- **Important:** AutoYaST in SLE-12-SPX will often select the disk with
  `bios_id=0x80` for the first drive, no matter whether such drive is `CT_DISK` or
  `CT_DMMULTIPATH` and no matter whether the disk is part of a multipath device.
  See [this
  code](https://github.com/yast/yast-autoinstallation/blob/c01fe86f3d508c4b7d7be28bfd8d66541e1b1fa8/src/modules/AutoinstStorage.rb#L107).
- With the `bios_id` exception mentioned above, drives which don't specify any
  device name will only match elements in the TargetMap with its very own type
  (`CT_MULTIPATH` or `CT_DISK`).

## The default behavior

Based on the previous facts, this describes how AutoYaST matches drives in the
profile with devices in the TargetMap, assuming no device names, skip lists or
any other mechanism is introduced in the drives to alter the default behavior of
matching by position and type.

- With `start_multipath`:
  - Only `CT_DMMULTIPATH` drives should be used, since you never want to use
    disks directly.
  - `CT_DISK` drives are useless, they will only match disks that are part of a
    multipath device.
  - Moreover, drives that were assigned to such disks will be ignored later.
  - **Pitfall:** a disk with `bios_id=0x80` can match a `CT_DMMULTIPATH` drive.
    That messes everything up.

- Without `start_multipath`:
  - Only `CT_DISK` drives should be used, there are no multipath devices in the
    system.
  - `CT_DMMULTIPATH` drives are useless, they should match with nothing... with
    one unintended exception (keep reading).
  - Exception to `CT_DMMULTIPATH` matching nothing: if the first drive is
    `CT_DMMULTIPATH` and there is a disk with `bios_id=0x80`, that will match.

## Sources of information

Apart from inspecting the code, most of the facts and conclusions on this
document where obtained by executing manual tests in the context of the
following bug reports:

- [bsc#1130988](https://bugzilla.suse.com/show_bug.cgi?id=1130988)
- [bsc#1135735](https://bugzilla.suse.com/show_bug.cgi?id=1135735)

[This wiki page](https://github.com/yast/yast-autoinstallation/wiki/Experiments-with-AutoYaST-and-Multipath)
summarizes the results of those manual tests (including more details in some
cases) and served as the main source of information for writing this document.
