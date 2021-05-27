#!/bin/sh

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

# Unit test 2

PORT=80
if [ ! -z "$PORT_INTERNAL" ]; then
        PORT=$PORT_INTERNAL
fi

CMD="curl -i -s 'http://localhost:${PORT_INTERNAL}/say?text=Nice%20demo%21'"

echo "$CMD"

RESULT=$(eval "$CMD")

echo "$RESULT"

echo "$RESULT" | grep Nice > /dev/null

if [ $? -eq 0 ]; then
	echo ""
	echo "Test2 succeeded"
else
	echo ""
	echo "Test2 failed"
fi
echo ""
