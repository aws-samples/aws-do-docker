#!/bin/sh

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

# Unit test 2

CMD="echo {\"Message\": \"Job container unit test successful\"} | tee /tmp/message.txt > /dev/null; cat /tmp/message.txt"

#echo "$CMD"

RESULT=$(eval "$CMD")

echo "$RESULT"

echo "$RESULT" | grep successful > /dev/null

if [ $? -eq 0 ]; then
	echo ""
	echo "Test2 succeeded"
else
	echo ""
	echo "Test2 failed"
fi
echo ""
