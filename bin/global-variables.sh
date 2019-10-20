#!/bin/bash

set -xo pipefail


# Setup variables
export PR_BRANCH=""
export BASE_BRANCH=""
export LABELS=()
export CODE_OWNERS=()

# Constants
# Approval count is integer
export DEFAULT_APPROVAL_COUNT=2
export PR_APPROVED='APPROVED'
export PR_LABEL=""
export COMMENT_BASED_BUILD=true
export BUILD_COMMENT="OK to test"
export DEFAULT_MERGE=merge
export DELETE_BRANCH=false

# DO NOT REDUCE THIS
export BUILD_UPDATE_TIME=15

# PR Status
export MERGED_STATUS='MERGED'
export UNMERGED_STATUS='UNMERGED'
export ALREADY_MERGED_STATUS='ALREADY_MERGED'
export MERGE_FAILED_STATUS='MERGE_FAILED'
export BUILD_FAILED_STATUS='BUILD_FAILED'
export NOT_READY_STATUS='NOT_READY'
export CONFLICT_STATUS='CONFLICT'
export MERGE_SUCCESS_MESSAGE='Pull Request successfully merged'
export NOT_MERGEABLE_STATUS='Pull Request is not mergeable'
export DELETE_FAILURE_MESSAGE='aborting delete'
export UPDATED_STATUS='UPDATED'
export ALREADY_UPDATED_STATUS='ALREADY_UPDATED'

# Git APIs
export GIT_PR_API="https://api.github.com/repos/$GITHUB_REPOSITORY/pulls/%s"
export GIT_ISSUES_COMMENTS_API="https://api.github.com/repos/$GITHUB_REPOSITORY/issues/%s/comments"
export GIT_MERGE_API="https://api.github.com/repos/$GITHUB_REPOSITORY/merges"
# Note extra page param at the end
export GIT_REVIEWS_API="https://api.github.com/repos/$GITHUB_REPOSITORY/pulls/%s/reviews?page="
export GIT_PENDING_REVIEWS_API="https://api.github.com/repos/$GITHUB_REPOSITORY/pulls/%s/requested_reviewers"
export GIT_COMMENT_API="https://api.github.com/repos/$GITHUB_REPOSITORY/pulls/%s/comments"
export GIT_PR_MERGE_API="https://api.github.com/repos/$GITHUB_REPOSITORY/pulls/%s/merge"
export GIT_DELETE_API="https://api.github.com/repos/$GITHUB_REPOSITORY/git/refs/heads/%s"
