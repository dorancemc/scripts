#!/bin/bash
# https://repost.aws/knowledge-center/authenticate-mfa-cli
#
# script to export the AWS credentials to the current shell
# dorancemc@ 18.11.2023
#
# Before running this script, you need to have the following
# 1. 1password cli installed and configured
# 2. aws cli installed and configured
# 3. aws profile configured with the following format
#    empty values are valid
# [default]
# aws_access_key_id=
# aws_secret_access_key=
# aws_session_token=
#

if [ -z "$1" ]; then
  echo "Usage: source $0 <aws_1pass_profile> [aws_profile] [duration_seconds]"
      aws_1pass_profile item name on 1password
      aws_profile profile on credentials config file to updated (should be exists)
  exit 1
fi

sed_escape() {
  echo "$1" | sed -e 's/[\/&]/\\&/g'
}

convert2localtime() {
  echo $(python3 -c "from dateutil import parser; print(parser.parse('$1').astimezone().strftime('%Y-%m-%d %H:%M:%S %Z'))")
}

aws_1pass_profile="${1}"
aws_profile="${2:-default}"
duration_seconds="${3:-900}"

#output=$(1pass gets ${aws_1pass_profile} aws_access_key_id,aws_secret_access_key,mfa_serial)
output=$(op item get ${aws_1pass_profile} --fields aws_access_key_id,aws_secret_access_key,mfa_serial)
IFS=',' read -r aws_access_key_id aws_secret_access_key mfa_serial <<< "$output"

json_output=$( \
AWS_ACCESS_KEY_ID="$aws_access_key_id" \
AWS_SECRET_ACCESS_KEY="$aws_secret_access_key" \
aws sts get-session-token \
--serial-number "$mfa_serial" \
--token-code $(1pass mfa ${aws_1pass_profile}) \
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

echo Credentials valid until: $(convert2localtime $(echo "$json_output" | jq -r '.Credentials.Expiration'))
