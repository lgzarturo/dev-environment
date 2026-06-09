#!/usr/bin/env zsh

__PROD_KEYS_FILE=$(mktemp)

# aws eks update-kubeconfig --name revenatium-prod-cluster

# ssh -i "~/.ssh/itermotus.pem" -D 1080 -N ec2-user@54.196.6.251

aws sts assume-role --role-arn arn:aws:iam::623842294996:role/AWSEKSProdDeveloperRole --role-session-name revenatium-prod-cluster --profile default > $__PROD_KEYS_FILE

aws configure --profile production set aws_access_key_id $(cat $__PROD_KEYS_FILE | jq -r '.Credentials.AccessKeyId')

aws configure --profile production set aws_secret_access_key $(cat $__PROD_KEYS_FILE | jq -r '.Credentials.SecretAccessKey')

aws configure --profile production set aws_session_token $(cat $__PROD_KEYS_FILE | jq -r '.Credentials.SessionToken')

aws eks update-kubeconfig --name revenatium-prod-cluster --profile production

echo $(cat $__PROD_KEYS_FILE | jq -r '.Credentials.Expiration')

# export HTTPS_PROXY="socks5://localhost:1080"

ssh -i "~/.ssh/itermotus.pem" -D 1080 -N ec2-user@54.196.6.251
