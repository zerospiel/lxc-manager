#!/bin/sh
grep -w 'NAME' $1 | awk '{ print substr($0, 6); }'
