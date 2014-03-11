#!/bin/sh

echo "chroot script $0 (chroot true) has run" > /tmp/chroot-script-has-run
sleep 10
echo $* >> /tmp/chroot-script-has-run
echo ARG0:$0: >> /tmp/chroot-script-has-run
echo ARG1:$1: >> /tmp/chroot-script-has-run
echo ARG2:$2: >> /tmp/chroot-script-has-run
echo ARG3:$3: >> /tmp/chroot-script-has-run
echo ARG4:$4: >> /tmp/chroot-script-has-run
echo ARG5:$5: >> /tmp/chroot-script-has-run
echo ARG6:$6: >> /tmp/chroot-script-has-run
echo ARG7:$7: >> /tmp/chroot-script-has-run
echo ARG8:$8: >> /tmp/chroot-script-has-run
echo ARG9:$9: >> /tmp/chroot-script-has-run

