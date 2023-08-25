#!/bin/bash
# 
# Copyright 2019-2021 Shiyghan Navti. Email shiyghan@techequity.company
#
#################################################################################
############           Explore Cloud Run Application                #############
#################################################################################

# User prompt function
function ask_yes_or_no() {
    read -p "$1 ([y]yes to preview, [n]o to create, [d]del to delete): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        n|no)  echo "no" ;;
        d|del) echo "del" ;;
        *)     echo "yes" ;;
    esac
}

function ask_yes_or_no_proj() {
    read -p "$1 ([y]es to change, [n]o to skip): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

clear
MODE=1
export TRAINING_ORG_ID=$(gcloud organizations list --format 'value(ID)' --filter="displayName:techequity.training" 2>/dev/null)
export ORG_ID=$(gcloud projects get-ancestors $GCP_PROJECT --format 'value(ID)' 2>/dev/null | tail -1 )
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)  

echo
echo
echo -e "                        👋  Welcome to Cloud Sandbox! 💻"
echo 
echo -e "              *** PLEASE WAIT WHILE LAB UTILITIES ARE INSTALLED ***"
sudo apt-get -qq install pv > /dev/null 2>&1
echo 
export SCRIPTPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

mkdir -p `pwd`/gcp-cloudrun-glb > /dev/null 2>&1
export PROJDIR=`pwd`/gcp-cloudrun-glb
export SCRIPTNAME=gcp-cloudrun-glb.sh

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT # set GCP project
export GCP_REGION=europe-west1 # set deployment region
export APP_NAME=helloworld # set application name
# export APP_DOMAIN=domain.com # for development, comment out this variable. Default value is \$EXT_IP.nip.io
export APP_INSTANCES=3 # set max number of instances
export APP_IMAGE_URL=gcr.io/google-samples/hello-app:1.0 # set full image URL
export APP_RELEASE=release1 # set release name
export APP_TRAFFIC=100 # set traffic distribution percentage
EOF
source $PROJDIR/.env
fi

# Display menu options
while :
do
clear
cat<<EOF
================================================
Configure CloudRun $APP_NAME Application
------------------------------------------------
Please enter number to select your choice:
 (1) Enable APIs
 (2) Deploy application
 (3) Configure IAM policies
 (4) Update traffic distribution
 (5) Enable access via Global Load Balancer 
 (6) Enable access via Global Load Balancer with Cloud CDN 
 (7) Enable access via Global Load Balancer with Cloud Armor 
 (G) Launch user guide
 (Q) Quit
-----------------------------------------------------------------------------
EOF
echo "Steps performed${STEP}"
echo
echo "What additional step do you want to perform, e.g. enter 0 to select the execution mode?"
read
clear
case "${REPLY^^}" in

"0")
start=`date +%s`
source $PROJDIR/.env
echo
echo "Do you want to run script in preview mode?"
export ANSWER=$(ask_yes_or_no "Are you sure?")
cd $HOME
if [[ ! -z "$TRAINING_ORG_ID" ]]  &&  [[ $ORG_ID == "$TRAINING_ORG_ID" ]]; then
    export STEP="${STEP},0"
    MODE=1
    if [[ "yes" == $ANSWER ]]; then
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    else 
        if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
            echo 
            echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
            echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
        else
            while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                echo 
                echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                gcloud auth login  --brief --quiet
                export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                if [[ $ACCOUNT != "" ]]; then
                    echo
                    echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                    read GCP_PROJECT
                    gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                    sleep 3
                    export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                fi
            done
            gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
            sleep 2
            gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
            gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
            gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
        fi
        export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
        cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT # set GCP project
export GCP_REGION=$GCP_REGION # set deployment region
export APP_NAME=$APP_NAME # set application name
# export APP_DOMAIN=$APP_DOMAIN # for development, comment out this variable. Default value is \$EXT_IP.nip.io
export APP_INSTANCES=$APP_INSTANCES # set max number of instances
export APP_IMAGE_URL=$APP_IMAGE_URL # set full image URL
export APP_RELEASE=$APP_RELEASE # set release name
export APP_TRAFFIC=$APP_TRAFFIC # set traffic distribution percentage
EOF
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
        echo "*** Application name is $APP_NAME ***" | pv -qL 100
        echo "*** Application domain is ${APP_DOMAIN:=\$EXT_IP.nip.io} ***" | pv -qL 100
        echo "*** Application max instances is ${APP_INSTANCES} ***" | pv -qL 100
        echo "*** Application image URL is $APP_IMAGE_URL ***" | pv -qL 100
        echo "*** Application release is $APP_RELEASE ***" | pv -qL 100
        echo "*** Application traffic percentage is $APP_TRAFFIC ***" | pv -qL 100
        echo
        echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
        echo "*** $PROJDIR/.env ***" | pv -qL 100
        if [[ "no" == $ANSWER ]]; then
            MODE=2
            echo
            echo "*** Create mode is active ***" | pv -qL 100
        elif [[ "del" == $ANSWER ]]; then
            export STEP="${STEP},0"
            MODE=3
            echo
            echo "*** Resource delete mode is active ***" | pv -qL 100
        fi
    fi
else 
    if [[ "no" == $ANSWER ]] || [[ "del" == $ANSWER ]] ; then
        export STEP="${STEP},0"
        if [[ -f $SCRIPTPATH/.${SCRIPTNAME}.secret ]]; then
            echo
            unset password
            unset pass_var
            echo -n "Enter access code: " | pv -qL 100
            while IFS= read -p "$pass_var" -r -s -n 1 letter
            do
                if [[ $letter == $'\0' ]]
                then
                    break
                fi
                password=$password"$letter"
                pass_var="*"
            done
            while [[ -z "${password// }" ]]; do
                unset password
                unset pass_var
                echo
                echo -n "You must enter an access code to proceed: " | pv -qL 100
                while IFS= read -p "$pass_var" -r -s -n 1 letter
                do
                    if [[ $letter == $'\0' ]]
                    then
                        break
                    fi
                    password=$password"$letter"
                    pass_var="*"
                done
            done
            export PASSCODE=$(cat $SCRIPTPATH/.${SCRIPTNAME}.secret | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$password 2> /dev/null)
            if [[ $PASSCODE == 'AccessVerified' ]]; then
                MODE=2
                echo && echo
                echo "*** Access code is valid ***" | pv -qL 100
                if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
                    echo 
                    echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
                    echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
                else
                    while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                        echo 
                        echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                        gcloud auth login  --brief --quiet
                        export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                        if [[ $ACCOUNT != "" ]]; then
                            echo
                            echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                            read GCP_PROJECT
                            gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                            sleep 3
                            export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                        fi
                    done
                    gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
                    sleep 2
                    gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
                    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
                    gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
                    gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
                fi
                export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
                cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT # set GCP project
export GCP_REGION=$GCP_REGION # set deployment region
export APP_NAME=$APP_NAME # set application name
# export APP_DOMAIN=$APP_DOMAIN # for development, comment out this variable. Default value is \$EXT_IP.nip.io
export APP_INSTANCES=$APP_INSTANCES # set max number of instances
export APP_IMAGE_URL=$APP_IMAGE_URL # set full image URL
export APP_RELEASE=$APP_RELEASE # set release name
export APP_TRAFFIC=$APP_TRAFFIC # set traffic distribution percentage
EOF
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
                echo "*** Application name is $APP_NAME ***" | pv -qL 100
                echo "*** Application domain is ${APP_DOMAIN:=\$EXT_IP.nip.io} ***" | pv -qL 100
                echo "*** Application max instances is $APP_INSTANCES ***" | pv -qL 100
                echo "*** Application image URL is $APP_IMAGE_URL ***" | pv -qL 100
                echo "*** Application release is $APP_RELEASE ***" | pv -qL 100
                echo "*** Application traffic percentage is $APP_TRAFFIC ***" | pv -qL 100
                echo
                echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
                echo "*** $PROJDIR/.env ***" | pv -qL 100
                if [[ "no" == $ANSWER ]]; then
                    MODE=2
                    echo
                    echo "*** Create mode is active ***" | pv -qL 100
                elif [[ "del" == $ANSWER ]]; then
                    export STEP="${STEP},0"
                    MODE=3
                    echo
                    echo "*** Resource delete mode is active ***" | pv -qL 100
                fi
            else
                echo && echo
                echo "*** Access code is invalid ***" | pv -qL 100
                echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
                echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
                echo
                echo "*** Command preview mode is active ***" | pv -qL 100
            fi
        else
            echo
            echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
            echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
            echo
            echo "*** Command preview mode is active ***" | pv -qL 100
        fi
    else
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    fi
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"1")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},1i"
    echo
    echo "$ gcloud services enable container.googleapis.com compute.googleapis.com cloudresourcemanager.googleapis.com run.googleapis.com --project \$GCP_PROJECT # to enable APIs" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "$ gcloud services enable container.googleapis.com compute.googleapis.com cloudresourcemanager.googleapis.com run.googleapis.com --project $GCP_PROJECT # to enable APIs" | pv -qL 100
    gcloud services enable container.googleapis.com compute.googleapis.com cloudresourcemanager.googleapis.com run.googleapis.com --project $GCP_PROJECT
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},1i"
    echo
    echo "1. Enable APIs" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"2")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},2i"        
    echo
    echo "$ gcloud beta run deploy \$APP_NAME --platform managed --region \$GCP_REGION --allow-unauthenticated --image \$APP_IMAGE_URL --max-instances=\$APP_INSTANCES --tag \$APP_RELEASE # to run appication" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},2"        
    echo
    echo "$ gcloud beta run deploy $APP_NAME --platform managed --region $GCP_REGION --allow-unauthenticated --image $APP_IMAGE_URL --max-instances=$APP_INSTANCES --tag $APP_RELEASE # to run appication" | pv -qL 100
    gcloud beta run deploy $APP_NAME --platform managed --region $GCP_REGION --allow-unauthenticated --image $APP_IMAGE_URL --max-instances=$APP_INSTANCES --tag $APP_RELEASE 
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},2x"        
    echo
    echo "$ gcloud beta run services delete $APP_NAME --platform managed --region $GCP_REGION --quiet # to delete services" | pv -qL 100
    gcloud beta run services delete $APP_NAME --platform managed --region $GCP_REGION --quiet
else
    export STEP="${STEP},2i"
    echo
    echo "1. Deploy and run service" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"3")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},3i"
    echo
    echo "$ gcloud beta run services add-iam-policy-binding \$APP_NAME --platform managed --region \$GCP_REGION --member=user:\$(gcloud config get-value core/account) --role roles/run.admin # to set role" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "$ gcloud beta run services add-iam-policy-binding $APP_NAME --platform managed --region $GCP_REGION --member=user:\$(gcloud config get-value core/account) --role roles/run.admin # to set role" | pv -qL 100
    gcloud beta run services add-iam-policy-binding $APP_NAME --platform managed --region $GCP_REGION --member=user:$(gcloud config get-value core/account) --role roles/run.admin
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x"
    echo
    echo "$ export USER=\$(gcloud config get-value core/account) # to set user" | pv -qL 100
    export USER=$(gcloud config get-value core/account)
    echo
    echo "$ gcloud beta run services remove-iam-policy-binding $APP_NAME --platform managed --region $GCP_REGION --member=user:$USER --role roles/run.admin # to set role" | pv -qL 100
    gcloud beta run services remove-iam-policy-binding $APP_NAME --platform managed --region $GCP_REGION --member=user:$USER --role roles/run.admin
else
    export STEP="${STEP},3i"
    echo
    echo "1. Grant admin privileges to the user" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"4")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},4i"        
    echo
    echo "$ gcloud beta run services --platform managed --region \$GCP_REGION update-traffic \$APP_NAME --to-tags $APP_RELEASE=$APP_TRAFFIC # to update traffic" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},4"        
    echo
    echo "$ gcloud beta run services --platform managed --region $GCP_REGION update-traffic $APP_NAME --to-tags $APP_RELEASE=$APP_TRAFFIC # to update traffic" | pv -qL 100
    gcloud beta run services --platform managed --region $GCP_REGION update-traffic $APP_NAME --to-tags $APP_RELEASE=$APP_TRAFFIC
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},4x"        
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},4i"
    echo
    echo "1. Update traffic distribution" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"5")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},5i"   
    echo
    echo "$ gcloud beta run services update \$APP_NAME --platform managed --region \$GCP_REGION --ingress=internal-and-cloud-load-balancing # to update ingress" | pv -qL 100
    echo
    echo "$ gcloud compute addresses create --global \${APP_NAME}-ip # create static IP address" | pv -qL 100
    echo
    echo "$ gcloud compute network-endpoint-groups create \${APP_NAME}-neg --region=\$GCP_REGION --network-endpoint-type=serverless --cloud-run-service=\$APP_NAME # to create serverless NEG" | pv -qL 100
    echo
    echo "$ gcloud compute backend-services create \${APP_NAME}-service --load-balancing-scheme=EXTERNAL --global # to create backend service" | pv -qL 100
    echo
    echo "$ gcloud compute backend-services add-backend \${APP_NAME}-service --network-endpoint-group=\${APP_NAME}-neg --network-endpoint-group-region=\$GCP_REGION --global # to add serverless NEG to backend service" | pv -qL 100
    echo
    echo "$ gcloud compute url-maps create \${APP_NAME}-url-map --default-service \${APP_NAME}-service # to create URL map" | pv -qL 100
    echo
    echo "$ gcloud beta compute ssl-certificates create \${APP_NAME}-cert --domains \$APP_DOMAIN # to create managed SSL cert" | pv -qL 100
    echo
    echo "$ gcloud compute target-https-proxies create \${APP_NAME}-https-proxy --ssl-certificates=\${APP_NAME}-cert --url-map=\${APP_NAME}-url-map # to create target HTTPS proxy" | pv -qL 100
    echo
    echo "$ gcloud compute forwarding-rules create \${APP_NAME}-fwd-rule --target-https-proxy=\${APP_NAME}-https-proxy --global --ports=443 --address=\${APP_NAME}-ip # to create forwarding rules" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},5"
    echo
    echo "$ gcloud beta run services update $APP_NAME --platform managed --region $GCP_REGION --ingress=internal-and-cloud-load-balancing # to update ingress" | pv -qL 100
    gcloud beta run services update $APP_NAME --platform managed --region $GCP_REGION --ingress=internal-and-cloud-load-balancing
    echo
    echo "$ gcloud compute addresses create --global ${APP_NAME}-ip # create static IP address" | pv -qL 100
    gcloud compute addresses create --global ${APP_NAME}-ip
    echo
    sleep 10 # wait 10 seconds
    echo "$ export EXT_IP=\$(gcloud compute addresses describe ${APP_NAME}-ip --global --format=\"value(address)\") # to set IP" | pv -qL 100
    export EXT_IP=$(gcloud compute addresses describe ${APP_NAME}-ip --global --format="value(address)")
    echo
    echo "$ gcloud compute network-endpoint-groups create ${APP_NAME}-neg --region=$GCP_REGION --network-endpoint-type=serverless --cloud-run-service=$APP_NAME # to create serverless NEG" | pv -qL 100
    gcloud compute network-endpoint-groups create ${APP_NAME}-neg --region=$GCP_REGION --network-endpoint-type=serverless --cloud-run-service=${APP_NAME}
    echo
    echo "$ gcloud compute backend-services create ${APP_NAME}-service --load-balancing-scheme=EXTERNAL --global # to create backend service" | pv -qL 100
    gcloud compute backend-services create ${APP_NAME}-service --load-balancing-scheme=EXTERNAL --global
    echo
    echo "$ gcloud compute backend-services add-backend ${APP_NAME}-service --network-endpoint-group=${APP_NAME}-neg --network-endpoint-group-region=$GCP_REGION --global # to add serverless NEG to backend service" | pv -qL 100
    gcloud compute backend-services add-backend ${APP_NAME}-service --network-endpoint-group=${APP_NAME}-neg --network-endpoint-group-region=$GCP_REGION --global
    echo
    echo "$ gcloud compute url-maps create ${APP_NAME}-url-map --default-service ${APP_NAME}-service # to create URL map" | pv -qL 100
    gcloud compute url-maps create ${APP_NAME}-url-map --default-service ${APP_NAME}-service
    echo
    if [[ -z "$APP_DOMAIN" ]] ; then
        export DOMAIN=$EXT_IP.nip.io
    else 
        export DOMAIN=$APP_DOMAIN
    fi
    echo "$ gcloud beta compute ssl-certificates create ${APP_NAME}-cert --domains $DOMAIN # to create managed SSL cert" | pv -qL 100
    gcloud beta compute ssl-certificates create ${APP_NAME}-cert --domains $DOMAIN
    echo
    echo "$ gcloud compute target-https-proxies create ${APP_NAME}-https-proxy --ssl-certificates=${APP_NAME}-cert --url-map=${APP_NAME}-url-map # to create target HTTPS proxy" | pv -qL 100
    gcloud compute target-https-proxies create ${APP_NAME}-https-proxy --ssl-certificates=${APP_NAME}-cert --url-map=${APP_NAME}-url-map
    echo
    echo "$ gcloud compute forwarding-rules create ${APP_NAME}-fwd-rule --target-https-proxy=${APP_NAME}-https-proxy --global --ports=443 --address=${APP_NAME}-ip # to create forwarding rules" | pv -qL 100
    gcloud compute forwarding-rules create ${APP_NAME}-fwd-rule --target-https-proxy=${APP_NAME}-https-proxy --global --ports=443 --address=${APP_NAME}-ip
    echo
    echo "*** Wait 10-15 minutes until cert provisions and run command \"curl https://$DOMAIN\" to verify app is running ***" | pv -qL 100
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},5x"
    echo
    echo "$ gcloud compute forwarding-rules delete ${APP_NAME}-fwd-rule --global # to delete forwarding rules" | pv -qL 100
    gcloud compute forwarding-rules delete ${APP_NAME}-fwd-rule --global 
    echo
    echo "$ gcloud compute target-https-proxies delete ${APP_NAME}-https-proxy # to delete target HTTPS proxy" | pv -qL 100
    gcloud compute target-https-proxies delete ${APP_NAME}-https-proxy
    echo
    echo "$ gcloud beta compute ssl-certificates delete ${APP_NAME}-cert # to delete managed SSL cert" | pv -qL 100
    gcloud beta compute ssl-certificates delete ${APP_NAME}-cert
    echo
    echo "$ gcloud compute url-maps delete ${APP_NAME}-url-map # to delete URL map" | pv -qL 100
    gcloud compute url-maps delete ${APP_NAME}-url-map
    echo
    echo "$ gcloud compute backend-services remove-backend ${APP_NAME}-service --network-endpoint-group=${APP_NAME}-neg --network-endpoint-group-region=$GCP_REGION --global # to remove serverless NEG to backend service" | pv -qL 100
    gcloud compute backend-services remove-backend ${APP_NAME}-service --network-endpoint-group=${APP_NAME}-neg --network-endpoint-group-region=$GCP_REGION --global
    echo
    echo "$ gcloud compute backend-services delete ${APP_NAME}-service --global # to delete backend service" | pv -qL 100
    gcloud compute backend-services delete ${APP_NAME}-service --global
    echo
    echo "$ gcloud compute network-endpoint-groups delete ${APP_NAME}-neg --region=$GCP_REGION # to delete serverless NEG" | pv -qL 100
    gcloud compute network-endpoint-groups delete ${APP_NAME}-neg --region=$GCP_REGION
    echo
    echo "$ gcloud compute addresses delete --global ${APP_NAME}-ip # to delete static IP address" | pv -qL 100
    gcloud compute addresses delete --global ${APP_NAME}-ip
else
    export STEP="${STEP},5i"
    echo
    echo " 1. Update ingress to accept traffic via load balancer" | pv -qL 100
    echo " 2. Create a global static IP address" | pv -qL 100
    echo " 3. Create serverless network endpoint group (NEG)" | pv -qL 100
    echo " 4. Create backend service" | pv -qL 100
    echo " 5. Add serverless NEG to backend service" | pv -qL 100
    echo " 6. Create URL map" | pv -qL 100
    echo " 7. Create managed SSL cert" | pv -qL 100
    echo " 8. Create target HTTPS proxy" | pv -qL 100
    echo " 9. Create forwarding rules" | pv -qL 100
    echo "10. Access service via the global load balancer" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"6")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},6i"   
    echo
    echo "$ gcloud beta run services update \$APP_NAME --platform managed --region \$GCP_REGION --ingress=internal-and-cloud-load-balancing # to update ingress" | pv -qL 100
    echo
    echo "$ gcloud compute addresses create --global \${APP_NAME}-ip # create static IP address" | pv -qL 100
    echo
    echo "$ gcloud compute network-endpoint-groups create \${APP_NAME}-neg --region=\$GCP_REGION --network-endpoint-type=serverless --cloud-run-service=\$APP_NAME # to create serverless NEG" | pv -qL 100
    echo
    echo "$ gcloud compute backend-services create \${APP_NAME}-service --load-balancing-scheme=EXTERNAL --global --enable-cdn --cache-mode=CACHE_All_STATIC  --custom-response-header='Cache-Status: {cdn_cache_status}' --custom-response-header='Cache-ID: {cdn_cache_id}' # to create backend service" | pv -qL 100
    echo
    echo "$ gcloud compute backend-services add-backend \${APP_NAME}-service --global --network-endpoint-group=\${APP_NAME}-neg --network-endpoint-group-region=\$GCP_REGION # to add serverless NEG to backend service" | pv -qL 100
    echo
    echo "$ gcloud compute url-maps create \${APP_NAME}-url-map --default-service \${APP_NAME}-service # to create URL map" | pv -qL 100
    echo
    echo "$ gcloud beta compute ssl-certificates create \${APP_NAME}-cert --domains \$APP_DOMAIN # to create managed SSL cert" | pv -qL 100
    echo
    echo "$ gcloud compute target-https-proxies create \${APP_NAME}-https-proxy --ssl-certificates=\${APP_NAME}-cert --url-map=\${APP_NAME}-url-map # to create target HTTPS proxy" | pv -qL 100
    echo
    echo "$ gcloud compute forwarding-rules create \${APP_NAME}-fwd-rule --target-https-proxy=\${APP_NAME}-https-proxy --global --ports=443 --address=\${APP_NAME}-ip # to create forwarding rules" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},6"
    echo
    echo "$ gcloud beta run services update $APP_NAME --platform managed --region $GCP_REGION --ingress=internal-and-cloud-load-balancing # to update ingress" | pv -qL 100
    gcloud beta run services update $APP_NAME --platform managed --region $GCP_REGION --ingress=internal-and-cloud-load-balancing
    echo
    echo "$ gcloud compute addresses create --global ${APP_NAME}-ip # create static IP address" | pv -qL 100
    gcloud compute addresses create --global ${APP_NAME}-ip
    echo
    sleep 10 # wait 10 seconds
    echo "$ export EXT_IP=\$(gcloud compute addresses describe ${APP_NAME}-ip --global --format=\"value(address)\") # to set IP" | pv -qL 100
    export EXT_IP=$(gcloud compute addresses describe ${APP_NAME}-ip --global --format="value(address)")
    echo
    echo "$ gcloud compute network-endpoint-groups create ${APP_NAME}-neg --region=$GCP_REGION --network-endpoint-type=serverless --cloud-run-service=$APP_NAME # to create serverless NEG" | pv -qL 100
    gcloud compute network-endpoint-groups create ${APP_NAME}-neg --region=$GCP_REGION --network-endpoint-type=serverless --cloud-run-service=${APP_NAME}
    echo
    echo "$ gcloud compute backend-services create ${APP_NAME}-service --load-balancing-scheme=EXTERNAL --global --enable-cdn --cache-mode=CACHE_All_STATIC --custom-response-header='Cache-Status: {cdn_cache_status}' --custom-response-header='Cache-ID: {cdn_cache_id}' # to create backend service" | pv -qL 100
    gcloud compute backend-services create ${APP_NAME}-service --load-balancing-scheme=EXTERNAL --global --enable-cdn --cache-mode=CACHE_All_STATIC --custom-response-header='Cache-Status: {cdn_cache_status}' --custom-response-header='Cache-ID: {cdn_cache_id}' 
    echo
    echo "$ gcloud compute backend-services add-backend ${APP_NAME}-service --global --network-endpoint-group=${APP_NAME}-neg --network-endpoint-group-region=$GCP_REGION # to add serverless NEG to backend service" | pv -qL 100
    gcloud compute backend-services add-backend ${APP_NAME}-service  --global --network-endpoint-group=${APP_NAME}-neg --network-endpoint-group-region=$GCP_REGION
    echo
    echo "$ gcloud compute url-maps create ${APP_NAME}-url-map --default-service ${APP_NAME}-service # to create URL map" | pv -qL 100
    gcloud compute url-maps create ${APP_NAME}-url-map --default-service ${APP_NAME}-service
    echo
    if [[ -z "$APP_DOMAIN" ]] ; then
        export DOMAIN=$EXT_IP.nip.io
    else 
        export DOMAIN=$APP_DOMAIN
    fi
    echo "$ gcloud beta compute ssl-certificates create ${APP_NAME}-cert --domains $DOMAIN # to create managed SSL cert" | pv -qL 100
    gcloud beta compute ssl-certificates create ${APP_NAME}-cert --domains $DOMAIN
    echo
    echo "$ gcloud compute target-https-proxies create ${APP_NAME}-https-proxy --ssl-certificates=${APP_NAME}-cert --url-map=${APP_NAME}-url-map # to create target HTTPS proxy" | pv -qL 100
    gcloud compute target-https-proxies create ${APP_NAME}-https-proxy --ssl-certificates=${APP_NAME}-cert --url-map=${APP_NAME}-url-map
    echo
    echo "$ gcloud compute forwarding-rules create ${APP_NAME}-fwd-rule --target-https-proxy=${APP_NAME}-https-proxy --global --ports=443 --address=${APP_NAME}-ip # to create forwarding rules" | pv -qL 100
    gcloud compute forwarding-rules create ${APP_NAME}-fwd-rule --target-https-proxy=${APP_NAME}-https-proxy --global --ports=443 --address=${APP_NAME}-ip
    echo
    echo "*** Wait 10-15 minutes until cert provisions and run command \"curl -v -o/dev/null -k -s 'https://$DOMAIN:443' --connect-to $DOMAIN:443:$EXT_IP:443\" to verify app is running ***" | pv -qL 100
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},6x"
    echo
    echo "$ gcloud compute forwarding-rules delete ${APP_NAME}-fwd-rule --global # to delete forwarding rules" | pv -qL 100
    gcloud compute forwarding-rules delete ${APP_NAME}-fwd-rule --global 
    echo
    echo "$ gcloud compute target-https-proxies delete ${APP_NAME}-https-proxy # to delete target HTTPS proxy" | pv -qL 100
    gcloud compute target-https-proxies delete ${APP_NAME}-https-proxy 
    echo
    echo "$ gcloud beta compute ssl-certificates delete ${APP_NAME}-cert # to delete managed SSL cert" | pv -qL 100
    gcloud beta compute ssl-certificates delete ${APP_NAME}-cert
    echo
    echo "$ gcloud compute url-maps delete ${APP_NAME}-url-map  # to delete URL map" | pv -qL 100
    gcloud compute url-maps delete ${APP_NAME}-url-map 
    echo
    echo "$ gcloud compute backend-services remove-backend ${APP_NAME}-service --global --network-endpoint-group=${APP_NAME}-neg --network-endpoint-group-region=$GCP_REGION # to remove serverless NEG to backend service" | pv -qL 100
    gcloud compute backend-services remove-backend ${APP_NAME}-service  --global --network-endpoint-group=${APP_NAME}-neg --network-endpoint-group-region=$GCP_REGION
    echo
    echo "$ gcloud compute backend-services delete ${APP_NAME}-service --global # to delete backend service" | pv -qL 100
    gcloud compute backend-services delete ${APP_NAME}-service --global  
    echo
    echo "$ gcloud compute network-endpoint-groups delete ${APP_NAME}-neg --region=$GCP_REGION # to delete serverless NEG" | pv -qL 100
    gcloud compute network-endpoint-groups delete ${APP_NAME}-neg --region=$GCP_REGION
    echo
    echo "$ gcloud compute addresses delete --global ${APP_NAME}-ip # to delete static IP address" | pv -qL 100
    gcloud compute addresses delete --global ${APP_NAME}-ip
else
    export STEP="${STEP},6i"
    echo
    echo " 1. Update ingress to accept traffic via load balancer" | pv -qL 100
    echo " 2. Create global static IP address" | pv -qL 100
    echo " 3. Create serverless network endpoint group (NEG)" | pv -qL 100
    echo " 4. Create backend service while enabling and configuring Cloud CDN" | pv -qL 100
    echo " 5. Add serverless NEG to backend service" | pv -qL 100
    echo " 6. Create URL map" | pv -qL 100
    echo " 7. Create managed SSL cert" | pv -qL 100
    echo " 8. Create target HTTPS proxy" | pv -qL 100
    echo " 9. Create forwarding rules" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"7")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},7i"
    echo
    echo "$ gcloud beta run services update \$APP_NAME --platform managed --region \$GCP_REGION --ingress=internal-and-cloud-load-balancing # to update ingress" | pv -qL 100
    echo
    echo "$ gcloud compute addresses create --global \${APP_NAME}-ip # create static IP address" | pv -qL 100
    echo
    echo "$ gcloud compute network-endpoint-groups create \${APP_NAME}-neg --region=\$GCP_REGION --network-endpoint-type=serverless --cloud-run-service=\$APP_NAME # to create serverless NEG" | pv -qL 100
    echo
    echo "$ gcloud compute backend-services create \${APP_NAME}-service --load-balancing-scheme=EXTERNAL --global # to create backend service" | pv -qL 100
    echo
    echo "$ gcloud compute backend-services add-backend \${APP_NAME}-service --network-endpoint-group=\${APP_NAME}-neg --network-endpoint-group-region=\$GCP_REGION --global # to add serverless NEG to backend service" | pv -qL 100
    echo
    echo "$ gcloud compute url-maps create \${APP_NAME}-url-map --default-service \${APP_NAME}-service # to create URL map" | pv -qL 100
    echo
    echo "$ gcloud beta compute ssl-certificates create \${APP_NAME}-cert --domains \$APP_DOMAIN # to create managed SSL cert" | pv -qL 100
    echo
    echo "$ gcloud compute target-https-proxies create \${APP_NAME}-https-proxy --ssl-certificates=\${APP_NAME}-cert --url-map=\${APP_NAME}-url-map # to create target HTTPS proxy" | pv -qL 100
    echo
    echo "$ gcloud compute forwarding-rules create \${APP_NAME}-fwd-rule --target-https-proxy=\${APP_NAME}-https-proxy --global --ports=443 --address=\${APP_NAME}-ip # to create forwarding rules" | pv -qL 100
    echo
    echo "$ gcloud compute security-policies create \${APP_NAME}-security-policy --description \"policy for internal test users\" # to create policies" | pv -qL 100
    echo
    echo "$ gcloud compute security-policies rules update 2147483647 --security-policy \${APP_NAME}-security-policy --action \"deny-502\" # to update default rules" | pv -qL 100
    echo
    echo "$ gcloud compute security-policies rules create 1000 --security-policy \${APP_NAME}-security-policy --description \"allow traffic from \$AUTHORIZED_NETWORK\" --src-ip-ranges \"\$AUTHORIZED_NETWORK\" --action \"allow\" # to restrict traffic to desired IP ranges" | pv -qL 100
    echo
    echo "$ gcloud compute backend-services update \${APP_NAME}-service --security-policy \${APP_NAME}-security-policy --global # to attach policy to backend service (one at a time)" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},7"
    echo
    echo "$ gcloud beta run services update $APP_NAME --platform managed --region $GCP_REGION --ingress=internal-and-cloud-load-balancing # to update ingress" | pv -qL 100
    gcloud beta run services update $APP_NAME --platform managed --region $GCP_REGION --ingress=internal-and-cloud-load-balancing
    echo
    echo "$ gcloud compute addresses create --global ${APP_NAME}-ip # create static IP address" | pv -qL 100
    gcloud compute addresses create --global ${APP_NAME}-ip
    echo
    sleep 10 # wait 10 seconds
    echo "$ export EXT_IP=\$(gcloud compute addresses describe ${APP_NAME}-ip --global --format=\"value(address)\") # to set IP" | pv -qL 100
    export EXT_IP=$(gcloud compute addresses describe ${APP_NAME}-ip --global --format="value(address)")
    echo
    echo "$ gcloud compute network-endpoint-groups create ${APP_NAME}-neg --region=$GCP_REGION --network-endpoint-type=serverless --cloud-run-service=$APP_NAME # to create serverless NEG" | pv -qL 100
    gcloud compute network-endpoint-groups create ${APP_NAME}-neg --region=$GCP_REGION --network-endpoint-type=serverless --cloud-run-service=${APP_NAME}
    echo
    echo "$ gcloud compute backend-services create ${APP_NAME}-service --load-balancing-scheme=EXTERNAL --global # to create backend service" | pv -qL 100
    gcloud compute backend-services create ${APP_NAME}-service --load-balancing-scheme=EXTERNAL --global
    echo
    echo "$ gcloud compute backend-services add-backend ${APP_NAME}-service --network-endpoint-group=${APP_NAME}-neg --network-endpoint-group-region=$GCP_REGION --global # to add serverless NEG to backend service" | pv -qL 100
    gcloud compute backend-services add-backend ${APP_NAME}-service --network-endpoint-group=${APP_NAME}-neg --network-endpoint-group-region=$GCP_REGION --global
    echo
    echo "$ gcloud compute url-maps create ${APP_NAME}-url-map --default-service ${APP_NAME}-service # to create URL map" | pv -qL 100
    gcloud compute url-maps create ${APP_NAME}-url-map --default-service ${APP_NAME}-service
    echo
    if [[ -z "$APP_DOMAIN" ]] ; then
        export DOMAIN=$EXT_IP.nip.io
    else 
        export DOMAIN=$APP_DOMAIN
    fi
    echo "$ gcloud beta compute ssl-certificates create ${APP_NAME}-cert --domains $DOMAIN # to create managed SSL cert" | pv -qL 100
    gcloud beta compute ssl-certificates create ${APP_NAME}-cert --domains $DOMAIN
    echo
    echo "$ gcloud compute target-https-proxies create ${APP_NAME}-https-proxy --ssl-certificates=${APP_NAME}-cert --url-map=${APP_NAME}-url-map # to create target HTTPS proxy" | pv -qL 100
    gcloud compute target-https-proxies create ${APP_NAME}-https-proxy --ssl-certificates=${APP_NAME}-cert --url-map=${APP_NAME}-url-map
    echo
    echo "$ gcloud compute forwarding-rules create ${APP_NAME}-fwd-rule --target-https-proxy=${APP_NAME}-https-proxy --global --ports=443 --address=${APP_NAME}-ip # to create forwarding rules" | pv -qL 100
    gcloud compute forwarding-rules create ${APP_NAME}-fwd-rule --target-https-proxy=${APP_NAME}-https-proxy --global --ports=443 --address=${APP_NAME}-ip
    export MANAGED_STATUS=$(gcloud compute ssl-certificates list --filter="managed.domains:$DOMAIN" --format 'value(MANAGED_STATUS)')
    echo
    while [[ "$MANAGED_STATUS" != "ACTIVE" ]]; do
        sleep 30
        echo "*** Managed SSL certificate status is $MANAGED_STATUS ***"
        export MANAGED_STATUS=$(gcloud compute ssl-certificates list --filter="managed.domains:$DOMAIN" --format 'value(MANAGED_STATUS)')
    done
    echo
    echo "$ gcloud compute security-policies create ${APP_NAME}-security-policy --description \"policy for internal test users\" # to create policies" | pv -qL 100
    gcloud compute security-policies create ${APP_NAME}-security-policy --description "policy for internal test users"
    echo
    echo "$ gcloud compute security-policies rules update 2147483647 --security-policy ${APP_NAME}-security-policy --action \"deny-502\" # to update default rules" | pv -qL 100
    gcloud compute security-policies rules update 2147483647 --security-policy ${APP_NAME}-security-policy --action "deny-502"
    export LOCALIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
    export AUTHORIZED_NETWORK=${LOCALIP}/32
    echo
    echo "$ gcloud compute security-policies rules create 1000 --security-policy ${APP_NAME}-security-policy --description \"allow traffic from $AUTHORIZED_NETWORK\" --src-ip-ranges \"$AUTHORIZED_NETWORK\" --action \"allow\" # to restrict traffic to desired IP ranges" | pv -qL 100
    gcloud compute security-policies rules create 1000 --security-policy ${APP_NAME}-security-policy --description "allow traffic from $AUTHORIZED_NETWORK" --src-ip-ranges "$AUTHORIZED_NETWORK" --action "allow"
    echo
    echo "$ gcloud compute backend-services update ${APP_NAME}-service --security-policy ${APP_NAME}-security-policy --global # to attach policy to backend service (one at a time)" | pv -qL 100
    gcloud compute backend-services update ${APP_NAME}-service --security-policy ${APP_NAME}-security-policy --global
    echo
    echo "$ export EXT_IP=\$(gcloud compute addresses describe ${APP_NAME}-ip --global --format=\"value(address)\") # to set IP" | pv -qL 100
    export EXT_IP=$(gcloud compute addresses describe ${APP_NAME}-ip --global --format="value(address)")
    echo
    export DOMAIN=${APP_DOMAIN:=$EXT_IP.nip.io}
    echo "*** Wait 10-15 minutes until policy propages and run command \"curl https://$DOMAIN\" to verify app is accessible ***" | pv -qL 100
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},7x"
    echo
    echo "$ gcloud compute security-policies rules delete 1000 --security-policy ${APP_NAME}-security-policy # to restrict traffic to desired IP ranges" | pv -qL 100
    gcloud compute security-policies rules delete 1000 --security-policy ${APP_NAME}-security-policy
    echo
    echo "$ gcloud compute forwarding-rules delete ${APP_NAME}-fwd-rule --global # to delete forwarding rules" | pv -qL 100
    gcloud compute forwarding-rules delete ${APP_NAME}-fwd-rule --global 
    echo
    echo "$ gcloud compute target-https-proxies delete ${APP_NAME}-https-proxy # to delete target HTTPS proxy" | pv -qL 100
    gcloud compute target-https-proxies delete ${APP_NAME}-https-proxy
    echo
    echo "$ gcloud beta compute ssl-certificates delete ${APP_NAME}-cert # to delete managed SSL cert" | pv -qL 100
    gcloud beta compute ssl-certificates delete ${APP_NAME}-cert
    echo
    echo "$ gcloud compute url-maps delete ${APP_NAME}-url-map # to delete URL map" | pv -qL 100
    gcloud compute url-maps delete ${APP_NAME}-url-map
    echo
    echo "$ gcloud compute backend-services remove-backend ${APP_NAME}-service --network-endpoint-group=${APP_NAME}-neg --network-endpoint-group-region=$GCP_REGION --global # to remove serverless NEG to backend service" | pv -qL 100
    gcloud compute backend-services remove-backend ${APP_NAME}-service --network-endpoint-group=${APP_NAME}-neg --network-endpoint-group-region=$GCP_REGION --global
    echo
    echo "$ gcloud compute backend-services delete ${APP_NAME}-service --global # to delete backend service" | pv -qL 100
    gcloud compute backend-services delete ${APP_NAME}-service --global
    echo
    echo "$ gcloud compute security-policies delete ${APP_NAME}-security-policy # to delete policies" | pv -qL 100
    gcloud compute security-policies delete ${APP_NAME}-security-policy
    echo
    echo "$ gcloud compute network-endpoint-groups delete ${APP_NAME}-neg --region=$GCP_REGION # to delete serverless NEG" | pv -qL 100
    gcloud compute network-endpoint-groups delete ${APP_NAME}-neg --region=$GCP_REGION
    echo
    echo "$ gcloud compute addresses delete --global ${APP_NAME}-ip # to delete static IP address" | pv -qL 100
    gcloud compute addresses delete --global ${APP_NAME}-ip
else
    export STEP="${STEP},7i"
    echo
    echo " 1. Update ingress to accept traffic via load balancer" | pv -qL 100
    echo " 2. Create global static IP address" | pv -qL 100
    echo " 3. Create serverless network endpoint group (NEG)" | pv -qL 100
    echo " 4. Create backend service" | pv -qL 100
    echo " 5. Add serverless NEG to backend service" | pv -qL 100
    echo " 6. Create URL map" | pv -qL 100
    echo " 7. Create managed SSL cert" | pv -qL 100
    echo " 8. Create target HTTPS proxy" | pv -qL 100
    echo " 9. Create forwarding rules" | pv -qL 100
    echo "10. Create web application firewall (WAF) policies" | pv -qL 100
    echo "11. Update default WAF rules" | pv -qL 100
    echo "12. Restrict traffic to a desired IP ranges" | pv -qL 100
    echo "13. Attach policy to backend service" | pv -qL 100
    echo "14. Confirm enforcement of the WAF rules" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"R")
echo
echo "
  __                      __                              __                               
 /|            /         /              / /              /                 | /             
( |  ___  ___ (___      (___  ___        (___           (___  ___  ___  ___|(___  ___      
  | |___)|    |   )     |    |   )|   )| |    \   )         )|   )|   )|   )|   )|   )(_/_ 
  | |__  |__  |  /      |__  |__/||__/ | |__   \_/       __/ |__/||  / |__/ |__/ |__/  / / 
                                 |              /                                          
"
echo "
We are a group of information technology professionals committed to driving cloud 
adoption. We create cloud skills development assets during our client consulting 
engagements, and use these assets to build cloud skills independently or in partnership 
with training organizations.
 
You can access more resources from our iOS and Android mobile applications.

iOS App: https://apps.apple.com/us/app/tech-equity/id1627029775
Android App: https://play.google.com/store/apps/details?id=com.techequity.app
 
Email:support@techequity.cloud 
Web: https://techequity.cloud

Ⓒ Tech Equity 2022" | pv -qL 100
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"G")
cloudshell launch-tutorial $SCRIPTPATH/.tutorial.md
;;

"Q")
echo
exit
;;
"q")
echo
exit
;;
* )
echo
echo "Option not available"
;;
esac
sleep 1
done
