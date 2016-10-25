#!/bin/bash

local CONF="$LE_WORKING_DIR/dnsapi/dns-route53-python.conf"
[ -r "$CONF" ] && . $CONF

if [ -z "$AWS" ]; then
  AWS=`which aws 2>/dev/null`
fi

#Usage: add _acme-challenge.www.domain.com "XKrx...."
dns_route53_add() {
  if [ -z "$AWS" ]; then
    _err "AWS not found. Please install globally using PIP or update AWS variable in $CONF"
    return 1
  fi

  if [ ! -x "$AWS" ]; then
    _err "AWS binary located at '$AWS' is not executable. Cannot continue."
    return 1
  fi

  PROFILE=""
  [ ! -z "$AWS53_PROFILE" ] && PROFILE="--profile $AWS53_PROFILE"
  if ! $AWS configure $PROFILE list | grep -q access_key; then
    _err "AWS is not configured with an access_key."
    return 1
  fi

  if ! $AWS configure $PROFILE list | grep -q secret_key; then
    _err "AWS is not configured with a secret_key."
    return 1
  fi

  fulldomain=$1
  _find_root $fulldomain
  if [ $? -gt 0 ]; then
    _err "ZoneID could not be determined"
    _err "Failed to change DNS"
    return 1
  fi

  # Update txtvalue to have \" at the beginning and end for JSON encoding
  txtvalue=\\\"`echo $2 | sed -e 's/"$//' -e 's/^"//'`\\\"
  _debug txtvalue $txtvalue

  # generate JSON update code
  JSONFILE=$(mktemp)
  echo '{"Changes": [{"Action": "UPSERT", "ResourceRecordSet": {"Name": "'$fulldomain'", "Type": "TXT", "TTL": 300, "ResourceRecords": [{"Value": "'$txtvalue'"}]}}]}' > $JSONFILE
  _debug JSONFILE $JSONFILE

  ERRFILE=$(mktemp)
  _info "Submitting request to change DNS for $fulldomain TXT record to $txtvalue"
  _debug "----JSON----"
  [ ! -z "$DEBUG" ] && cat $JSONFILE
  _debug "----JSON----"
  _debug "$AWS --output text $PROFILE route53 change-resource-record-sets --hosted-zone-id $_domain_id --change-batch file://$JSONFILE"
  RESULT=`$AWS --output text $PROFILE route53 change-resource-record-sets --hosted-zone-id $_domain_id --change-batch file://$JSONFILE 2>$ERRFILE | grep "CHANGEINFO"`
  _debug RESULT "$RESULT"
  rm -f $JSONFILE

  LINES=`wc -l < $ERRFILE`
  if [ $LINES -gt 0 ]; then
    _info "Error output of AWS command:"
    cat $ERRFILE
  fi
  rm -f $ERRFILE

  RESULT_STATUS_CODE=`echo $RESULT | awk '{ print $3; }'`
  _debug RESULT_STATUS_CODE "$RESULT_STATUS_CODE"
  CHANGE_ID=`echo $RESULT | awk '{ print $2; }'`
  _debug CHANGE_ID "$CHANGE_ID"

  # If we find a pending state, loop until we find a insync state.
  if [ "$RESULT_STATUS_CODE" == "PENDING" ]; then
    _info "State of change request is $RESULT_STATUS_CODE."
    for run in {1..3}
    do
      sleep 15
      _check_changeid $CHANGE_ID
      _info "State of change request is $RESULT_STATUS_CODE."
      [ "$RESULT_STATUS_CODE" == "INSYNC" ] && break;
    done
  fi

  # final state check. If INSYNC, then success, otherwise failure.
  if [ "$RESULT_STATUS_CODE" == "INSYNC" ]; then
    _debug "Result status code $RESULT_STATUS_CODE found. DNS added."
    _info "DNS added."
    return 0
  else
    _err "Failed to change DNS"
    return 1
  fi
}

####################  Private functions bellow ##################################


#Usage: _find_root _acme-challenge.www.domain.com
#returns
# _sub_domain=_acme-challenge.www
# _domain=domain.com
# _domain_id=Z20IC834500000
_find_root() {
  local domain=$1
  local i=2
  local p=1
  local h
  while [ '1' ]; do
    local h=$(printf $domain | rev | cut -d . -f-$i | rev)
    if [ -z "$h" ] ; then
      #not valid
      return 1
    fi

    if _test_domain $h; then
      if [ ! -z "$_domain_id" ]; then
        _sub_domain=$(printf $domain | cut -d . -f 1-$p)
        _domain=$h
        return 0
      fi
    fi
    p=$i
    let "i+=1"
  done
  return 1
}

#Usage: _test_domain domain.com
_test_domain() {
  local basedomain=$1
  local errfile=$(mktemp)
  _info "Searching for ZoneID for $basedomain"
  _domain_id=`$AWS --output text $PROFILE route53 list-hosted-zones-by-name --dns-name $basedomain --max-items 1 2>$errfile | grep "HOSTEDZONES" | awk '{ print $3; }' | sed -r 's/\/hostedzone\/([A-Z0-9]+)/\1/'`
  _debug _domain_id $_domain_id
  local errorcount=`wc -l < $errfile`
  return $errorcount
}

#Usage: _check-changeid /change/C30DVTKZ000000
_check_changeid() {
  # aws --output text route53 get-change --id /change/C30DVTKZ000000
  RESULT=`$AWS --output text $PROFILE route53 get-change --id $1`
  _debug RESULT "$RESULT"
  # CHANGEINFO	/change/C30DVTKZ000000	PENDING	2016-03-08T19:15:48.323Z
  RESULT_STATUS_CODE=`echo $RESULT | awk '{ print $3; }'`
  _debug RESULT_STATUS_CODE "$RESULT_STATUS_CODE"
}

_debug() {

  if [ -z "$DEBUG" ] ; then
    return
  fi

  if [ -z "$2" ] ; then
    echo $1
  else
    echo "$1"="$2"
  fi
}

_info() {
  if [ -z "$2" ] ; then
    echo "$1"
  else
    echo "$1"="$2"
  fi
}

_err() {
  if [ -z "$2" ] ; then
    echo "$1" >&2
  else
    echo "$1"="$2" >&2
  fi
}
