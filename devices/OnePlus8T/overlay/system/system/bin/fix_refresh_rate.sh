#!/bin/sh

while [ "$(getprop sys.boot_completed)" != "1" ];do
    sleep 0.1s
done

settings put system peak_refresh_rate 60
sleep 0.5s
settings put system peak_refresh_rate 120