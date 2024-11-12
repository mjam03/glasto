#!/bin/bash

IPS="
194.168.202.201
194.168.202.202
194.168.202.203
194.168.202.208
194.168.202.209
194.168.202.211
194.168.202.212
194.168.202.213
194.168.202.214
194.168.202.218
194.168.202.232
"

for IP in ${IPS}
do
echo -n "$IP"
curl -s http://$IP/content/extras -H 'Host: glastonbury.seetickets.com' | grep 'Glastonbury Festival 2024<'|wc -l
done
