#!/bin/bash
# https://repost.aws/knowledge-center/authenticate-mfa-cli
#
# script to export the AWS credentials to an assumed role
# dorancemc@ 28.11.2023
#
# Before running this script, you need to have the following
# 1. aws cli installed and configured
# 3. aws profile configured with the following format
#    empty values are valid
# [default]
# aws_access_key_id=
# aws_secret_access_key=
# aws_session_token=
#

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  echo "Usage: $0 <aws_parent_profile> <aws_accoount_id> <aws_role> [aws_profile] [duration_seconds]"
  exit 1
fi

sed_escape() {
  echo "$1" | sed -e 's/[\/&]/\\&/g'
}

convert2localtime() {
  echo $(python3 -c "from dateutil import parser; print(parser.parse('$1').astimezone().strftime('%Y-%m-%d %H:%M:%S %Z'))")
}

aws_parent_profile="${1}"
aws_accoount_id="${2}"
aws_role="${3}"
aws_profile="${4:-default}"
duration_seconds="${5:-900}"

json_output=$( \
aws --profile ${aws_parent_profile} sts assume-role \
--role-arn arn:aws:iam::${aws_accoount_id}:role/${aws_role} \
--role-session-name ${aws_profile} \
--duration-seconds ${duration_seconds} \
)

if [ "$json_output" == "" ]; then
  echo "Error: Unable to get session token"
  exit 1
fi

export AWS_ACCESS_KEY_ID=$(echo "$json_output" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$json_output" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$json_output" | jq -r '.Credentials.SessionToken')

credentials_file="$HOME/.aws/credentials"
if [ -f "$credentials_file" ]; then
  sed -i "" -E "/^\[$aws_profile\]/,/^$/ { s/aws_access_key_id=.*/aws_access_key_id=$(sed_escape "$AWS_ACCESS_KEY_ID")/; s/aws_secret_access_key=.*/aws_secret_access_key=$(sed_escape "$AWS_SECRET_ACCESS_KEY")/; s/aws_session_token=.*/aws_session_token=$(sed_escape "$AWS_SESSION_TOKEN")/; }" "$credentials_file"
fi

echo "Credentials valid until: $(convert2localtime $(echo $json_output | jq -r '.Credentials.Expiration'))"
