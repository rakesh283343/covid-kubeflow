#!/bin/bash


if [ -z "$PROJECT_ID" ]
then
      echo "Please set \$PROJECT_ID and run again"
      exit 1
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
  
  
# IF above errors with `Identity Pool does not exist ...` try :  
# per: https://github.com/kubeflow/website/issues/2121
# gcloud beta container clusters create tmp-cluster \
#   --release-channel regular \
#   --workload-pool=${PROJECT_ID}.svc.id.goog \
#   --region=us-east1-b
#
# gcloud beta container clusters delete tmp-cluster --region=us-east1-b
#
# Had lots of 
# > Insufficient regional quota to satisfy request: resource # > "IN_USE_ADDRESSES": request requires '9.0' and is short '1.0'. project has a quota of 
# > '8.0' with '8.0' available. View and manage quotas at https://console.cloud.google.com/iam-admin/quotas?usage=USED&project=covid-kf.` 
#
# Just kept changin regions till one worker /shrug
