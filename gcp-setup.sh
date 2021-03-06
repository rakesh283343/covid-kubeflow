#!/bin/bash

if [ -z "$CLONE_DIR" ]
then
      echo "Please set \$CLONE_DIR and run again \n (Hint: it's probably this directory)"
      exit 1
fi 

echo "Found \$CLONE_DIR"

if [ -z "$REGION" ]
then
      #us-east1
      echo "Please set \$REGION and run again"
      exit 1
fi

echo "Found \$REGION"

if [ -z "$ZONE" ]
then
      #us-east1-b
      echo "Please set \$ZONE and run again"
fi

echo "\$ZONE: ${ZONE}"

if [ -z "$EMAIL" ]
then
      echo "Please set \$EMAIL so I can spam you and run again"
      exit 1
fi

echo "Found \$EMAIL ${EMAIL} get ready for spam!"

if [ -z "$PROJECT_NUMBER" ]
then
      echo "Please set \$PROJECT_NUMBER and run again"
      exit 1
fi

echo "PROJECT_NUMBER: ${PROJECT_NUMBER}"

if [ -z "$CLIENT_ID" ]
then
      echo "Please set \$CLIENT_ID and run again"
      exit 1
fi

echo "CLIENT_ID"

if [ -z "$CLIENT_SECRET" ]
then
      echo "Please set \$CLIENT_SECRET and run again"
      exit 1
fi

echo "CLIENT_SECRET"

if [ -z "$PROJECT_ID" ]
then
      echo "Please set \$PROJECT_ID and run again"
      exit 1
fi



export CLUSTER_LOCATION=$REGION
export CLUSTER_NAME=$PROJECT_ID
export KF_NAME=$PROJECT_ID
export KF_PROJECT=$PROJECT_ID #Careful here...
export KF_DIR=${HOME}/kf-deployments/${KF_NAME}
export LOCATION=${REGION}
export MESH_ID="proj-${PROJECT_NUMBER}"

export MGMT_NAME="mgmt-${PROJECT_ID}"
      # ^^ Should check if 
      #     start with a lowercase letter
      #     only contain lowercase letters, numbers and -
      #     end with a number or a letter
      #     contain no more than 18 characters
export MGMT_DIR=${HOME}/kf-deployments/${MGMT_NAME}
export MGMT_PROJECT=${PROJECT_ID}
export MGMTCTXT=$MGMT_NAME
export WORKLOAD_POOL=${PROJECT_ID}.svc.id.goog


 
      
echo "################### All ENV variables seem in order... #########################################"

curl --request POST \
  --header "Authorization: Bearer $(gcloud auth print-access-token)" \
  --data '' \
  https://meshconfig.googleapis.com/v1alpha1/projects/${PROJECT_ID}:initialize



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

echo "################### Let's Install Some Friends!    #############################################"

curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
mv ./kustomize ~/.local/bin/kustomize

## Warno: Max v is 2.4.1
wget https://github.com/mikefarah/yq/releases/download/2.4.1/yq_linux_amd64 -O $HOME/.local/bin/yq &&\
    chmod +x $HOME/.local/bin/yq

PATH=$HOME/.local/bin:$PATH

echo "################### Setting Up MGMT cluster, lol .Smh ##########################################"

if [ ! -d $MGMT_DIR ]
then
  echo "Creating ${MGMT_DIR}"
  mkdir -p $MGMT_DIR
fi

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
gcloud beta anthos apply ./instance/managed-project/iam.yaml

echo "################### Install Kubeflow the expensive way #########################################"
set -e

echo "Install istio-custom"
cd $HOME
curl -LO https://storage.googleapis.com/gke-release/asm/istio-1.4.10-asm.18-linux.tar.gz
tar xzf istio-1.4.10-asm.18-linux.tar.gz
mv istio-1.4.10-asm.18/bin/* $HOME/.local/bin


echo "apply manifest..."
## Permisive - for strict TLS see https://cloud.google.com/service-mesh/docs/archive/1.4/docs/gke-install-new-cluster#preparing_to_install_anthos_service_mesh
istioctl manifest apply --set profile=asm \
  --set values.global.trustDomain=${WORKLOAD_POOL} \
  --set values.global.sds.token.aud=${WORKLOAD_POOL} \
  --set values.nodeagent.env.GKE_CLUSTER_URL=https://container.googleapis.com/v1/projects/${PROJECT_ID}/locations/${CLUSTER_LOCATION}/clusters/${CLUSTER_NAME} \
  --set values.global.meshID=${MESH_ID} \
  --set values.global.proxy.env.GCP_METADATA="${PROJECT_ID}|${PROJECT_NUMBER}|${CLUSTER_NAME}|${CLUSTER_LOCATION}"

rm -rf ${KF_DIR}
kpt pkg get https://github.com/kubeflow/gcp-blueprints.git/kubeflow@v1.2.0 "${KF_DIR}"
cd "${KF_DIR}"

kpt cfg set ./instance mgmt-ctxt $MGMTCTXT #* ?
kubectl config use-context "${MGMTCTXT}"
kubectl create namespace "${KF_PROJECT}"

echo "################### It's the Final Count down... badadada dadadada #############################"

echo "Copying custom Makefile"
cp $CLONE_DIR/Makefile $KF_DIR/Makefile

echo "Setting values with make set-values"
make get-pkg
make set-values
# failed had to request more CPUs to run it
#failed at random a few times- had to keep kick starting it

echo "Getting ready to do a make apply"
cd "${KF_DIR}"
make apply

# things known to cause issues which require you simply to rerun `make apply`
# ... no matches for kind "Image" in version "caching.internal.knative.dev/v1alpha1"
# ... no matches for kind "Profile" in version "kubeflow.org/v1beta1"

echo "Then this"
gcloud container clusters get-credentials "${KF_NAME}" --zone "${REGION}" --project "${KF_PROJECT}"

echo "Generating login for ${EMAIL}"
gcloud projects add-iam-policy-binding "${KF_PROJECT}" --member=user:${EMAIL} --role=roles/iap.httpsResourceAccessor

echo "Cash me here"
kubectl -n istio-system get ingress

## turn on autoscaling on both clusters

#gcloud container clusters update covid-kf --enable-autoscaling \
#    --min-nodes 0 --max-nodes 10 --zone $ZONE --node-pool default-pool
#
#gcloud container clusters update mgmt-covid-kf --enable-autoscaling \
#    --min-nodes 1 --max-nodes 2 --zone $ZONE --node-pool mgmt-covid-kf-pool
