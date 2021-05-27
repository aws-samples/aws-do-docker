#!/bin/sh

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

# Unit test 2

CMD="curl -i -s -XPOST 'http://localhost:8080/2015-03-31/functions/function/invocations' -d '{\"text\": \"DockerCon 2021 demo!\"}'"

echo "$CMD"

RESULT=$(eval "$CMD")

echo "$RESULT"

echo "$RESULT" | grep DockerCon > /dev/null

if [ $? -eq 0 ]; then
	echo ""
	echo "Test2 succeeded"
else
	echo ""
	echo "Test2 failed"
fi
echo ""
