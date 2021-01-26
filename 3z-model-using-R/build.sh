#!/bin/bash

IMAGE_NAME=rawkintrevo/model-lm-covid-data
IMAGE_TAG=0.1

docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
docker push ${IMAGE_NAME}:${IMAGE_TAG}
