# Profile Conversions

Although AutoYaST keeps backward compatibility so the old profiles should work
in new product releases in some cases it might be useful to do some conversions.

## :warning: Warning

*The automatic conversions using XSLT might not produce exact 1:1 results,
there might be minor differences in formatting, also the CDATA sections are
converted to regular data.*

*Always check the conversion result and adjust it manually if needed.*

## Converting from the Old Data Types to the New Ones

Since SLE15-SP3 AutoYaST simplified the data type definitions in the XML
profiles.

Instead of `config:type="boolean"` you can use a shorter form `t="boolean"`,
for example:

```xml
<confirm t="boolean">true</confirm>
```

To convert the data types automatically you can use the [`new_types.xslt`](
../xslt/new_types.xslt) file.

```shell
xsltproc -o profile_new.xml /usr/share/autoinstall/xslt/new_types.xslt profile.xml
```

## Converting from the New Data Types to the Old Ones

This is the opposite process to the previous conversion, it converts the new
data types to the old ones. This is useful if you want to use a new profile
in an old system (SLE15-SP2 and older). The old AutoYaST cannot read the new
data types and it would fail.

The [`old_types.xslt`](../xslt/old_types.xslt) file converts the short
attributes `t="boolean"` to long attributes `config:type="boolean"`.

```shell
xsltproc -o profile_old.xml /usr/share/autoinstall/xslt/old_types.xslt profile.xml
```
