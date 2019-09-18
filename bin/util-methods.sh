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
	GIT_NAME="$GITHUB_NAME"
	GIT_TOKEN="$GITHUB_TOKEN"

	# Approval count is integer
	if [[ ! -z "$DEFAULT_APPROVAL_COUNT_ENV" ]]; then
		DEFAULT_APPROVAL_COUNT=$DEFAULT_APPROVAL_COUNT_ENV
	fi

	if [[ ! -z "$BASE_BRANCH_ENV" ]]; then
		BASE_BRANCH="$BASE_BRANCH_ENV"
	fi

	if [[ ! -z "$COMMENT_BASED_BUILD_ENV" ]]; then
		COMMENT_BASED_BUILD="$COMMENT_BASED_BUILD_ENV"
	fi

	if [[ ! -z "$BUILD_COMMENT_ENV" ]]; then
		BUILD_COMMENT="$BUILD_COMMENT_ENV"
	fi

	if [[ ! -z "$PR_LABEL_ENV" ]]; then
		PR_LABEL="$PR_LABEL_ENV"
	fi
}

function check_labels () {
	match=false
	labels="$1"
	for row in $(echo "${labels}" | jq -r '.[] | @base64'); do
    	_jq() {
     		echo ${row} | base64 -d | jq -r ${1}
    	}

   		label_name=$(_jq '.name')
   		if [ "$label_name" == "$PR_LABEL" ]; then
   			match=true
   			break
   		fi
	done
	echo "$match"
}

function review_set () {
    reviewSet+="$1,$2"$'\n'
}

function review_get () {
    state=$(echo "$reviewSet" | grep "^$1," | sed -e "s/^$1,//" | tail -n 1)
    echo $state
}

function review_flush () {
    reviewSet=""
}

function login_set () {
    loginSet+="$1,"
}

function login_get () {
    count=$(echo "$loginSet" | grep "$1," | wc -l)
    echo $count
}

function login_flush () {
    loginSet=""
}
