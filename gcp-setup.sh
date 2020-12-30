#!/bin/bash


if [ -z "$PROJECT_ID" ]
then
      echo "Please set \$PROJECT_ID and run again"
else
      curl --request POST \
        --header "Authorization: Bearer $(gcloud auth print-access-token)" \
        --data '' \
        https://meshconfig.googleapis.com/v1alpha1/projects/${PROJECT_ID}:initialize
fi

gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  iam.googleapis.com \
  servicemanagement.googleapis.com \
  cloudresourcemanager.googleapis.com \
  ml.googleapis.com \
  meshconfig.googleapis.com
  
  
