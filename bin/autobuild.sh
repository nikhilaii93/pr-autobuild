#!/bin/bash

set -Eexo pipefail

# import variables and functions
DIR=/usr/bin


# See: https://github.com/koalaman/shellcheck/wiki/SC1090
# Don't the import order
# shellcheck disable=SC1091
# shellcheck source=/usr/bin
. "$DIR"/global-variables.sh
# shellcheck disable=SC1091
# shellcheck source=/usr/bin
. "$DIR"/util-methods.sh
# shellcheck disable=SC1091
# shellcheck source=/usr/bin
. "$DIR"/git-api.sh

parse_env

echo "$GITHUB_EVENT_PATH"
cat "$GITHUB_EVENT_PATH"

action=$(jq --raw-output .action "$GITHUB_EVENT_PATH")

if [ "$action" == "labeled" ]; then
	pr_num=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")
elif [ "$action" == "submitted" ]; then
	review_state=$(jq --raw-output .review.state "$GITHUB_EVENT_PATH")
	if [ "$review_state" == "approved" ]; then
		pr_num=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")	
	else
		echo "Nothing to do for review $review_state"	
		exit 0
	fi
else
	event=$(jq --raw-output .event_type "$GITHUB_EVENT_PATH")
	if [ "$event" == "pr-build-success" ]; then
		pr_num=$(jq --raw-output .pr_num "$GITHUB_EVENT_PATH")
	else 
		echo "$action is not supported"
		exit 0
	fi	
fi


labels=$(jq --raw-output .pull_request.labels "$GITHUB_EVENT_PATH")

if [[ -n "$PR_LABEL" ]]; then
	match=$(check_labels "$labels")
	if [ "$match" == false ]; then
		echo "$PR_LABEL not found on PR: $pr_num"
		exit 0
	fi
fi

if [ "$event" == "pr-build-success" ]; then

	readyToMerge=$(checkReadyToBuildOrMerge "$pr_num")

	if [ "$readyToMerge" == true ]; then
		mergeStatus=$(mergePR "$pr_num")
		mergeSuccess=$(grep -o -i "$MERGE_SUCCESS_MESSAGE" <<< "$mergeStatus" | wc -l)

		# shellcheck disable=SC2086
		if [ $mergeSuccess -eq 1 ]; then 
            echo "Successfully merged $pr_num"
            exit 0
        else
        	echo "Merge failed for $pr_num"
        	echo "This means branch was rebased with master. Rebuilding..."
        	triggerBuild "$pr_num"
            exit 1
        fi
	fi
else 
	readyToBuild=$(checkReadyToBuildOrMerge "$pr_num")

	if [ "$readyToBuild" == true ]; then
		triggerBuild "$pr_num"
	fi
fi




