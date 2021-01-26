#!/bin/bash

IMAGE_NAME=rawkintrevo/clone-covid-data
IMAGE_TAG=0.3.1

docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
docker push ${IMAGE_NAME}:${IMAGE_TAG}
