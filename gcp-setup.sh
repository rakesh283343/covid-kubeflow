#!/bin/bash

if [ -z "$REGION" ]
      echo "Please set \$REGION and run again"
      exit 1
fi

if 

if [ -z "$PROJECT_ID" ]
then
      echo "Please set \$PROJECT_ID and run again"
      exit 1
fi
      curl --request POST \
        --header "Authorization: Bearer $(gcloud auth print-access-token)" \
        --data '' \
        https://meshconfig.googleapis.com/v1alpha1/projects/${PROJECT_ID}:initialize
        MGMT_PROJECT=${PROJECT_ID}
fi

gcloud config set project $PROJECT_ID

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
#   --region=${REGION}
#
# gcloud beta container clusters delete tmp-cluster --region=${REGION}
#
# Had lots of 
# > Insufficient regional quota to satisfy request: resource # > "IN_USE_ADDRESSES": request requires '9.0' and is short '1.0'. project has a quota of 
# > '8.0' with '8.0' available. View and manage quotas at https://console.cloud.google.com/iam-admin/quotas?usage=USED&project=covid-kf.` 
#
# Just kept changin regions till one worker /shrug

curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
mv ./kustomize ~/.local/bin/kustomize

## Warno: Max v is 2.4.1
wget https://github.com/mikefarah/yq/releases/download/2.4.1/yq_linux_amd64 -O $HOME/.local/bin/yq &&\
    chmod +x $HOME/.local/bin/yq
    
PATH=$HOME/.local/bin:$PATH

MGMT_NAME="mgmt-${PROJECT_ID}"
# ^^ Should check if 
#     start with a lowercase letter
#     only contain lowercase letters, numbers and -
#     end with a number or a letter
#     contain no more than 18 characters

LOCATION=${REGION}
MGMT_DIR=${HOME}/kf-deployments/${MGMT_NAME}
mkdir -p $MGMT_DIR


kpt pkg get https://github.com/kubeflow/gcp-blueprints.git/management@v1.2.0 "${MGMT_DIR}"
cd "${MGMT_DIR}/management"
make get-pkg
kpt cfg set -R . name "${MGMT_NAME}"
kpt cfg set -R . gcloud.core.project "${MGMT_PROJECT}"
kpt cfg set -R . location "${LOCATION}"

make apply-cluster
make create-context
make apply-kcc

kpt cfg set ./instance managed-project "${PROJECT_ID}"


