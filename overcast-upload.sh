#!/usr/bin/env bash

if [[ -z "$1" ]]
then
  echo "Please enter a file to upload."
  exit 1
fi

if [[ ! -f $1 ]]
then
  echo "File $1 not found."
  exit 1
fi

unset overcast_email
unset overcast_password
source ~/.overcast_auth

if [[ -z "$overcast_email" ]] \
  || [[ -z "$overcast_password" ]]
then
  echo "Please set your credentials in ~/.overcast_auth like this:"
  echo ""
  echo 'export overcast_email="yourEmail@example.com"'
  echo 'export overcast_password="yourPassword"'
  echo ""
  exit 1
fi

echo "Logging in as $overcast_email"
curl -Ls  --compressed \
  -d "then=uploads" \
  -d "email=$overcast_email" \
  -d "password=$overcast_password" \
  -c overcast_cookies \
  -o upload.tmp \
  https://overcast.fm/login \
  || exit 1

policy=$(grep -o -E \
  '<input type="hidden" id="upload_policy" name="policy" value="[^\\"]+' \
  upload.tmp \
  | sed \
  's/<input type="hidden" id="upload_policy" name="policy" value="//g' \
  )

signature=$(grep -o -E \
  '<input type="hidden" id="upload_signature" name="signature" value="[^\\"]+' \
  upload.tmp \
  | sed \
  's/<input type="hidden" id="upload_signature" name="signature" value="//g' \
  )

AWSAccessKeyId=$(grep -o -E \
  '<input type="hidden" name="AWSAccessKeyId" value="[^\\"]+' \
  upload.tmp \
  | sed \
  's/<input type="hidden" name="AWSAccessKeyId" value="//g' \
  )

key=$(grep -o -E \
  'data-key-prefix="[^\\"]+' \
  upload.tmp \
  | sed \
  's/data-key-prefix="//g' \
  )

filename=$(basename $1)

if [[ -z "$policy" ]] \
  || [[ -z "$signature" ]] \
  || [[ -z "$AWSAccessKeyId" ]] \
  || [[ -z "$key" ]] \
  || [[ -z "$filename" ]]
then
  echo "There was a problem fetching the upload page."
  echo "Make sure your email and password are correct."
  exit 1
fi

rm upload.tmp

echo Uploading $filename
curl -Ls --compressed \
  -F "bucket=uploads-overcast" \
  -F "key=$key$filename" \
  -F "AWSAccessKeyId=$AWSAccessKeyId" \
  -F "acl=authenticated-read" \
  -F "policy=$policy" \
  -F "signature=$signature" \
  -F "Content-Type=audio/mpeg" \
  -F "file=@$1" \
  -b overcast_cookies \
  https://uploads-overcast.s3.amazonaws.com/ \
  || exit 1

curl -Ls --compressed \
  -F "key=$key$filename" \
  -b overcast_cookies \
  https://overcast.fm/podcasts/upload_succeeded \
  > /dev/null \
  || exit 1

rm overcast_cookies

echo Done!
