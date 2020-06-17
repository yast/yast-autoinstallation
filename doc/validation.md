# Profile Validation

Since version 4.3.9 AutoYaST validates all XML files (profiles,
rules, classes) before using them to avoid possible problems later.

## Validation Errors

If a XML document does not validate or is not well-formed (contains syntax
errors) then AutoYaST displays an error popup with details.

It is still possible to continue and use the XML file by clicking the
`Continue` button. But that is on your risk, the installation might later
fail or crash, the result will be different than expected or some data
might be lost.

If you are sure the XML file is correct and the problem is in the validation
itself you can disable the error popup, see below.

## Manual Validation

Of course, it is much easier to validate the XML files *before* using them.
The error popup contains some example commands for validating the failed file
manually. See the [AutoYaST documentation](
https://doc.opensuse.org/projects/autoyast/#CreateProfile-Manual) for more
details.

It is recommended to use `jing` for manual validation, it usually produces
better error messages than `xmllint` (which is also internally used by AutoYaST).

## Disabling Validation

In some rare cases the XML files might work correctly but the validation
reports errors because of an issue in the schema definition or in the validation
process itself.

In that case you can set the environment variable `YAST_SKIP_XML_VALIDATION=1`
to skip the error popups. You can set that directly on the boot command line.

Note: Internally the validation is still done, but the result is only logged
into the `y2log` file, the error popup is not displayed. This should help with
debugging AutoYaST problems.
