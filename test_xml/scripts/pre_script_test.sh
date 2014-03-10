#!/bin/sh

echo "pre script has run" > /tmp/pre-script-has-run
echo $* >> /tmp/pre-script-has-run
echo ARG0:$0: >> /tmp/pre-script-has-run
echo ARG1:$1: >> /tmp/pre-script-has-run
echo ARG2:$2: >> /tmp/pre-script-has-run
echo ARG3:$3: >> /tmp/pre-script-has-run
echo ARG4:$4: >> /tmp/pre-script-has-run
echo ARG5:$5: >> /tmp/pre-script-has-run
echo ARG6:$6: >> /tmp/pre-script-has-run
echo ARG7:$7: >> /tmp/pre-script-has-run
echo ARG8:$8: >> /tmp/pre-script-has-run
echo ARG9:$9: >> /tmp/pre-script-has-run

