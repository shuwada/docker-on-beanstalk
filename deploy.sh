#!/bin/bash

# Name of the application. $APP + timestamp will be Beanstalk application name.
APP=myapp

# S3 bucket and key of Dockerrun.aws.json file to use. The object must be
# accessible with the Instance Profile specified in 'IamInstanceProfile' of
# 'aws elasticbeanstalk create-environment' below. If the object is in public,
# no Instance Policy is required.
BUNDLE_BUCKET=mybucket
BUNDLE_KEY=Dockerrun.aws.json

# Must match with the solution name returned by 'aws elasticbeanstalk list-available-solution-stacks'
SOLUTION_STACK="64bit Amazon Linux 2015.03 v1.4.0 running Docker 1.6.0"

# Instance type. Should be reasonably large to run a container.
INSTANCE_TYPE="m1.large"


# ---------- main ----------
set -e

TIMESTAMP="$(date +%m%d%H%M)"
APP_NAME="$APP-$TIMESTAMP"
APP_VERSION="$TIMESTAMP"
ENV_NAME="env-$APP-$TIMESTAMP"
CNAME="$APP-$TIMESTAMP"

log() {
  echo "[$(date +"%T")] $1"
}

# Create a new application and the environment
log "Creating a new Beanstalk applicaiton $APP_NAME from s3://$BUNDLE_BUCKET/$BUNDLE_KEY"
aws elasticbeanstalk create-application \
  --application-name $APP_NAME \
  --description $APP_NAME
aws elasticbeanstalk create-application-version \
  --application-name $APP_NAME \
  --version-label $APP_VERSION \
  --source-bundle S3Bucket=$BUNDLE_BUCKET,S3Key=$BUNDLE_KEY

# Run 'aws elasticbeanstalk describe-configuration-settings' to see the list of available options
log "Creating a new Beanstalk environment $ENV_NAME for the new application"
aws elasticbeanstalk create-environment \
  --application-name $APP_NAME \
  --version-label $APP_VERSION \
  --environment-name $ENV_NAME \
  --cname-prefix $CNAME \
  --solution-stack-name "$SOLUTION_STACK" \
  --option-settings \
    Namespace=aws:autoscaling:launchconfiguration,OptionName=InstanceType,Value=$INSTANCE_TYPE \
    Namespace=aws:elasticbeanstalk:environment,OptionName=EnvironmentType,Value=SingleInstance \
    # Namespace=aws:autoscaling:launchconfiguration,OptionName=IamInstanceProfile,Value=aws-elasticbeanstalk-ec2-role

log "Waiting for the new Beanstalk environment ready"

while [ "$status" != "Ready" ]
do
  status=$(aws elasticbeanstalk describe-environments --environment-names $ENV_NAME --output text | grep ENVIRONMENTS | cut -f11)
  log "Current status ... $status"
  sleep 10
done

url=$(aws elasticbeanstalk describe-environments --environment-names $ENV_NAME --output text | grep ENVIRONMENTS | cut -f3)
log "$APP is ready at $url"

