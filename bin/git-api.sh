#!/bin/bash

set -xo pipefail

function updatePRdetails {
    log "Function updatePRdetails"

    local pr_num
    pr_num=$1

    local prDetails
    prDetails=$(getCall "$GIT_PR_API" "$pr_num")
    PR_BRANCH=$(echo "$prDetails" | jq -r '.head.ref')
    export PR_BRANCH
    BASE_BRANCH=$(echo "$prDetails" | jq -r '.base.ref')
    export BASE_BRANCH
    LABELS=$(echo "$prDetails" | jq -r '.labels')
    export LABELS
}

function getMergeStatus {
    log "Function getMergeStatus"

    local pr_num
    pr_num=$1

    local mergeStatus
    mergeStatus=$(getCall "$GIT_PR_MERGE_API" "$pr_num")

    if [[ "$mergeStatus" == *"Not Found"* ]]; then
        echo "$UNMERGED_STATUS"
    else
        echo "$MERGED_STATUS"
    fi
}

function isPROpenAndUnmerged {
    log "Function isPROpenAndUnmerged"

    local pr_num
    pr_num=$1

    local prDetails
    prDetails=$(getCall "$GIT_PR_API" "$pr_num")
    local prStatus
    prStatus=$(echo "$prDetails" | jq -r '.state')
    local mergeStatus
    mergeStatus=$(getMergeStatus "$pr_num")

    log "Debug: PR status $prStatus of $pr_num"
    log "Debug: Merge status $mergeStatus of $pr_num"

    if [ "$prStatus" == 'open' ] && [ "$mergeStatus" == "$UNMERGED_STATUS" ];
    then 
        echo true
    else 
        echo false
    fi
}

function isCodeOwnerReviewPending {
    log "Function isCodeOwnerReviewPending"

    local pr_num
    pr_num=$1

    pendingReviews=$(getCall "$GIT_PENDING_REVIEWS_API" "$pr_num")

    local userNames=()
    while IFS='' read -r line; do userNames+=("$line"); done < <(jq -r '.users[].login' <<< "${pendingReviews}")
    local teamNames=()
    while IFS='' read -r line; do teamNames+=("$line"); done < <(jq -r '.teams[].name' <<< "${pendingReviews}")

    #echo "User: ${userNames[@]}"
    #echo "Team: ${teamNames[@]}"

    local pendingReview
    local j
    pendingReview=false
    j=0
    while [ ${#CODE_OWNERS[@]} -gt $j ]; do
        if [[ " ${userNames[*]} " =~ ${CODE_OWNERS[$j]} ]]; then
            pendingReview=true
        elif [[ " ${teamNames[*]} " =~ ${CODE_OWNERS[$j]} ]]; then
            pendingReview=true
        fi

        j=$((j+1))
    done
    echo "$pendingReview"
}

function isApproved {
    log "Function isApproved"

    local approvalCount
    approvalCount=0
    local prStatus
    prStatus="$1"

    # States are returned in chronological order
    # See: https://github.com/koalaman/shellcheck/wiki/SC2207
    local loginNames=()
    while IFS='' read -r line; do loginNames+=("$line"); done < <(jq -r '.[].user.login' <<< "${prStatus}")
    local reviewStates=()
    while IFS='' read -r line; do reviewStates+=("$line"); done < <(jq -r '.[].state' <<< "${prStatus}")

    local j
    j=0

    # Store all reviews
    while [ ${#loginNames[@]} -gt $j ]; do
        review_set "${loginNames[$j]}" "${reviewStates[$j]}"

        j=$((j+1))
    done

    
    local i=0
    while [ ${#loginNames[@]} -gt $i ]; do
        local loginName
        loginName="${loginNames[$i]}"

        local loginCount
        loginCount=$(login_get "$loginName")
        
        # shellcheck disable=SC2086
        if [ $loginCount -eq 0 ]; then

            login_set "$loginName"

            # Get the latest review
            local latestState
            latestState=$(review_get "$loginName")
            
            log "Debug: Latest state $latestState for $loginName"

            # Takes care of any changes requested by anyone + changes requested by codeowners
            if [ "$latestState" == "$PR_CHANGES_REQUESTED" ]; then 
                changesRequested=true
                break
            elif [ "$latestState" == "$PR_APPROVED" ]; then
                approvalCount=$((approvalCount+1))
            fi
        fi

        i=$((i+1))
    done

    log "Debug: Approval count $approvalCount"
    
    # shellcheck disable=SC2086
    if [ "$changesRequested" == true ]; then
        log "Debug: Changes requested"
        echo false
    elif [ $approvalCount -ge $DEFAULT_APPROVAL_COUNT ]; then 
        echo true
    else
        echo false
    fi

    review_flush
    login_flush
}

function updatePR {
    log "Function updatePR"

    local pr_num
    pr_num=$1

    local updateStatus
    # shellcheck disable=SC2086
    updateStatus=$(curl -s -X POST -u "$GIT_NAME":"$GIT_TOKEN" -H "Content-Type: application/json" -H "Accept: application/vnd.github.v3+json" "$GIT_MERGE_API" -d '
    {
        "base": '\"$PR_BRANCH\"',
        "head": '\"$BASE_BRANCH\"'
    }')

    local conflictCount
    conflictCount=$(grep -o -i 'Merge Conflict' <<< "$updateStatus" | wc -l)
    local commitCount
    commitCount=$(grep -o -i 'commit' <<< "$updateStatus" | wc -l)
    
    # shellcheck disable=SC2086
    if [ $conflictCount -eq 0 ]; then
        # shellcheck disable=SC2086
        if [ $commitCount -eq 0 ]; then
            echo "$ALREADY_UPDATED_STATUS"
        else
            echo "$UPDATED_STATUS"
        fi
    else
        echo "$CONFLICT_STATUS"
    fi
}

function checkReadyToBuildOrMerge {
    log "Function checkReadyToBuild"

    local pr_num
    pr_num=$1


    local page_num
    page_num=1
    local reviewDetails=()

    # Loop because in a page only 30 requests are returned
     while true; do
        getReviewApiWithPage="$GIT_REVIEWS_API$page_num"

        local reviewDetailsTemp
        reviewDetailsTemp=$(getCall "$getReviewApiWithPage" "$pr_num")

        # Check for a unique string in the payload
        current_size=$(grep -o -i 'pull_request_url' <<< "$reviewDetailsTemp" | wc -l)
        
        # shellcheck disable=SC2086
        if [ $current_size -eq 0 ]; then
            break;
        fi
        # shellcheck disable=SC2179
        reviewDetails+=${reviewDetailsTemp[*]}
        page_num=$((page_num+1))
    done

    local isPRValid
    isPRValid=$(isPROpenAndUnmerged "$pr_num")
    local approved
    approved=$(isApproved "${reviewDetails[@]}")
    local pendingCodeOwner
    pendingCodeOwner=$(isCodeOwnerReviewPending "$pr_num")
    local currentUpdateStatus
    currentUpdateStatus=$(updatePR "$pr_num")

    if [ "$isPRValid" == true ] && [ "$approved" == true ] && [ "$pendingCodeOwner" == false ]; then
        log "PR $pr_num ready to build/merge"
        echo "$currentUpdateStatus"
    else
        log "PR $pr_num not ready to build/merge"
        echo "$NOT_READY_STATUS"
    fi
}

function triggerCommentBuild {
    log "Function triggerBuild"

    local pr_num
    pr_num=$1

    local commentsApi
    # shellcheck disable=SC2059
    commentsApi=$(printf "$GIT_ISSUES_COMMENTS_API" "$pr_num")

    curl -s -X POST -u "$GIT_NAME":"$GIT_TOKEN" -H "Content-Type: application/json" -H "Accept: application/vnd.github.v3+json" "$commentsApi" -d '
    {
        "body": "OK to test"
    }'

    log "Build triggered for $pr_num"
}

function triggerBuild {
    local pr_num
    pr_num=$1
    if [ "$COMMENT_BASED_BUILD" = true ]; then
        triggerCommentBuild "$pr_num"
    else
        echo "Build Script option yet to be implemented!"
        exit 1
    fi
}

function mergePR {
    log "Function mergePR"

    pr_num=$1

    local mergeApi
    # shellcheck disable=SC2059
    mergeApi=$(printf "$GIT_PR_MERGE_API" "$pr_num")
    local mergeStatus

    # Branches to release aren't squashed as it will ruin the commit history.
    if [ "$PR_BRANCH" == "release" ] || [ "$BASE_BRANCH" == "release" ] || [ "$DEFAULT_MERGE" == "merge" ]; then
        log "Doing default merge for prBranch: $PR_BRANCH & baseBranch: $BASE_BRANCH"
        mergeStatus=$(curl -s -X PUT -u "$GIT_NAME":"$GIT_TOKEN" -H "Accept: application/vnd.github.v3+json" "$mergeApi")
    else
        log "Doing squash merge for prBranch: $PR_BRANCH & baseBranch: $BASE_BRANCH"
        mergeStatus=$(curl -s -X PUT -u "$GIT_NAME":"$GIT_TOKEN" "$mergeApi" -H "Accept: application/vnd.github.v3+json" -d '{"merge_method": "squash"}')
    fi    

    
    echo "$mergeStatus"
}

function isPRCloseAndMerged {
    log "Function isPRCloseAndMerged"

    local pr_num
    pr_num=$1

    local prDetails
    prDetails=$(getCall "$GIT_PR_API" "$pr_num")
    local prStatus
    prStatus=$(echo "$prDetails" | jq -r '.state')
    local mergeStatus
    mergeStatus=$(getMergeStatus "$pr_num")

    log "Debug: PR status $prStatus of $pr_num"
    log "Debug: Merge status $mergeStatus of $pr_num"

    if [ "$prStatus" == 'closed' ] && [ "$mergeStatus" == "$MERGED_STATUS" ]; then 
        echo true
    else 
        echo false
    fi
}

function deleteBranch {
    log "Function deleteBranch"

    local pr_num
    pr_num=$1

    local isPRMerged
    isPRMerged=$(isPRCloseAndMerged "$pr_num")

    log "PR merged $isPRMerged $PR_BRANCH"

    if [ "$isPRMerged" == true ]; then
        local deleteApi
        # shellcheck disable=SC2059
        deleteApi=$(printf "$GIT_DELETE_API" "$PR_BRANCH")
        
        log "$deleteApi"
        curl -s -X DELETE -u "$GIT_NAME":"$GIT_TOKEN" "$deleteApi"
    else
        echo "PR $pr_num is not merged, aborting delete"
    fi
}
