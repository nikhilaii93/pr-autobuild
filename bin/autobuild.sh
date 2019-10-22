#!/bin/bash

set -xo pipefail

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

# Parse Environment Variables
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
elif [[ "$action" == "pr-build-success"* ]]; then
	event="pr-build-success"

	IFS=' '
	read -ra actionParts <<< "$action"
	
	pr_num="${actionParts[1]}"
else 
	echo "$action is not supported"
	exit 0
fi


# Update PR details in Global Variables
updatePRdetails "$pr_num"

if [[ -n "$PR_LABEL" ]]; then
	match=$(check_labels "$LABELS")
	if [ "$match" == false ]; then
		echo "$PR_LABEL not found on PR: $pr_num"
		exit 0
	fi
fi

if [ "$event" == "pr-build-success" ]; then

	readyToMerge=$(checkReadyToBuildOrMerge "$pr_num")

	if [ "$readyToMerge" == "$NOT_READY_STATUS" ]; then
		echo "PR not valid or approved: $pr_num"

		exit 0
	elif [ "$readyToMerge" == "$UPDATED_STATUS" ]; then
		triggerBuild "$pr_num"

		exit 0
	elif [ "$readyToMerge" == "$ALREADY_UPDATED_STATUS" ]; then
		# try merging
		mergeStatus=$(mergePR "$pr_num")
		mergeSuccess=$(grep -o -i "$MERGE_SUCCESS_MESSAGE" <<< "$mergeStatus" | wc -l)

		# shellcheck disable=SC2086
		if [ $mergeSuccess -eq 1 ]; then 
            echo "Successfully merged $pr_num"

            if [ "$DELETE_BRANCH" == true ]; then
            	deleteStatus=$(deleteBranch $pr_num)

            	log "Delete status $deleteStatus"
            fi

            exit 0
        else 
        	echo "Merge failed for $pr_num"
        	echo "This means branch has sonar issues/review pending. Exiting..."
        fi
	elif [ "$readyToMerge" == "$CONFLICT_STATUS" ]; then
		echo "Conflict in PR: $pr_num"

		exit 0
	else
		echo "Unknown status: $readyToBuild"
		exit 1
	fi
else 
	readyToBuild=$(checkReadyToBuildOrMerge "$pr_num")

	if [ "$readyToBuild" == "$NOT_READY_STATUS" ]; then
		echo "PR not valid or approved: $pr_num"

		exit 0
	elif [ "$readyToBuild" == "$UPDATED_STATUS" ]; then
		triggerBuild "$pr_num"

		exit 0
	elif [ "$readyToBuild" == "$ALREADY_UPDATED_STATUS" ]; then
		# try merging
		mergeStatus=$(mergePR "$pr_num")
		mergeSuccess=$(grep -o -i "$MERGE_SUCCESS_MESSAGE" <<< "$mergeStatus" | wc -l)

		# shellcheck disable=SC2086
		if [ $mergeSuccess -eq 1 ]; then 
            echo "Successfully merged $pr_num"

            if [ "$DELETE_BRANCH" == true ]; then
            	deleteStatus=$(deleteBranch $pr_num)

            	log "Delete status $deleteStatus"
            fi

            exit 0
        else
        	triggerBuild "$pr_num"

            exit 0
        fi
	elif [ "$readyToBuild" == "$CONFLICT_STATUS" ]; then
		echo "Conflict in PR: $pr_num"

		exit 0
	else
		echo "Unknown status: $readyToBuild"
		exit 1
	fi
fi
