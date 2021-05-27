#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

# Container startup script
echo "Container-Root/startup.sh executed"

# Start sample web api in background
PORT=80
if [ ! "$PORT_INTERNAL" == "" ]; then
	PORT=$PORT_INTERNAL
fi
cd /app
hypercorn server:app -b 0.0.0.0:${PORT} &

# Start sample ininite loop to produce periodic log output
while true; do date; sleep 10; done

