#!/bin/bash

set -u

usage(){
  cat <<EOF
Usage:
  $0 -h
  $0 [-w WEBHOOK_ID] [-c CHANNEL] message

Description:
  Send a message to Slack by using Incoming Webhook.
  Webhook URL must be defined in '~/.slack-post.config' as following.

  piyopiyo=https://hooks.slack.com/services/XXXXXXXXX/YYYYYYYYYYYYYYYYYYYYYYYY
  
  Format:
  <webhook-id>=<url>
  * webhook-id : you can specify message destination by id (-w).
  * url : webhook URL. Let's get it from <https://slack.com/services/new/incoming-webhook>!
  * Definition starting with the character '#' is ignored.
  
Options:
  -h help
  -w webhook-id
  -c channel 
  -j 
     Send the message as payload json.
EOF
}

################################################################

option_asjson=''
option_webhook_id=''
option_channel=''

# options
while getopts hw:c:j opts
do
  case $opts in
  h)
    usage
	exit 0
	;;
  w)
    option_webhook_id="$OPTARG"
    ;;
  c)
    readonly option_channel="$OPTARG"
	;;
  j)
    option_asjson=yes
    ;;
  \?)
    exit 1
  esac
done
shift $((OPTIND - 1))

# requirements
readonly REQUIRED_CMDS="curl"
for cmd in $REQUIRED_CMDS
do
  if ! type $cmd >/dev/null 2>&1; then
	{
      echo "$cmd not found."
	  cat 'Requirements:'
	  for c in $REQUIRED_CMDS; do echo "  - $c"; done
	} >&2
	exit 1
  fi
done

################################################################

readonly CONFIG="$HOME/.slack-post.config"
readonly MESSAGE=$( [ -p /dev/stdin ] && cat - || echo "$1" )
readonly MESSAGE_IS_JSON=${option_asjson}
readonly WEBHOOK_ID=${option_webhook_id}
readonly CHANNEL=${option_channel}

# Webhook URL
if [ -z "${WEBHOOK_ID}" ]; then
  readonly WEBHOOK_URL=$(grep -v '^#.*' "$CONFIG" | head -n 1 | sed -e 's/^[^=]*=//')
else
  readonly WEBHOOK_URL=$(grep -oP "(?<=^${WEBHOOK_ID}=).*" "$CONFIG")
fi

[[ -z "$WEBHOOK_URL" ]] && {
  echo 'Webhook URL is not defined.' >&2
  exit 1;
}

# Create payload
payload=''
if [ "${MESSAGE_IS_JSON}" = yes ]; then
   payload="${MESSAGE}" 
else
  payload='{'
  # channel
  [ ! -z $CHANNEL ] && payload="${payload}\"channel\": \"$CHANNEL\","
  # text
  payload="${payload}\"text\": \"$MESSAGE\""
  payload="${payload}}"
fi

# Send Message
if [ ! -z "$MESSAGE" ]; then
  curl -X POST -d "payload=${payload}" $WEBHOOK_URL
fi

