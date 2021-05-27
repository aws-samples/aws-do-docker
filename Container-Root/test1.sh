#!/bin/sh

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

# Unit test 1

PORT=80
if [ ! -z "$PORT_INTERNAL" ]; then
	PORT=$PORT_INTERNAL
fi

CMD="curl -i -s 'http://localhost:${PORT_INTERNAL}/'"

echo "$CMD"

RESULT=$(eval "$CMD")

echo "$RESULT"

echo "$RESULT" | grep Healthy > /dev/null

if [ $? -eq 0 ]; then
	echo ""
	echo "Test1 succeeded"
else
	echo ""
	echo "Test1 failed"
fi
echo ""
