######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

# Simple REST API
from fastapi import FastAPI
import logging

global logger

logger = logging.getLogger()

app = FastAPI()

@app.get("/")
async def report_health():
        logger.warning("Received healthcheck request")
        r = {"Status": "Healthy"}
        logger.warning("Returning " + str(r))
        return r


@app.get("/say")
async def say_something(text: str = "Hello"):
        logger.warning("Received say request: " + text)
        r =  {"Message": text}
        logger.warning("Returning " + str(r))
        return r

