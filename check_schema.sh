#! /bin/sh

# explicitly check the RNC schema files for errors
# (the files are defined here, but converted in yast2-schema)
find . -name "*.rnc" -exec trang -I rnc -O rng \{\} test.rng \; 2> trang.log
rm -f test.rng

# grep for "error" in the output, "trang" returns 0 exit status
# even on an error :-(
if grep -i -q error trang.log; then
    echo "Error in schema:"
    cat trang.log
    rm -f trang.log
    exit 1
fi

rm -f trang.log

