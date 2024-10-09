#!/bin/bash -e

COMMAND=$1
LOCKREF=$2
TRAILER=$3

# How many times we try to lock safely before giving up.
RETRIES=5
# How many seconds to delay before trying again (grows exponentially).
BACKOFF=2

# This script lets us coordinate deploy jobs across multiple pipelines by using git-notes as a primitive mutex.
# It's not an ideal solution, but gets the job done to prevent atlas deploy jobs from colliding for the same change.

function lock() {
    ENQUEUED=false

    # Acquire deploy lock
    while [ $RETRIES -gt 0 ]; do
        # Get the current queue status from origin, replacing our local copy.
        if ! git fetch origin "+$LOCKREF:$LOCKREF" > /dev/null; then
            echo "Lock in '$LOCKREF' not found on remote or fetch failed, continuing..."
        fi

        # Add ourselves to the local copy of the queue.
        git notes --ref "$LOCKREF" append -m "$TRAILER"

        # Attempt to push. If we fail, we raced with someone, and need to try to enqueue ourselves again.
        if ! git push origin "$LOCKREF"; then
            RETRIES=$((RETRIES-1))

            echo "Couldn't enqueue operation, sleeping $BACKOFF seconds and trying again..."
            sleep $BACKOFF
            BACKOFF=$((BACKOFF*2))
            continue
        fi

        # We have successfully enqueued ourselves, and may or may not have the lock (depending on if we're first).
        ENQUEUED=true
        break
    done

    [ "$ENQUEUED" == "true" ] || (echo "Couldn't acquire lock, giving up." && exit 0)

    # Reset the retry counter.
    RETRIES=5
    # Make backoff times longer for re-checking lock acquisition, since the deploy operation can take some time.
    BACKOFF=30
    while [ $RETRIES -gt 0 ] && ! git notes --ref "$LOCKREF" show | head -n 1 | grep "$TRAILER" ; do
        RETRIES=$((RETRIES-1))
        echo "Another operation is in progress, waiting $BACKOFF seconds and trying again..."
        sleep $BACKOFF
        BACKOFF=$((BACKOFF*2))

        git fetch origin "+$LOCKREF:$LOCKREF" > /dev/null || true
        continue
    done
}

function unlock() {
    # Release deploy lock and publish deployed URL
    while [ $RETRIES -gt 0 ]; do
        if ! git fetch origin "+$LOCKREF:$LOCKREF" > /dev/null; then
            echo "Lock in '$LOCKREF' not found on remote or fetch failed, continuing..."
        fi

        # Take us out of the (local copy of the) queue by removing the line which mentions our job.
        git notes --ref "$LOCKREF" show |\
          grep -v "$TRAILER" |\
          git notes --ref "$LOCKREF" add -f -F - || true

        # Attempt to push. If we fail, we raced with someone, and need to try to dequeue ourselves again.
        echo "Removing ourselves from the deployment queue for $CI_COMMIT_REF_SLUG..."
        if ! git push origin "$LOCKREF"; then
            RETRIES=$((RETRIES-1))

            echo "Couldn't dequeue, sleeping $BACKOFF seconds and trying again..."
            sleep $BACKOFF
            BACKOFF=$((BACKOFF*2))
            continue
        fi

        # Successfully dequeued
        break
    done
}

case "$COMMAND" in
    "lock") lock;;
    "unlock") unlock;;
    *) echo "Unknown command $COMMAND" > /dev/stderr; exit 1;;
esac
