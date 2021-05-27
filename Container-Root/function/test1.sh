#!/bin/sh

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

# Unit test 1

CMD="curl -i -s -XPOST 'http://localhost:8080/2015-03-31/functions/function/invocations' -d '{}'"

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
