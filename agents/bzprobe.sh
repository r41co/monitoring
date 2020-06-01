#!/bin/bash

set -x

AGENT="$1"

if [[ -z $AGENT ]]; then
  echo "Usage: $0 <agent ID>"
  exit 1
fi

TEMPDIR="/dev/shm"

CONFIG=$(curl -s -w '%{response_code}' https://monitoring.r41.co/jobs/$AGENT -o "$TEMPDIR/$AGENT")

if [[ $CONFIG -lt 200 ]] || [[ $CONFIG -ge 300 ]]; then
  echo "Failed to load job configs."
  exit 2
fi

ENDPOINTS=$(cat "$TEMPDIR/$AGENT")

TIMESTAMP=$(date +%s%N)
echo > $TEMPDIR/bzprobe-$TIMESTAMP.txt

for endpoint in $ENDPOINTS ; do
  cat <<EOF >$TEMPDIR/bzprobe-format.txt
time_namelookup,endpoint=$endpoint,agent=$AGENT value=%{time_namelookup} $TIMESTAMP\n
time_connect,endpoint=$endpoint,agent=$AGENT value=%{time_connect} $TIMESTAMP\n
time_appconnect,endpoint=$endpoint,agent=$AGENT value=%{time_appconnect} $TIMESTAMP\n
time_pretransfer,endpoint=$endpoint,agent=$AGENT value=%{time_pretransfer} $TIMESTAMP\n
time_redirect,endpoint=$endpoint,agent=$AGENT value=%{time_redirect} $TIMESTAMP\n
time_starttransfer,endpoint=$endpoint,agent=$AGENT value=%{time_starttransfer} $TIMESTAMP\n
time_total,endpoint=$endpoint,agent=$AGENT value=%{time_total} $TIMESTAMP\n
response_code,endpoint=$endpoint,agent=$AGENT value=%{response_code} $TIMESTAMP\n
ssl_verify_result,endpoint=$endpoint,agent=$AGENT value=%{ssl_verify_result} $TIMESTAMP\n
EOF

  curl -w "@$TEMPDIR/bzprobe-format.txt" -o /dev/null -s "$endpoint" >> $TEMPDIR/bzprobe-$TIMESTAMP.txt
  rm -rf $TEMPDIR/bzprobe-format.txt
done

curl -i -XPOST "https://r41.co/m/" --data-binary "@$TEMPDIR/bzprobe-$TIMESTAMP.txt"
rm -rf $TEMPDIR/bzprobe-$TIMESTAMP.txt
