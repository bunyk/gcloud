#!/usr/bin/env bash

for_each_cluster() {
    CLUSTER_STATE_URI=${CLUSTER_STATE_URI:-gs://sixty-sre-cluster-state/clusters}
    if [ -z "$CLUSTER_STATE_URI" ];then
        echo "error: CLUSTER_STATE_URI is not set"
        exit 1
    fi

    if [ -z "$DEPLOYMENT_CREDENTIALS" ];then
        echo "error: DEPLOYMENT_CREDENTIALS is not set to b64 encoded service account"
        exit 1
    fi

    echo "Activating service account"
    echo "$DEPLOYMENT_CREDENTIALS" | base64 --decode > "$HOME"/google-application-credentials.json
    gcloud auth activate-service-account --key-file="$HOME"/google-application-credentials.json && \
      rm -f "$HOME"/google-application-credentials.json || \
      rm -f "$HOME"/google-application-credentials.json

    cluster_file=`mktemp`
    gsutil cp $CLUSTER_STATE_URI $cluster_file
    errs=0
    export CLUSTER_INDEX=0
    export CLUSTER_RANK=0
    while read CLUSTER_RANK cluster project region; do
        auth_for_cluster $project $region $cluster
        for cmd in $*;do
            echo "================================================="
            echo "Executing '$cmd' for $CLUSTER_INDEX:$project/$region/$cluster"
            if ! $cmd;then
                echo "ERROR: FAILED! Abandoning run for cluster"
                errs=`expr $errs + 1`
                break
            fi
            echo "================================================="
        done
        CLUSTER_INDEX=`expr $CLUSTER_INDEX + 1`
    done < $cluster_file
    rm $cluster_file
    return $errs
}

auth_for_cluster() {
    project=$1
    region=$2
    cluster=$3
    echo Authenticating for cluster $project/$region/$cluster

    if [ ! -z "$GITLAB_CI" ]; then
        gcloud config set project "$project"
        gcloud container clusters get-credentials "$cluster" \
            --region "$region" \
            --project "$project"
    else
        echo "Running locally, skipping authentication"
    fi
}
