######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

import json

def handler(event, context):

    print(f"event = {event}")
    response = { "Status": "Healthy" }

    if  "text" in event.keys(): 
        response ={ "Message": event['text'] }

    print(f"response = {response}")
    return response
