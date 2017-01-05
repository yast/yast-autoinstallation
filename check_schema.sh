#! /bin/sh

# This script checks that all RNC files can be converted to RNG without errors.

# Fail if trang is missing
if ! which trang > /dev/null; then
  echo 'ERROR: "trang" tool is missing'
  exit 1
fi

# explicitly check the RNC schema files for errors
# (the files are defined here, but converted in yast2-schema)
find . -name "*.rnc" -exec sh -c "echo 'Checking {}...'; trang -I rnc -O rng {} /dev/null" \; 2> trang.log

# grep for "error" in the output, "trang" returns 0 exit status
# even on an error :-(
if grep -i -q error trang.log; then
    echo "Error in schema:"
    cat trang.log
    rm -f trang.log
    exit 1
fi

rm -f trang.log
echo "OK"
