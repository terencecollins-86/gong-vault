#!/usr/bin/env bash
#
# simulate-entrypoints.sh — gentle, continuous entry-point simulator for
# IngesterTelephonySystemsSupervisor.
#
# WHAT IT DOES
#   Walks a curated list of NON-DESTRUCTIVE troubleshooter endpoints and fires
#   one curl at a time, sleeping a few seconds between each, looping forever.
#   This keeps the locally-running Supervisor lightly busy so any breakpoint you
#   set gets hit on the next cycle — no need to re-send requests from Postman.
#
# THE BREAKPOINT TRICK (--max-time)
#   Each curl uses a short --max-time. When your debugger pauses a request's
#   server thread, curl gives up after MAX_TIME seconds and the loop moves on,
#   so the app keeps receiving steady traffic while you inspect the paused
#   thread. The HTTP code logged for a paused request will be 000 (timeout).
#
# ENTRY-POINT TYPES COVERED
#   REST troubleshooters (directly) · Kafka via the process-one-event HTTP twin ·
#   SQS via runChainNow / sqs/sendMessage · scheduled tasks via
#   /troubleshooting/tasks/{id}/run (tasks register only under the Dev profile,
#   which the run config activates).
#
# REQUIREMENTS
#   bash + curl. Nothing else. Service must be up on $BASE_URL with profiles
#   Dev,Local (IntelliJ run config IngesterTelephonySystemsSupervisorInitializer,
#   port 8097) and the seed loaded (dev/seed-dialers-local.sql).
#
# USAGE
#   bash dev/simulate-entrypoints.sh                 # loop forever (Ctrl-C to stop)
#   bash dev/simulate-entrypoints.sh --once          # one pass, then exit
#   bash dev/simulate-entrypoints.sh --list          # print endpoints, make NO calls
#   bash dev/simulate-entrypoints.sh --include-mutating  # add the 2nd (mutating) tier
#   bash dev/simulate-entrypoints.sh -h | --help
#
# ENV-VAR KNOBS (all overridable; defaults mirror the Postman collection)
#   BASE_URL=http://localhost:8097   COMPANY_ID=9001   INTEGRATION_ID=9001
#   INTEGRATION_FLAVOR=GONG_CONNECT_API   PROVIDER_CALL_ID=gc-call-aaa-001
#   CALL_IDS=100001,100002   SLEEP=3 (sec between requests)   MAX_TIME=5 (per-request)
#   CYCLE_PAUSE=0 (extra sec between full passes)
#
# NOTE: process-one-event, syncOneCall, runChainNow, sqs/sendMessage and the
#   S3/provider reads hit external systems (provider APIs, AWS, SQS) that aren't
#   wired locally. They return errors but DO execute the entry point and trip
#   breakpoints — which is the whole point.

set -u

# ---- Config (env-overridable) ------------------------------------------------
BASE_URL="${BASE_URL:-http://localhost:8097}"
COMPANY_ID="${COMPANY_ID:-9001}"
INTEGRATION_ID="${INTEGRATION_ID:-9001}"
INTEGRATION_FLAVOR="${INTEGRATION_FLAVOR:-GONG_CONNECT_API}"
PROVIDER_CALL_ID="${PROVIDER_CALL_ID:-gc-call-aaa-001}"
CALL_IDS="${CALL_IDS:-100001,100002}"
SLEEP="${SLEEP:-3}"
MAX_TIME="${MAX_TIME:-5}"
CYCLE_PAUSE="${CYCLE_PAUSE:-0}"

# ---- Flags -------------------------------------------------------------------
ONCE=0
LIST=0
INCLUDE_MUTATING=0

usage() {
    sed -n '2,60p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
    case "$1" in
        --once)              ONCE=1 ;;
        --list)              LIST=1 ;;
        --include-mutating)  INCLUDE_MUTATING=1 ;;
        -h|--help)           usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; echo "Try --help." >&2; exit 2 ;;
    esac
    shift
done

# ---- Endpoint table ----------------------------------------------------------
# Records are pipe-delimited: METHOD|PATH|CONTENT_TYPE|BODY
#   PATH is relative to $BASE_URL and may embed the config vars below.
#   CONTENT_TYPE and BODY are empty where not needed.
# The JSON process-one-event body is the one from the Postman collection.
PROCESS_EVENT_BODY="{\"companyId\":${COMPANY_ID},\"providerIdentifier\":\"${PROVIDER_CALL_ID}\",\"providerIdentifierType\":\"ENGAGE_DIALER\",\"providerName\":\"gong-connect\",\"ownerIdentifier\":[],\"startTime\":\"2024-01-01T10:00:00Z\",\"endTime\":\"2024-01-01T10:05:00Z\",\"fromNumber\":\"+15550001001\",\"toNumber\":\"+15550001002\",\"direction\":\"OUTBOUND\",\"additionalData\":{}}"
SYNCJOB_BODY="message={\"companyId\":${COMPANY_ID},\"integrationId\":${INTEGRATION_ID},\"integrationFlavorId\":\"${INTEGRATION_FLAVOR}\",\"backfill\":false}"

ENDPOINTS=(
    # --- Health / discovery ---
    "GET|/||"
    "GET|/v3/api-docs||"

    # --- Scheduled tasks (Dev profile) ---
    "GET|/troubleshooting/tasks||"
    "GET|/troubleshooting/tasks/run||"
    "POST|/troubleshooting/tasks/heartbeat/run||"

    # --- Push: telephony call events (Kafka twin) ---
    "POST|/troubleshooting/telephony-call-events/generic/telephony-call-event/process-one-event?integration-flavor=${INTEGRATION_FLAVOR}|application/json|${PROCESS_EVENT_BODY}"
    "POST|/troubleshooting/telephony-call-events/generic/telephony-call-event/generate-datadog-issues?companyId=${COMPANY_ID}&integrationId=${INTEGRATION_ID}&integration-flavor=${INTEGRATION_FLAVOR}||"

    # --- PCI-compliant troubleshooter (zero-arg smoke + idempotent reads) ---
    "POST|/troubleshooting/telephony-system-pci-compliant/generic/backfill/backfillMarkedTSs||"
    "POST|/troubleshooting/telephony-system-pci-compliant/generic/backfill/markChangedUsers||"
    "POST|/troubleshooting/telephony-system-pci-compliant/generic/calls/syncOneCall?company-id=${COMPANY_ID}&integration-id=${INTEGRATION_ID}&providerCallId=${PROVIDER_CALL_ID}&callDate=2024-01-01T00:00:00Z||"

    # --- SQS async-trigger entry points ---
    "POST|/troubleshooting/time-based-events-sync-infra/syncJobInfra/SyncJobChain/runChainNow?company-id=${COMPANY_ID}&integration-id=${INTEGRATION_ID}&is-backfill=false||"
    "POST|/troubleshooting/time-based-events-sync-infra/sqs/sendMessage?high-priority=true|application/x-www-form-urlencoded|${SYNCJOB_BODY}"

    # --- Reads / smoke tests across the other troubleshooters ---
    "GET|/troubleshooting/integrations/list/all-integrations?company-id=${COMPANY_ID}||"
    "GET|/troubleshooting/salesforce/object/describeCompanyTasks?company-id=${COMPANY_ID}&fromDate=2024-01-01T00:00:00Z&toDate=2024-12-31T23:59:59Z&limit=100||"
    "GET|/troubleshooting/dialpad/list/users?company-id=${COMPANY_ID}&filter-email=||"
    "POST|/troubleshooting/sms/dialpad/is-token-valid?token=tok_dp_beta_dev_placeholder||"
    "GET|/troubleshooting/telephony-systems-sms/generic/list-users?company-id=${COMPANY_ID}&integration-id=${INTEGRATION_ID}&messages-provider=DIALPAD||"
    "GET|/troubleshooting/ssh-public-key/list-company-access-keys?company-id=${COMPANY_ID}||"
    "GET|/troubleshooting/crm-info-retrieval/get/call-associated-accounts?company-id=${COMPANY_ID}&call-id=100001||"
    "POST|/troubleshooting/call-activity-store-ingestion/getCallsMetadataByCallIds?company-id=${COMPANY_ID}&comma-separated-call-ids=${CALL_IDS}||"
    "GET|/troubleshooting/provider-data-access/troubleshooting-dialers/provider-data/list-users?company-id=${COMPANY_ID}&integration-id=${INTEGRATION_ID}||"
    "GET|/troubleshooting/front/is-connection-name-exists?company-id=${COMPANY_ID}&integration-id=${INTEGRATION_ID}&connection-name=Acme%20Corp||"
    "GET|/troubleshooting/public-api-basic-auth-credentials/get-credentials?company-id=${COMPANY_ID}&descriptor-id=ingestertelephonysystemssupervisor||"
    "POST|/troubleshooting/s3/generic/s3/listFolders?company-id=${COMPANY_ID}&integration-id=${INTEGRATION_ID}&bucket=acme-recordings-dev||"
    "GET|/troubleshooting/s3-events/listEventsForCompanyAndIntegration?company-id=${COMPANY_ID}&integration-id=${INTEGRATION_ID}&from=2024-01-01T00:00:00Z&till=2024-12-31T23:59:59Z||"
)

# Second tier — reversible state changes, only fired with --include-mutating.
# Each line is commented with what it mutates.
MUTATING_ENDPOINTS=(
    # toggles the backfill flag for one company+integration
    "POST|/troubleshooting/telephony-system-pci-compliant/generic/backfill/setBackfillStatus?company-id=${COMPANY_ID}&integration-id=${INTEGRATION_ID}&shouldSetBackfill=true||"
    # rewinds the sync watermark for one company
    "POST|/troubleshooting/telephony-system-pci-compliant/generic/company/sync/setSyncTime/single-company?company-id=${COMPANY_ID}&integration-id=${INTEGRATION_ID}&is-initial-sync=true&sync-date-from=2024-01-01&sync-date-to=2024-01-31||"
    # rewinds the sync watermark for multiple companies by provider
    "POST|/troubleshooting/telephony-system-pci-compliant/generic/company/sync/setSyncTime/multiple-companies?integration-flavor=${INTEGRATION_FLAVOR}&is-initial-sync=true&sync-date-from=2024-01-01&companyIds=${COMPANY_ID}||"
    # inserts call_provider_data rows for the given ids
    "POST|/troubleshooting/telephony-system-pci-compliant/generic/calls/insertCallIds|application/x-www-form-urlencoded|integration-flavor=${INTEGRATION_FLAVOR}&company-id=${COMPANY_ID}&integration-id=${INTEGRATION_ID}&callIds=${CALL_IDS}"
    # re-processes already-imported calls (re-associate / re-title)
    "POST|/troubleshooting/telephony-system-pci-compliant/generic/calls/redoCalls/redoExistingCall|application/x-www-form-urlencoded|callIds=${CALL_IDS}&associateCalls=true&updateTitles=true&priority=MEDIUM"
    # reassigns the owner of the given calls
    "POST|/troubleshooting/telephony-system-pci-compliant/generic/calls/changeCallOwner|application/x-www-form-urlencoded|company-id=${COMPANY_ID}&new-owner-id=502&callIds=${CALL_IDS}"
    # stores a hashed SFTP password (body is the password)
    "POST|/troubleshooting/sftp/add-hashed-password?company-id=${COMPANY_ID}&integration-id=${INTEGRATION_ID}|text/plain|dev-sftp-password-placeholder"
    # migrates one user's user-defined phone numbers
    "POST|/troubleshooting/user-defined-phone-numbers/migrate_user?company-id=${COMPANY_ID}&app-user-id=501||"
    # releases the enable-recording sync lock
    "POST|/troubleshooting/recording-interceptor/generic/freeSyncLock?company-id=${COMPANY_ID}&integration-id=${INTEGRATION_ID}&is-initial-sync=false||"
    # clears integration-failure state for the company on the flavor
    "POST|/troubleshooting/integration/failure/reset?company-id=${COMPANY_ID}&integration-flavor=${INTEGRATION_FLAVOR}&integration-id=${INTEGRATION_ID}||"
)

if [ "$INCLUDE_MUTATING" -eq 1 ]; then
    ENDPOINTS+=("${MUTATING_ENDPOINTS[@]}")
fi

# ---- Helpers -----------------------------------------------------------------
REQUEST_COUNT=0

# fire METHOD PATH CONTENT_TYPE BODY — run one curl, print a compact status line.
fire() {
    local method="$1" path="$2" ctype="$3" body="$4"
    local args=(-s -o /dev/null -w '%{http_code}|%{time_total}' --max-time "$MAX_TIME" -X "$method")
    [ -n "$ctype" ] && args+=(-H "Content-Type: ${ctype}")
    [ -n "$body" ]  && args+=(--data "$body")

    local out code time_total
    out="$(curl "${args[@]}" "${BASE_URL}${path}" 2>/dev/null)"
    code="${out%%|*}"
    time_total="${out##*|}"
    [ -z "$code" ] && code="000"
    [ -z "$time_total" ] && time_total="0"

    printf '[%s] %-4s %-90s -> HTTP %s (%ss)\n' \
        "$(date +%H:%M:%S)" "$method" "${path:0:90}" "$code" "$time_total"
    REQUEST_COUNT=$((REQUEST_COUNT + 1))
}

# ---- --list: print endpoints and exit (no HTTP calls) ------------------------
if [ "$LIST" -eq 1 ]; then
    echo "BASE_URL=${BASE_URL}  COMPANY_ID=${COMPANY_ID}  INTEGRATION_ID=${INTEGRATION_ID}  FLAVOR=${INTEGRATION_FLAVOR}"
    echo "Endpoints that WOULD be hit (--include-mutating=${INCLUDE_MUTATING}):"
    n=0
    for rec in "${ENDPOINTS[@]}"; do
        IFS='|' read -r method path ctype body <<< "$rec"
        n=$((n + 1))
        printf '  %2d. %-4s %s\n' "$n" "$method" "${BASE_URL}${path}"
    done
    echo "Total: ${n} endpoints. Made 0 HTTP calls (--list)."
    exit 0
fi

# ---- Preflight: is the service up? -------------------------------------------
if ! curl -s -o /dev/null --max-time "$MAX_TIME" "${BASE_URL}/" 2>/dev/null; then
    echo "ERROR: service not up on ${BASE_URL} — start it with the Dev,Local run config" >&2
    echo "       (IntelliJ: IngesterTelephonySystemsSupervisorInitializer, port 8097)." >&2
    exit 1
fi

# ---- Clean exit on Ctrl-C ----------------------------------------------------
trap 'echo; echo "Stopped after ${REQUEST_COUNT} requests."; exit 0' INT

# ---- Main loop ---------------------------------------------------------------
CYCLE=0
while true; do
    CYCLE=$((CYCLE + 1))
    [ "$ONCE" -eq 0 ] && echo "=== cycle ${CYCLE} ==="
    for rec in "${ENDPOINTS[@]}"; do
        IFS='|' read -r method path ctype body <<< "$rec"
        fire "$method" "$path" "$ctype" "$body"
        sleep "$SLEEP"
    done
    if [ "$ONCE" -eq 1 ]; then
        echo "Done — one pass, ${REQUEST_COUNT} requests."
        break
    fi
    [ "$CYCLE_PAUSE" -gt 0 ] && sleep "$CYCLE_PAUSE"
done
