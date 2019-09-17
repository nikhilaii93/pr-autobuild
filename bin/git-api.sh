#!/bin/bash

set -Eexo pipefail

function getMergeStatus {
    log "Function getMergeStatus"

    local pr_num=$1

    local mergeStatus=$(getCall "$GIT_PR_MERGE_API" "$pr_num")

    if [[ "$mergeStatus" == *"Not Found"* ]]; then
        echo "$UNMERGED_STATUS"
    else
        echo "$MERGED_STATUS"
    fi
}

function isPROpenAndUnmerged {
    log "Function isPROpenAndUnmerged"

    local pr_num=$1

    local prDetails=$(getCall "$GIT_PR_API" "$pr_num")
    local prStatus=$(echo "$prDetails" | jq -r '.state')
    local mergeStatus=$(getMergeStatus "$pr_num")

    log "Debug: PR status $prStatus of $pr_num"
    log "Debug: Merge status $mergeStatus of $pr_num"

    if [ "$prStatus" == 'open' ] && [ "$mergeStatus" == "$UNMERGED_STATUS" ];
    then 
        echo true
    else 
        echo false
    fi
}

function isPRCloseAndMerged {
    log "Function isPRCloseAndMerged"

    local pr_num=$1

    local prDetails=$(getCall "$GIT_PR_API" "$pr_num")
    local prStatus=$(echo "$prDetails" | jq -r '.state')
    local mergeStatus=$(getMergeStatus "$pr_num")

    log "Debug: PR status $prStatus of $pr_num"
    log "Debug: Merge status $mergeStatus of $pr_num"

    if [ "$prStatus" == 'closed' ] && [ "$mergeStatus" == "$MERGED_STATUS" ];
    then 
        echo true
    else 
        echo false
    fi
}

function isApproved {
    log "Function isApproved"

    local approvalCount=0
    local prStatus="$1"

    # States are returned in chronological order
    local loginNames=($(jq -r '.[].user.login' <<< "${prStatus}"))
    local reviewStates=($(jq -r '.[].state' <<< "${prStatus}"))

    local j=0

    # Store all reviews
    while [ ${#loginNames[@]} -gt $j ]; do
        review_set "${loginNames[$j]}" "${reviewStates[$j]}"

        j=$((j+1))
    done

    
    local i=0
    while [ ${#loginNames[@]} -gt $i ]; do
        local loginName="${loginNames[$i]}"

        local loginCount=$(login_get $loginName)
        
        if [ $loginCount -eq 0 ]; then

            login_set "$loginName"

            # Get the latest review
            local latestState=$(review_get $loginName)
            
            log "Debug: Latest state $latestState for $loginName"

            if [ "$latestState" == "$PR_CHANGES_REQUESTED" ];
            then 
                changesRequested=true
                break
            elif [ "$latestState" == "$PR_APPROVED" ]; 
            then
                approvalCount=$((approvalCount+1))
            fi
        fi

        i=$((i+1))
    done

    log "Debug: Approval count $approvalCount"
    
    if [ "$changesRequested" == true ];
    then
        log "Debug: Changes requested"
        echo false
    elif [ $approvalCount -ge $DEFAULT_APPROVAL_COUNT ];
    then
        echo true
    else
        echo false
    fi

    review_flush
    login_flush
}

function updatePR {
    log "Function updatePR"

    local pr_num=$1


    local prDetails=$(getCall "$GIT_PR_API" "$pr_num")
    local prBranch=$(echo "$prDetails" | jq -r '.head.ref')

    local updateStatus=$(curl -s -X POST -u "$GIT_NAME":"$GIT_TOKEN" -H "Content-Type: application/json" "$GIT_MERGE_API" -d ' 
    {
        "base": '\"$prBranch\"',
        "head": '\"$BASE_BRANCH\"'
    }')

    local conflictCount=$(grep -o -i 'Merge Conflict' <<< "$updateStatus" | wc -l)

    if [ $conflictCount -eq 0 ];
    then
        echo true
    else
        log "$CONFLICT_STATUS $pr_num"
        echo false
    fi
}

function checkReadyToBuild {
    log "Function checkReadyToBuild"

    local pr_num=$1

    local reviewDetails=$(getCall "$GIT_REVIEWS_API" "$pr_num")

    local isPRValid=$(isPROpenAndUnmerged "$pr_num")
    local approved=$(isApproved "$reviewDetails")
    local isUpdateSuccessful=$(updatePR "$pr_num")

    if [ "$isPRValid" == true ] && [ "$approved" == true ] && [ "$isUpdateSuccessful" == true ];
    then
        log "PR $pr_num ready to build"
        echo true
    else
        log "PR $pr_num not ready to build"
        echo false
    fi
}

function triggerCommentBuild {
    log "Function triggerBuild"

    local pr_num=$1

    local commentsApi=$(printf "$GIT_ISSUES_COMMENTS_API" "$pr_num")

    curl -s -X POST -u "$GIT_NAME":"$GIT_TOKEN" -H "Content-Type: application/json" "$commentsApi" -d ' 
    {
        "body": "OK to test"
    }'

    log "Build triggered for $pr_num"
}