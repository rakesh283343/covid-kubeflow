#!/bin/bash

IMAGE_NAME=rawkintrevo/blog-writer-covid-data
IMAGE_TAG=0.3.4

docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
docker push ${IMAGE_NAME}:${IMAGE_TAG}
