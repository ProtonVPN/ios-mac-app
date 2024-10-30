#!/bin/bash -e

SPRINT_FIELD=customfield_10020
STORY_POINTS_FIELD=customfield_10035
RELEASE_NOTES_FIELD=customfield_10189
JIRA_PROJECT=VPNAPPL
JIRA_TRAILER=Jira-Id

# Can be any train, since they all store at the same attrs reference.
# If this ever changes in the future, issue-hashes.txt should include the train name.
LHC_TRAIN=ios
RELEASE_NOTES_ATTR=Release-Notes

# Other environment variables required:
# - PIPELINE_ACCESS_TOKEN: a project access token for your GitLab repository
# - JIRA_API_TOKEN: a read-only API access token for your Jira project
# - JIRA_API_URL: the API url for your Jira organization
# - JIRA_NEW_RELEASE_WEBHOOK: a webhook for creating releases (with associated issues) in Jira
# - JIRA_SHIP_RELEASE_WEBHOOK: a webhook for marking releases as shipped in Jira

ISSUE_HASHES=""
MILESTONE_ID=""
ISSUES_JSON=""
SPRINT_NAME=""

# Different API locations on GitLab.
PROJECT_API_URL="$CI_SERVER_URL/api/v4/projects/$CI_PROJECT_ID"
MILESTONES_API_URL="$PROJECT_API_URL/milestones"
MERGE_REQUEST_API_URL="$PROJECT_API_URL/merge_requests/$CI_MERGE_REQUEST_IID"

# If CI_MERGE_REQUEST_DIFF_BASE_SHA is set, then use it.
# Otherwise, if GIT_DEPTH is set, go back $GIT_DEPTH commits.
# Otherwise, go back 50 commits.
COMMIT_RANGE="${CI_MERGE_REQUEST_DIFF_BASE_SHA:-HEAD~${GIT_DEPTH:-50}}..HEAD"

# Jira only lets us bulk-fetch 100 issues at a time.
BULK_ISSUE_LIMIT=100

function fetch_data() {
    ISSUE_LIST=$(sed "s/^\([0-9a-f]\)\([0-9a-f]\)* \($JIRA_PROJECT-[0-9][0-9]*\)$/\"\3\",/g" <<<"$ISSUE_HASHES" | head -n "$BULK_ISSUE_LIMIT" | tr -d '\n')

    REQUEST_DATA="
{
    \"expand\": [\"names\"],
    \"fields\": [\"summary\", \"$SPRINT_FIELD\", \"$RELEASE_NOTES_FIELD\", \"$STORY_POINTS_FIELD\"],
    \"fieldsByKeys\": true,
    \"properties\": [],
    \"issueIdsOrKeys\": [${ISSUE_LIST%?}]
}"

    ISSUES_JSON=$(curl -s -X POST \
         -H "Content-Type: application/json" \
         -u "$JIRA_API_TOKEN" \
         "${JIRA_API_URL}/rest/api/3/issue/bulkfetch" \
         -d "$REQUEST_DATA")
}

UPDATED_ISSUES=""
function update_commit() {
    local commit_hash=$(cut <<<"$1" -d " " -f 1)
    local task_id=$(cut <<<"$1" -d " " -f 2)

    if grep "^${task_id}$" <<<"$UPDATED_ISSUES" > /dev/null; then
        # Already seen this issue, continue
        return 0
    fi

    local issue_json
    issue_json=$(jq -r <<<"$ISSUES_JSON" ".issues[] | select(.key == \"${task_id}\")")

    local notes=$(jq -r <<<"$issue_json" ".fields.$RELEASE_NOTES_FIELD | select(. != null and .version == 1) | .content[].content[].text")
    local points=$(jq -r <<<"$issue_json" ".fields.$STORY_POINTS_FIELD")

    UPDATED_ISSUES+="$task_id"$'\n'

    if [ -n "$notes" ] && [ "$notes" != "null" ]; then
        local old_release_notes
        old_release_notes=$(mint run -s git-lhc attr get --train $LHC_TRAIN Release-Notes $commit_hash || true)

        if [ "$old_release_notes" != "$notes" ]; then
            echo "Adding Release-Notes attribute..."
            mint run -s git-lhc attr add --train $LHC_TRAIN --force "Release-Notes=$notes" $commit_hash
        fi
    fi

    if [ -n "$points" ] && [ "$points" != "null" ]; then
        local old_story_points
        old_story_points=$(mint run -s git-lhc attr get --train $LHC_TRAIN Story-Points $commit_hash || true)

        if [ "$old_story_points" != "$points" ]; then
            echo "Adding Story-Points attribute..."
            mint run -s git-lhc attr add --train $LHC_TRAIN --force "Story-Points=$points" $commit_hash
        fi
    fi
}

function update_commits() {
    echo "Updating commits..."
    IFS=$'\n'
    for logentry in $(git log "$COMMIT_RANGE" --format="%H"); do
        local entries
        if ! entries=$(grep "$logentry" <<<"$ISSUE_HASHES"); then
            continue
        fi

        for entry in $entries; do
            update_commit $entry
        done
    done
}

function update_merge_request() {
    [ -n "$CI_MERGE_REQUEST_IID" ] || return 0

    local quick_actions=""

    if [ -n "$MILESTONE_ID" ]; then
        local milestone_mr_count
        # check if the milestone has already been assigned to this MR
        milestone_mr_count=$(curl -s -X GET \
            -H "Authorization: Bearer $PIPELINE_ACCESS_TOKEN" \
            "$MILESTONES_API_URL/$MILESTONE_ID/merge_requests" | \
            jq -r "[.[] | select(.iid == $CI_MERGE_REQUEST_IID)] | length")

        # if it's not assigned, assign it
        if [ "$milestone_mr_count" -eq 0 ]; then
            quick_actions+="/milestone $SPRINT_NAME\\r\\n"
        fi
    fi

    # if the merge request doesn't have any labels, then apply one according to the commit type of the first
    # recognizable type that we see (if it exists).
    if [ -z "$CI_MERGE_REQUEST_LABELS" ]; then
        IFS=$'\n'
        local label_name
        for subject in $(git log $COMMIT_RANGE --format="%s"); do
            case "$subject" in
                fix*) label_name="Fix"; break;;
                feat*) label_name="Feature"; break;;
                refactor*) label_name="Refactor"; break;;
                test*) label_name="Tests"; break;;
                Revert*) label_name="Revert"; break;;
                *) continue ;;
            esac
        done

        [ -z "$label_name" ] || quick_actions+="/label ~$label_name\\r\\n"
    fi

    if [ -z "$quick_actions" ]; then
        echo 'Merge request up to date!'
        return 0
    fi

    # Add the attributes to the merge request.
    curl -s -X POST \
         -H "Content-Type: application/json" \
         -H "Authorization: Bearer $PIPELINE_ACCESS_TOKEN" \
         "$MERGE_REQUEST_API_URL/notes" \
         -d "{ \"body\": \"$quick_actions\" }" > /dev/null

    echo "Merge request $CI_MERGE_REQUEST_IID updated: $quick_actions"
}

function update_active_sprint() {
    local sprint_json sprint_goal sprint_start gitlab_sprint_start gitlab_sprint_end

    sprint_json=$(jq -r <<<"$ISSUES_JSON" "[.issues[].fields.$SPRINT_FIELD | select(. != null) | flatten | add | select(.state == \"active\")][0]")

    [ "$sprint_json" != "null" ] || return 0

    SPRINT_NAME=$(jq -r <<<"$sprint_json" ".name")

    sprint_goal=$(jq -r <<<"$sprint_json" ".goal")
    sprint_start=$(jq -r <<<"$sprint_json" ".startDate")
    gitlab_sprint_start=$(jq -r <<<"$sprint_json" ".startDate | split(\"T\")[0]")
    gitlab_sprint_end=$(jq -r <<<"$sprint_json" ".endDate | split(\"T\")[0]")

    [ -n "$SPRINT_NAME" ] || return 0
    echo "Detected sprint $SPRINT_NAME..."

    echo "Querying existing milestones..."
    local milestones
    milestones=$(curl -s -X GET \
        -H "Authorization: Bearer $PIPELINE_ACCESS_TOKEN" \
        --data-urlencode "title=$SPRINT_NAME" \
        "$MILESTONES_API_URL")

    if [ $(jq -r <<<"$milestones" length) -eq 0 ]; then
        echo "Creating milestone $SPRINT_NAME..."

        milestones=$(curl -s -X POST \
             -H "Content-Type: application/json" \
             -H "Authorization: Bearer $PIPELINE_ACCESS_TOKEN" \
             -d "{ \"title\": \"$SPRINT_NAME\", \"description\": \"$sprint_goal\", \"due_date\": \"$gitlab_sprint_end\", \"start_date\": \"$gitlab_sprint_start\" }" \
             "$MILESTONES_API_URL" | jq -r '[.]')
    fi

    MILESTONE_ID=$(jq -r <<<"$milestones" ".[0].id")

    local sprint_timestamp sprint_started_hash
    sprint_timestamp=$(sed 's/\.[0-9][0-9]*Z$//g' <<<"$sprint_start" | xargs date -jf "%Y-%m-%dT%H:%M:%S" +%s)

    IFS=$'\n'
    # Go through the commits by timestamp, and mark the closest one to where the sprint started.
    for entry in $(git log "$COMMIT_RANGE" --format="%H %ct"); do
        local commit_timestamp=$(cut -d " " -f 2 <<<"$entry")
        [ "$sprint_timestamp" -lt "$commit_timestamp" ] || break

        sprint_started_hash=$(cut -d " " -f 1 <<<"$entry")
    done

    if [ -n "$sprint_started_hash" ]; then
        local old_sprint_started
        old_sprint_started=$(mint run -s git-lhc attr get --train $LHC_TRAIN Sprint-Started $sprint_started_hash || true)

        if [ "$old_sprint_started" != "$SPRINT_NAME" ]; then
            echo "Adding Sprint-Started attribute..."
            mint run -s git-lhc attr add --train $LHC_TRAIN --force "Sprint-Started=$SPRINT_NAME" $sprint_started_hash
        fi
    fi
}

function update_release() {
    local channel="$1"
    local release_name="$2"
    local release_issues="$3"
    local jira_webhook_url

    case "$channel" in
        "alpha") jira_webhook_url=$JIRA_NEW_RELEASE_WEBHOOK ;;
        "beta") jira_webhook_url=$JIRA_SHIP_RELEASE_WEBHOOK ;;
        *) return 0 ;; # Don't do anything for prod builds, alpha/beta are enough
    esac

    # Send the request. JIRA_WEBHOOK_URL is defined in each Jira automation.
    echo "Updating tasks in Jira..."
    echo curl -X POST -H 'Content-type: application/json' \
        --data "{\"releaseName\":\"$release_name\",\"issues\":[$release_issues]}" \
        $jira_webhook_url
}

if [ "$#" -eq 0 ]; then
    ISSUE_HASHES=$(git log $COMMIT_RANGE --format="%H %(trailers:key=$JIRA_TRAILER,valueonly)" | grep "$JIRA_PROJECT" | head -n 1)
else
    for arg in "$@"; do
        [ -f "$arg" ] || (echo "No such file $arg. Aborting." && exit 1)

        # Remove the first line from each file, since it contains the train information which we don't care about
        ISSUE_HASHES+=$(sed "1d" < "$arg" | grep "$JIRA_PROJECT")
        ISSUE_HASHES+=$'\n'

        if [ -n "$CI_COMMIT_TAG" ]; then
            train_info=$(head -n 1 "$arg")
            channel=$(cut -d ':' -f 1 <<<"$train_info")
            release_name=$(sed "s/^${channel}: //" <<<"$train_info")

            release_issues=$(cut -d ' ' -f 2 < "$arg" | sort | uniq | tr '\n' ',')
            release_issues=${release_issues%?} # remove trailing comma

            update_release "$channel" "$release_name" "$release_issues"
        fi
    done

    # We don't care about the order, we'll be traversing in git log order anyway.
    ISSUE_HASHES=$(sort <<<"$ISSUE_HASHES" | uniq)
fi

[ -n "$ISSUE_HASHES" ] || exit 0

fetch_data
update_commits
update_active_sprint
update_merge_request
