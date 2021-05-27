#!/bin/sh

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

# Unit test 1

CMD="echo {\"Status\": \"Successful\"} | tee /tmp/status.txt > /dev/null; cat /tmp/status.txt"

#echo "$CMD"

RESULT=$(eval "$CMD")

echo "$RESULT"

echo "$RESULT" | grep Successful > /dev/null

if [ $? -eq 0 ]; then
	echo ""
	echo "Test1 succeeded"
else
	echo ""
	echo "Test1 failed"
fi
echo ""
