#!/bin/bash

#set -x

AGENT="$1"

if [[ -z $AGENT ]]; then
  echo "Usage: $0 <agent ID>"
  exit 1
fi

TEMPDIR="/dev/shm"
MAX_QUEUE=100
TIMESTAMP=$(date +%s%N)

CONFIG=$(curl -s -w '%{response_code}' https://monitoring.r41.co/jobs/$AGENT?c=$TIMESTAMP -o "$TEMPDIR/$AGENT")

if [[ $CONFIG -lt 200 ]] || [[ $CONFIG -ge 300 ]]; then
  echo "Failed to load job configs."
  exit 2
fi

ENDPOINTS=$(cat "$TEMPDIR/$AGENT")

if [[ -f $TEMPDIR/bzprobe-queue.txt ]]; then
  cat $TEMPDIR/bzprobe-queue.txt > $TEMPDIR/bzprobe-$TIMESTAMP.txt
  rm -rf $TEMPDIR/bzprobe-queue.txt
else
  echo > $TEMPDIR/bzprobe-$TIMESTAMP.txt
fi

for endpoint in $ENDPOINTS ; do
  host=$(echo $endpoint | awk -F/ '{ print $1"/"$2"/"$3 }')
  cat <<EOF >$TEMPDIR/bzprobe-format.txt
response,endpoint=$host,agent=$AGENT,response_code=%{response_code} time_namelookup=%{time_namelookup},time_connect=%{time_connect},time_appconnect=%{time_appconnect},time_pretransfer=%{time_pretransfer},time_redirect=%{time_redirect},time_starttransfer=%{time_starttransfer},time_total=%{time_total},ssl_verify_result=%{ssl_verify_result} $TIMESTAMP\n
EOF

  curl -w "@$TEMPDIR/bzprobe-format.txt" -o /dev/null -s "$endpoint" >> $TEMPDIR/bzprobe-$TIMESTAMP.txt
  rm -rf $TEMPDIR/bzprobe-format.txt
done

code=$(curl -s -w '%{response_code}' -XPOST "https://r41.co/m/" --data-binary "@$TEMPDIR/bzprobe-$TIMESTAMP.txt")

if [[ $code -lt 200 ]] || [[ $code -gt 299 ]]; then
  cat $TEMPDIR/bzprobe-$TIMESTAMP.txt | tail -n $MAX_QUEUE >> $TEMPDIR/bzprobe-queue.txt
fi

rm -rf $TEMPDIR/bzprobe-$TIMESTAMP.txt
