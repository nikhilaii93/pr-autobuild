#!/bin/bash

set -Eexo pipefail

# import variables and functions
DIR=/usr/bin

. "$DIR"/global-variables.sh
. "$DIR"/util-methods.sh
. "$DIR"/git-api.sh

parse_env

echo "$GITHUB_EVENT_PATH"

exit 1

readyToBuild=$(checkReadyToBuild $pr_num)

if [ "$readyToBuild" == true ];
then
	if [ "$COMMENT_BASED_BUILD" = true ];
	then
		triggerCommentBuild "$pr_num"
	else
		echo "Build Script option yet to be implemented!"
		exit 1
	fi
fi