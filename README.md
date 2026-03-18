===============================================================================
 iplookup.sh -- IP Address Lookup Tool
 Version: 1.1
===============================================================================

DESCRIPTION
-----------
iplookup.sh performs a longest-prefix-match lookup against one of three CSV
network datasets and prints all matching fields for the best-matching network.
It is designed for network engineers and sysadmins who need to quickly identify
which network block an IP address belongs to, along with associated metadata
such as site name, region, VLAN, and contact info.


REQUIREMENTS
------------
  - bash 3.2 or later (macOS default or Linux)
  - Any POSIX awk: macOS awk, gawk, mawk, or nawk
  - No external dependencies beyond standard Unix tools

  macOS:  No additional installs needed.
  Linux:  No additional installs needed (bash + awk are pre-installed).


DATASETS
--------
Place the following CSV files in the SAME directory as iplookup.sh:

  all_IP_networks.csv   Full network dataset (default)
  cidr_16.csv           /16 summarized network dataset (selected with -C16)
  cidr_24.csv           /24 summarized network dataset (selected with -C24)

Each CSV file must have a header row containing one of the following column
names to identify the CIDR field:

  CIDR  |  /16_CIDR  |  /24_CIDR

UTF-8 BOM encoding is handled automatically.


INSTALLATION
------------
  1. Copy iplookup.sh and your CSV data files to the same directory.
  2. Make the script executable:

       chmod +x iplookup.sh

  3. Run it:

       ./iplookup.sh -l 10.0.0.5


USAGE
-----
  ./iplookup.sh -l <ip> [OPTIONS]


OPTIONS
-------
  -l <ip>   IPv4 address to look up (required)

  -C16      Use the /16 CIDR dataset (cidr_16.csv)
  -C24      Use the /24 CIDR dataset (cidr_24.csv)
            If neither -C16 nor -C24 is given, uses all_IP_networks.csv

  -a        Show ALL fields, including verbose fields that are hidden by
            default: NAUTOBOT_PHONE, NAUTOBOT_ADDRESS, SITE_CODES

  -d        Enable debug output. Shows CIDR column detection, per-row
            match testing, and hit results written to stderr.

  -h        Show help and exit.


EXAMPLES
--------
  # Basic lookup using the default dataset
  ./iplookup.sh -l 10.0.0.5

  # Lookup using the /16 CIDR dataset
  ./iplookup.sh -l 10.0.0.5 -C16

  # Lookup using the /24 CIDR dataset
  ./iplookup.sh -l 10.0.0.5 -C24

  # Lookup with all fields shown (including phone, address, site codes)
  ./iplookup.sh -l 172.16.10.0 -C16 -a

  # Lookup with debug output enabled
  ./iplookup.sh -l 192.168.1.50 -d

  # Combine dataset selection, all fields, and debug
  ./iplookup.sh -l 10.10.5.1 -C24 -a -d


OUTPUT
------
When a match is found, output looks like:

  Match found for 10.0.0.5 in all_IP_networks.csv
  --------------------------------------------------------------
  CIDR:                            10.0.0.0/24
  SITE_NAME:                       Main Campus
  REGION:                          US-EAST
  VLAN:                            100
  DESCRIPTION:                     Server LAN
  --------------------------------------------------------------
  Best match : 10.0.0.0/24 (prefix /24)

When no match is found:

  No match found for 10.0.0.5 in all_IP_networks.csv


HOW IT WORKS
------------
1. The script reads the target CSV file using an embedded POSIX awk program.

2. The awk program scans the header row to locate the CIDR column by name
   (CIDR, /16_CIDR, or /24_CIDR).

3. For each data row, it parses the CIDR field, converts the network address
   to a 32-bit integer, applies a bitmask for the prefix length, and tests
   whether the query IP falls within that network.

4. The longest prefix (most specific match) wins. For example, if both
   10.0.0.0/8 and 10.0.0.0/24 match, the /24 result is returned.

5. The matched row and header are passed back to bash, which parses them
   as CSV (handling quoted fields and embedded commas) and prints each
   field with colour formatting.

   Colour output is automatic when writing to a terminal and is suppressed
   when output is redirected to a file or pipe.


MATCH LOGIC
-----------
Longest-prefix-match means the MOST SPECIFIC network wins:

  Query IP: 10.0.0.5

  Candidate networks:
    10.0.0.0/8    -> matches (broad)
    10.0.0.0/16   -> matches (more specific)
    10.0.0.0/24   -> matches (most specific) <-- WINNER

  Result returned: 10.0.0.0/24


HIDDEN FIELDS
-------------
By default, the following fields are suppressed to keep output clean:

  NAUTOBOT_PHONE
  NAUTOBOT_ADDRESS
  SITE_CODES

Use -a to display them, or -d (debug mode) to display all fields including
empty ones.


ENVIRONMENT
-----------
No environment variables are required. The script auto-detects its own
directory using BASH_SOURCE[0] and looks for CSV files there.


EXIT CODES
----------
  0   Success (match found or no match -- both are normal exits)
  1   Error (data file not found, CIDR column missing, etc.)
  2   Invalid argument or missing required option


TROUBLESHOOTING
---------------
  Problem: "Data file not found"
  Fix:     Make sure your CSV file is in the SAME directory as iplookup.sh.
           Check the filename matches exactly (case-sensitive on Linux).

  Problem: "Could not locate CIDR column"
  Fix:     Check your CSV header row contains exactly one of:
             CIDR    /16_CIDR    /24_CIDR
           Run with -d to see which column was detected.

  Problem: "No match found" for an IP you expect to match
  Fix:     Run with -d to trace which networks are being tested.
           Confirm the IP is within a listed network range.
           Try a different dataset (-C16 or -C24).

  Problem: No colour in output
  Fix:     Colour is only shown when writing directly to a terminal.
           If you are piping output, colour codes are suppressed by design.
           Use: ./iplookup.sh -l 10.0.0.5 | cat   (no colour -- expected)


NOTES
-----
  * The script is compatible with Bash 3.2+ (macOS default) and does not
    require any Homebrew or third-party installs.
  * The embedded awk program uses only POSIX awk features and works with
    macOS awk, gawk, mawk, and nawk.
  * UTF-8 BOM characters at the start of CSV files are stripped automatically
    before awk processes the file.
  * The CSV parser handles RFC 4180 quoting: quoted fields, embedded commas,
    and escaped double-quotes are all handled correctly.


===============================================================================
