#!/bin/sh

echo "post script (network false) has run" > /tmp/post-script-has-run
echo $* >> /tmp/post-script-has-run
echo ARG0:$0: >> /tmp/post-script-has-run
echo ARG1:$1: >> /tmp/post-script-has-run
echo ARG2:$2: >> /tmp/post-script-has-run
echo ARG3:$3: >> /tmp/post-script-has-run
echo ARG4:$4: >> /tmp/post-script-has-run
echo ARG5:$5: >> /tmp/post-script-has-run
echo ARG6:$6: >> /tmp/post-script-has-run
echo ARG7:$7: >> /tmp/post-script-has-run
echo ARG8:$8: >> /tmp/post-script-has-run
echo ARG9:$9: >> /tmp/post-script-has-run

