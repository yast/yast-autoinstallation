## Relax NG Schema

See [doc/validation.md: Profile Validation](../../doc/validation.md).

### Validating the Schema Itself

(Or, Who will guard the guards themselves?)

See [check_schema.sh](../../check_schema.sh) at the root of this repo,
which is run as part of a [CI GH Action](../../.github/workflows/ci.yml).

To run it yourself you may need to install the tools:

```sh
zypper install trang
```
