#!/bin/bash

#set -x

AGENT="$1"

if [[ -z $AGENT ]]; then
  echo "Usage: $0 <agent ID>"
  exit 1
fi

TEMPDIR="/dev/shm"
TIMESTAMP=$(date +%s%N)

CONFIG=$(curl -s -w '%{response_code}' https://monitoring.r41.co/jobs/$AGENT?c=$TIMESTAMP -o "$TEMPDIR/$AGENT")

if [[ $CONFIG -lt 200 ]] || [[ $CONFIG -ge 300 ]]; then
  echo "Failed to load job configs."
  exit 2
fi

ENDPOINTS=$(cat "$TEMPDIR/$AGENT")

echo > $TEMPDIR/bzprobe-$TIMESTAMP.txt

for endpoint in $ENDPOINTS ; do
  host=$(echo $endpoint | awk -F/ '{ print $1"/"$2"/"$3 }')
  cat <<EOF >$TEMPDIR/bzprobe-format.txt
time_namelookup,endpoint=$host,agent=$AGENT,response_code=%{response_code} value=%{time_namelookup} $TIMESTAMP\n
time_connect,endpoint=$host,agent=$AGENT,response_code=%{response_code} value=%{time_connect} $TIMESTAMP\n
time_appconnect,endpoint=$host,agent=$AGENT,response_code=%{response_code} value=%{time_appconnect} $TIMESTAMP\n
time_pretransfer,endpoint=$host,agent=$AGENT,response_code=%{response_code} value=%{time_pretransfer} $TIMESTAMP\n
time_redirect,endpoint=$host,agent=$AGENT,response_code=%{response_code} value=%{time_redirect} $TIMESTAMP\n
time_starttransfer,endpoint=$host,agent=$AGENT,response_code=%{response_code} value=%{time_starttransfer} $TIMESTAMP\n
time_total,endpoint=$host,agent=$AGENT,response_code=%{response_code} value=%{time_total} $TIMESTAMP\n
ssl_verify_result,endpoint=$host,agent=$AGENT,response_code=%{response_code} value=%{ssl_verify_result} $TIMESTAMP\n
EOF

  curl -w "@$TEMPDIR/bzprobe-format.txt" -o /dev/null -s "$endpoint" >> $TEMPDIR/bzprobe-$TIMESTAMP.txt
  rm -rf $TEMPDIR/bzprobe-format.txt
done

curl -i -XPOST "https://r41.co/m/" --data-binary "@$TEMPDIR/bzprobe-$TIMESTAMP.txt"
rm -rf $TEMPDIR/bzprobe-$TIMESTAMP.txt
