#!/bin/bash

set -xo pipefail

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

    if [[ -n "$DEFAULT_MERGE_ENV" ]]; then
        export DEFAULT_MERGE="$DEFAULT_MERGE_ENV"
    fi

    if [[ -n "$DELETE_BRANCH_ENV" ]]; then
        export DELETE_BRANCH="$DELETE_BRANCH_ENV"
    fi

    if [[ -n "$CODE_OWNERS_ENV" ]]; then
        IFS=',' read -r -a CODE_OWNERS <<< "$CODE_OWNERS_ENV"
        export CODE_OWNERS
    fi
}

function check_labels () {
    local labels
    labels="$1"
    
    local labelCount
    labelCount=$(grep -o -i "$PR_LABEL" <<< "$labels" | wc -l)
	
    # shellcheck disable=SC2086
    if [ $labelCount -eq 0 ]; then
        echo false
    else
        echo true
    fi

    # Below code is not working as expected in alpine, so using grep above.
    # 
    # for row in $(echo "${labels}" | jq -r '.[] | @base64'); do
    # _jq() {
    #     echo "${row}" | base64 -d | jq -r "${1}"
    # }
    # 
    #     label_name=$(_jq '.name')
    #     if [ "$label_name" == "$PR_LABEL" ]; then
    #         match=true
    #         break
    #     fi
    # done
}

function getCall {
    gitApi="$1"
    prNum="$2"


    local getApi
    # shellcheck disable=SC2059
    getApi=$(printf "$gitApi" "$prNum")

    local apiStatus
    apiStatus=$(curl -s -u "$GIT_NAME":"$GIT_TOKEN" -H "Accept: application/vnd.github.v3+json" "$getApi")

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
