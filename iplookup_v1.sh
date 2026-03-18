#!/usr/bin/env bash
# =============================================================================
# iplookup.sh — IP Address Lookup Tool
#
# Performs a longest-prefix-match against one of three CSV datasets and
# prints all fields for the best-matching network.
#
# Datasets (place in the same directory as this script):
#   all_IP_networks.csv  — default
#   cidr_16.csv          — selected with -C16
#   cidr_24.csv          — selected with -C24
#
# Usage:    iplookup.sh -l <IP> [-C16|-C24] [-a] [-d] [-h]
# Requires: bash 3.2+, any POSIX awk (macOS awk, gawk, mawk, nawk)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LOOKUP_IP=""
DATASET="all"
DEBUG=false
ALL_FIELDS=false

if [ -t 1 ]; then
    BOLD="\033[1m"; DIM="\033[2m"; RED="\033[0;31m"; GREEN="\033[0;32m"
    YELLOW="\033[1;33m"; CYAN="\033[0;36m"; BLUE="\033[0;34m"; RESET="\033[0m"
else
    BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; CYAN=""; BLUE=""; RESET=""
fi

usage() {
cat <<EOF
${BOLD}Usage:${RESET}
  $(basename "$0") -l <IP_ADDRESS> [OPTIONS]

${BOLD}Options:${RESET}
  -l <IP>   IPv4 address to look up  (required)
  -C16      Use the /16 CIDR dataset  (cidr_16.csv)
  -C24      Use the /24 CIDR dataset  (cidr_24.csv)
            Default dataset: all_IP_networks.csv
  -a        Show all fields including NAUTOBOT_PHONE, NAUTOBOT_ADDRESS, SITE_CODES
  -d        Enable debug output
  -h        Show this help message

${BOLD}Examples:${RESET}
  $(basename "$0") -l 10.0.0.5
  $(basename "$0") -l 10.0.0.5 -C16
  $(basename "$0") -l 10.0.0.5 -C24
  $(basename "$0") -l 192.168.1.50 -d
  $(basename "$0") -l 172.16.10.0 -C16 -a

${BOLD}Notes:${RESET}
  * Longest-prefix-match: the most specific network containing the IP wins.
  * CSV data files must live in the same directory as this script.
  * Works with any POSIX awk (macOS awk, gawk, mawk, nawk).
EOF
}

dbg() { $DEBUG && echo -e "${DIM}[DEBUG] $*${RESET}" >&2 || true; }
die() { echo -e "${RED}[ERROR] $*${RESET}" >&2; exit 1; }

validate_ip() {
    local ip="$1"
    local IFS='.'
    read -ra oct <<< "$ip"
    [[ ${#oct[@]} -eq 4 ]] || return 1
    local o
    for o in "${oct[@]}"; do
        [[ "$o" =~ ^[0-9]+$ ]]           || return 1
        [[ "$o" -ge 0 && "$o" -le 255 ]] || return 1
    done
}

ip_to_int() {
    local IFS='.'
    read -ra o <<< "$1"
    IP_INT=$(( o[0]*16777216 + o[1]*65536 + o[2]*256 + o[3] ))
}

print_field() {
    local key="$1" val="$2"
    # Suppress noisy fields unless -a or -d is set
    if ! $DEBUG && ! $ALL_FIELDS; then
        case "$key" in
            NAUTOBOT_PHONE|NAUTOBOT_ADDRESS|SITE_CODES) return ;;
        esac
    fi
    if [[ -n "$val" ]]; then
        printf "  ${CYAN}%-32s${RESET} %s\n" "${key}:" "$val"
    elif $DEBUG; then
        printf "  ${CYAN}%-32s${RESET} ${DIM}<empty>${RESET}\n" "${key}:"
    fi
}

parse_csv_line() {
    CSV_FIELDS=()
    local line="$1" field="" in_q=false i=0 len ch nx
    len=${#line}
    while [[ $i -lt $len ]]; do
        ch="${line:$i:1}"
        if $in_q; then
            if [[ "$ch" == '"' ]]; then
                nx="${line:$(( i+1 )):1}"
                if [[ "$nx" == '"' ]]; then field+='"'; i=$(( i+1 ))
                else in_q=false; fi
            else field+="$ch"; fi
        else
            case "$ch" in
                '"') in_q=true ;;
                ',') CSV_FIELDS+=("$field"); field="" ;;
                *)   field+="$ch" ;;
            esac
        fi
        i=$(( i+1 ))
    done
    CSV_FIELDS+=("$field")
}

# ---------------------------------------------------------------------------
# AWK program — portable POSIX, no gawk extensions required.
# Finds the CIDR column, runs longest-prefix-match over all rows, outputs
# structured key:value lines for bash to consume.
# ---------------------------------------------------------------------------
read -r -d '' AWK_PROGRAM << 'AWKEOF'
BEGIN {
    FS = ","
    best_prefix = -1
    cidr_col = 0
}

function bitand(a, b,    r, p) {
    r = 0; p = 1
    while (a > 0 || b > 0) {
        if ((a % 2) == 1 && (b % 2) == 1) r += p
        a = int(a / 2); b = int(b / 2); p *= 2
    }
    return r
}

function ip_to_int(ip,    a, n) {
    n = split(ip, a, ".")
    if (n != 4) return -1
    return a[1]*16777216 + a[2]*65536 + a[3]*256 + a[4]+0
}

function in_cidr(qi, net, prefix,    ni, mask) {
    ni = ip_to_int(net)
    if (ni < 0) return 0
    if (prefix == 32) return (qi == ni)
    if (prefix == 0)  return 1
    mask = 4294967296 - 2^(32 - prefix)
    return bitand(qi, mask) == bitand(ni, mask)
}

NR == 1 {
    raw_header = $0
    for (i = 1; i <= NF; i++) {
        v = $i
        gsub(/^[ \t\r]+|[ \t\r]+$/, "", v)
        if (v == "CIDR" || v == "/16_CIDR" || v == "/24_CIDR") {
            cidr_col = i
            if (debug) print "[DEBUG] CIDR column: " i " (" v ")" > "/dev/stderr"
            break
        }
    }
    if (cidr_col == 0) {
        print "STATUS:ERROR:Could not locate CIDR column"
        exit 1
    }
    next
}

{
    cidr = $cidr_col
    gsub(/^[ \t]+|[ \t]+$/, "", cidr)
    if (cidr !~ /\//) next

    slash  = index(cidr, "/")
    net    = substr(cidr, 1, slash - 1)
    prefix = substr(cidr, slash + 1) + 0
    gsub(/ /, "", net)

    if (prefix < 0 || prefix > 32) next

    if (debug) print "[DEBUG] Line " NR ": testing " cidr > "/dev/stderr"

    if (in_cidr(query_int, net, prefix)) {
        if (debug) print "[DEBUG]   -> HIT /" prefix > "/dev/stderr"
        if (prefix > best_prefix) {
            best_prefix = prefix
            best_line   = $0
            best_cidr   = cidr
        }
    }
}

END {
    if (best_prefix >= 0) {
        print "STATUS:MATCH"
        print "CIDR:"   best_cidr
        print "PREFIX:" best_prefix
        print "HEADER:" raw_header
        print "ROW:"    best_line
    } else {
        print "STATUS:NOMATCH"
    }
}
AWKEOF

lookup() {
    local csv_file="$1" query_ip="$2" query_int="$3"

    [[ -f "$csv_file" ]] || die "Data file not found: $csv_file"
    dbg "Scanning $(basename "$csv_file") for $query_ip (int=$query_int)"

    local awk_out status cidr prefix raw_header raw_row

    # Strip UTF-8 BOM from line 1 before awk sees it — BSD awk (macOS) does not
    # support \xef hex escapes in regex, so we pre-clean with sed in bash.
    awk_out=$(awk -v query_int="$query_int" \
                  -v debug="$( $DEBUG && echo 1 || echo 0 )" \
                  "$AWK_PROGRAM" <(LC_ALL=C sed $'1s/^\xef\xbb\xbf//' "$csv_file"))

    while IFS= read -r line; do
        case "$line" in
            STATUS:MATCH)    status="MATCH"   ;;
            STATUS:NOMATCH)  status="NOMATCH" ;;
            STATUS:ERROR:*)  die "${line#STATUS:ERROR:}" ;;
            CIDR:*)    cidr="${line#CIDR:}"         ;;
            PREFIX:*)  prefix="${line#PREFIX:}"     ;;
            HEADER:*)  raw_header="${line#HEADER:}" ;;
            ROW:*)     raw_row="${line#ROW:}"       ;;
        esac
    done <<< "$awk_out"

    echo ""

    if [[ "${status:-NOMATCH}" == "NOMATCH" ]]; then
        echo -e "${YELLOW}No match found for ${BOLD}${query_ip}${RESET}${YELLOW} in $(basename "$csv_file").${RESET}"
        echo ""
        return 0
    fi

    raw_header="$(printf '%s' "$raw_header" | tr -d '\r')"
    raw_row="$(   printf '%s' "$raw_row"    | tr -d '\r')"

    parse_csv_line "$raw_header"; local -a HEADERS=("${CSV_FIELDS[@]}")
    parse_csv_line "$raw_row";    local -a VALS=("${CSV_FIELDS[@]}")

    echo -e "${BOLD}${GREEN}Match found for ${BLUE}${query_ip}${GREEN} in $(basename "$csv_file")${RESET}"
    echo -e "${DIM}--------------------------------------------------------------${RESET}"

    local i
    for i in "${!HEADERS[@]}"; do
        print_field "${HEADERS[$i]}" "${VALS[$i]:-}"
    done

    echo -e "${DIM}--------------------------------------------------------------${RESET}"
    echo -e "  ${DIM}Best match :${RESET} ${BOLD}${cidr}${RESET}  ${DIM}(prefix /${prefix})${RESET}"
    echo ""
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
[[ $# -gt 0 ]] || { usage; exit 0; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        -l)
            shift
            [[ $# -gt 0 ]] || die "-l requires an IP address argument"
            LOOKUP_IP="$1" ;;
        -C16) DATASET="16" ;;
        -C24) DATASET="24" ;;
        -a)   ALL_FIELDS=true ;;
        -d)   DEBUG=true   ;;
        *)    die "Unknown option: '$1'  (use -h for help)" ;;
    esac
    shift
done

[[ -n "$LOOKUP_IP" ]] || die "No IP address specified. Use -l <IP>  (or -h for help)."
validate_ip "$LOOKUP_IP" || die "Invalid IPv4 address: '$LOOKUP_IP'"

case "$DATASET" in
    16)  DATA_FILE="$SCRIPT_DIR/cidr_16.csv"         ;;
    24)  DATA_FILE="$SCRIPT_DIR/cidr_24.csv"          ;;
    all) DATA_FILE="$SCRIPT_DIR/all_IP_networks.csv"  ;;
esac

dbg "Dataset   : $DATASET"
dbg "Data file : $DATA_FILE"
dbg "Lookup IP : $LOOKUP_IP"

ip_to_int "$LOOKUP_IP"
dbg "IP integer: $IP_INT"

lookup "$DATA_FILE" "$LOOKUP_IP" "$IP_INT"