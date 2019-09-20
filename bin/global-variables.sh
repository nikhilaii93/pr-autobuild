#!/bin/bash

set -Eexo pipefail


# Setup variables
export PR_BRANCH=""
export BASE_BRANCH=""

# Constants
# Approval count is integer
export DEFAULT_APPROVAL_COUNT=2
export PR_APPROVED='APPROVED'
export PR_LABEL=""
export COMMENT_BASED_BUILD=true
export BUILD_COMMENT="OK to test"
export DEFAULT_MERGE=merge

# DO NOT CHANGE THIS
export BUILD_UPDATE_TIME=10

# PR Status
export MERGED_STATUS='MERGED'
export UNMERGED_STATUS='UNMERGED'
export ALREADY_MERGED_STATUS='ALREADY_MERGED'
export MERGE_FAILED_STATUS='MERGE_FAILED'
export BUILD_FAILED_STATUS='BUILD_FAILED'
export NOT_READY_STATUS='NOT_READY'
export CONFLICT_STATUS='CONFLICT'
export MERGE_SUCCESS_MESSAGE='Pull Request successfully merged'

# Git APIs
export GIT_PR_API="https://api.github.com/repos/$GITHUB_REPOSITORY/pulls/%s"
export GIT_ISSUES_COMMENTS_API="https://api.github.com/repos/$GITHUB_REPOSITORY/issues/%s/comments"
export GIT_MERGE_API="https://api.github.com/repos/$GITHUB_REPOSITORY/merges"
export GIT_REVIEWS_API="https://api.github.com/repos/$GITHUB_REPOSITORY/pulls/%s/reviews"
export GIT_COMMENT_API="https://api.github.com/repos/$GITHUB_REPOSITORY/pulls/%s/comments"
export GIT_PR_MERGE_API="https://api.github.com/repos/$GITHUB_REPOSITORY/pulls/%s/merge?"
