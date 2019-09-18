#!/bin/bash

set -Eexo pipefail

# import variables and functions
DIR=/usr/bin

. "$DIR"/global-variables.sh
. "$DIR"/util-methods.sh
. "$DIR"/git-api.sh

parse_env

echo "$GITHUB_EVENT_PATH"
cat "$GITHUB_EVENT_PATH"

action=$(jq --raw-output .action "$GITHUB_EVENT_PATH")

if [ "$action" == "labeled" ]; then
	pr_num=$(jq --raw-output .number "$GITHUB_EVENT_PATH")
elif [ "$action" == "submitted" ]; then
	review_state=$(jq --raw-output .review.state "$GITHUB_EVENT_PATH")
	if [ "$review_state" == "approved" ]; then
		pr_num=$(jq --raw-output .number "$GITHUB_EVENT_PATH")	
	else
		echo "Nothing to do for review $review_state"	
		exit 0
	fi
else
	echo "$action is not supported"
	exit 0
fi


labels=$(jq --raw-output .pull_request.labels "$GITHUB_EVENT_PATH")

if [[ ! -z "$PR_LABEL" ]]; then
	match=$(check_labels "$labels")
	if [ "$match" == false ]; then
		echo "$PR_LABEL not found on PR: $pr_num"
		exit 0
	fi
fi

readyToBuild=$(checkReadyToBuild $pr_num)

if [ "$readyToBuild" == true ]; then
	if [ "$COMMENT_BASED_BUILD" = true ]; then
		triggerCommentBuild "$pr_num"
	else
		echo "Build Script option yet to be implemented!"
		exit 1
	fi
fi