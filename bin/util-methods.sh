#!/bin/bash

set -Eexo pipefail

function log {
    if [[ "$1" != *"Function"* ]] && [[ "$1" != *"Debug"* ]];
    then
        echo "$1" >&2
    elif [[ "$DEBUG" == "true" ]];
    then
        echo "$1" >&2
    fi
}

function parse_env {
	if [[ -z "$GITHUB_TOKEN" ]]; then
		echo "Set the GITHUB_TOKEN env variable."
		exit 1
	fi
	if [[ -z "$GITHUB_NAME" ]]; then
		echo "Set the GITHUB_NAME env variable."
		exit 1
	fi
	export GIT_NAME="$GITHUB_NAME"
	export GIT_TOKEN="$GITHUB_TOKEN"

	# Approval count is integer
	if [[ -n "$DEFAULT_APPROVAL_COUNT_ENV" ]]; then
		export DEFAULT_APPROVAL_COUNT=$DEFAULT_APPROVAL_COUNT_ENV
	fi

	if [[ -n "$COMMENT_BASED_BUILD_ENV" ]]; then
		export COMMENT_BASED_BUILD="$COMMENT_BASED_BUILD_ENV"
	fi

	if [[ -n "$BUILD_COMMENT_ENV" ]]; then
		export BUILD_COMMENT="$BUILD_COMMENT_ENV"
	fi

	if [[ -n "$PR_LABEL_ENV" ]]; then
		export PR_LABEL="$PR_LABEL_ENV"
	fi
}

function check_labels () {
	match=false
	labels="$1"
	for row in $(echo "${labels}" | jq -r '.[] | @base64'); do
    	_jq() {
     		echo "${row}" | base64 -d | jq -r "${1}"
    	}

   		label_name=$(_jq '.name')
   		if [ "$label_name" == "$PR_LABEL" ]; then
   			match=true
   			break
   		fi
	done
	echo "$match"
}

function getCall {
    gitApi="$1"
    prNum="$2"

    local getApi
    getApi=$(printf "$gitApi" "$prNum")

    local apiStatus
    apiStatus=$(curl -s -u "$GIT_NAME":"$GIT_TOKEN" "$getApi")

    echo "$apiStatus"
}

function review_set () {
    reviewSet+="$1,$2"$'\n'
}

function review_get () {
    state=$(echo "$reviewSet" | grep "^$1," | sed -e "s/^$1,//" | tail -n 1)
    echo "$state"
}

function review_flush () {
    reviewSet=""
}

function login_set () {
    loginSet+="$1,"
}

function login_get () {
    count=$(echo "$loginSet" | grep -c "$1,")
    echo "$count"
}

function login_flush () {
    loginSet=""
}
