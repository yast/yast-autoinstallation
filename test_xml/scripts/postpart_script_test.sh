#!/bin/sh

echo "postpart script has run" > /tmp/postpart-script-has-run
echo $* >> /tmp/postpart-script-has-run
echo ARG0:$0: >> /tmp/postpart-script-has-run
echo ARG1:$1: >> /tmp/postpart-script-has-run
echo ARG2:$2: >> /tmp/postpart-script-has-run
echo ARG3:$3: >> /tmp/postpart-script-has-run
echo ARG4:$4: >> /tmp/postpart-script-has-run
echo ARG5:$5: >> /tmp/postpart-script-has-run
echo ARG6:$6: >> /tmp/postpart-script-has-run
echo ARG7:$7: >> /tmp/postpart-script-has-run
echo ARG8:$8: >> /tmp/postpart-script-has-run
echo ARG9:$9: >> /tmp/postpart-script-has-run


