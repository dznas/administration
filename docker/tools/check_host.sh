#! /bin/sh
#
# check_host.sh -- a wrapper script to run diagnostics and generate a report.
# 
# needs ssh root access on the host to check.
# needed on the host to check:
#   - tar, bash, python
#   - smartmontools
#
# 2018 (c) jw@owncloud.com
# Distribute under GPLv2 or ask.
#
# 2018-01-24, initial draught.

remote="$1"

test -z "$CHECK_HOST_INTERVAL" && export CHECK_HOST_INTERVAL=4
test -n "$2" && CHECK_HOST_INTERVAL="$2"

if [ -n "$remote" ]; then
  if [ "$remote" = "-h" -o "$remote" = "--help" ]; then
    echo "Usage: $0 root@server.example.com [delay]"
    exit 1
  fi
  dir=$(dirname $0)
  echo "transfering to $remote ..."
  tar cf - --exclude obs $dir | ssh -o ConnectTimeout=5 $remote 'td=$(mktemp -t -d check_host_XXXXXX) && tar xf - -C $td && cd $td && env CHECK_HOST_INTERVAL='$CHECK_HOST_INTERVAL' sh $td/check_host.sh && rm -rf "/tmp/$(basename $td)"'
  exit 0
fi
echo ... $(basename $0) running on $(hostname)

(
export TMPDIR=./tmp/
mkdir -p $TMPDIR
uptime
uname -a

if [ -n "$(smartctl --version 2>/dev/null)" ]; then
  # Requires: apt-get install smartmontools
  sh ./diskerrors.sh | python ./persec.py -c 5 > /dev/null
  sleep $CHECK_HOST_INTERVAL
  sh ./diskerrors.sh | python ./persec.py -c 5
fi

if [ -n "$(docker ps -q 2>/dev/null)" ]; then
  # docker is installed
  sh ./dockernetio.sh | python ./persec.py -c 2 -u K -n TX_KBytes | python ./persec.py -c 3 -u K -n RX_KBytes > /dev/null
  sleep $CHECK_HOST_INTERVAL
  sh ./dockernetio.sh | python ./persec.py -c 2 -u K -n TX_KBytes | python ./persec.py -c 3 -u K -n RX_KBytes
fi

rm -rf $TMPDIR
) | sed -e "s/^/$(hostname): /"

