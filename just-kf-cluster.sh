#!/bin/bash

export CLONE_DIR=$HOME/covid-kubeflow
export REGION=us-east1
export ZONE=us-east1-b
export EMAIL=trevor.d.grant@gmail.com
export PROJECT_NUMBER=565570946662
export CLIENT_ID=565570946662-1b990vogug96v16pg55sn2oa9vk5jpql.apps.googleusercontent.com
export CLIENT_SECRET=U0Y7ewXBXMsAxIHakKrZ8kl8
export PROJECT_ID=covid-kf



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
mv $KF_DIR/Makefile $KF_DIR/Makefile.bu
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
# remember to add https:// ahead of it or it will keep 404ing even thought its up
# can take ~20 min

## turn on autoscaling on both clusters

#gcloud container clusters update covid-kf --enable-autoscaling \
#    --min-nodes 0 --max-nodes 10 --zone $ZONE --node-pool default-pool
#
#gcloud container clusters update mgmt-covid-kf --enable-autoscaling \
#    --min-nodes 1 --max-nodes 2 --zone $ZONE --node-pool mgmt-covid-kf-pool
