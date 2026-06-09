#!/usr/bin/env zsh

__STAGE_KEYS_FILE=$(mktemp)

# ssh -i "~/.ssh/itermotus.pem" -D 1080 -N ec2-user@ec2-35-173-138-204.compute-1.amazonaws.com

aws sts assume-role --role-arn arn:aws:iam::623842294996:role/AWSEKSDeveloperRole --role-session-name stage-cluster > $__STAGE_KEYS_FILE

aws configure --profile stage set aws_access_key_id $(cat $__STAGE_KEYS_FILE | jq -r '.Credentials.AccessKeyId')

aws configure --profile stage set aws_secret_access_key $(cat $__STAGE_KEYS_FILE | jq -r '.Credentials.SecretAccessKey')

aws configure --profile stage set aws_session_token $(cat $__STAGE_KEYS_FILE | jq -r '.Credentials.SessionToken')

aws eks update-kubeconfig --name stage-cluster-v2 --profile stage

echo $(cat $__STAGE_KEYS_FILE | jq -r '.Credentials.Expiration')

#export HTTPS_PROXY="socks5://localhost:1080"

ssh -i "~/.ssh/itermotus.pem" -D 1080 -N ec2-user@35.173.138.204
