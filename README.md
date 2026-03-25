===============================================================================
 iplookup.sh  --  IPAM + Application Subnet Lookup Tool
 Version: 2.5  |  CVS Health / Aetna Network Intelligence
===============================================================================

DESCRIPTION
-----------
iplookup.sh is a multi-mode IPAM and application lookup tool. It performs
longest-prefix-match IP lookups, hostname and domain searches, application
index queries, structured keyword searches, and location-based application
discovery across five complementary IPAM dataset files.

It is designed for network engineers, application owners, and security teams
who need to identify subnets, applications, hosting locations, OS profiles,
server counts, PCI scope, and risk classifications for any CVS Health / Aetna
IP address or network block.


REQUIREMENTS
------------
  - Bash 4.0 or later
  - Python 3.8 or later  (uses csv, sys, collections from stdlib only --
                           no pip installs required)
  - All five dataset files in the SAME directory as iplookup.sh
  - tree_diagram.py in the same directory  (required for -td flag only)

  macOS:   System Python 3 is sufficient.  No Homebrew required.
  Linux:   Python 3.8+ is pre-installed on most distributions.
  Windows: Use WSL (Windows Subsystem for Linux).


DATASET FILES
-------------
Place all files in the same directory as iplookup.sh:

  File                    Scope                            Rows    Cols  Version
  ----------------------  -------------------------------  ------  ----  -------
  all_IP_networks.csv     All prefixes /4-/32              315,181  50   v1.14
  cidr_16.csv             /16 supernets with rollups           482  67   v1.10
  cidr_24.csv             /24 blocks with full enrichment   26,453  65   v1.12
  app_subnet_index.csv    Application metadata per /24       1,998  23   --
  dataset_index.json      Machine-readable version manifest     --  --   --
  tree_diagram.py         CLI subnet tree renderer              --  --   --

cidr_24.csv carries 65 enrichment fields per /24, including:
  Network:     OWNER, ROUTING_DOMAIN, NET_TYPE, FACILITY_TYPE, BU, DIVISION
  Location:    LOCATION, CITIES, STATES, SITE_CODES, NAUTOBOT_ADDRESS
  Application: IPAM_APP_ID, APP_COUNT, PROD/DR/DEV_APP_COUNT, APP_ENV_TYPES,
               PCI_DESIGNATION, RISK_TIER, DNS_DOMAINS, COMP_SENSITIVE
  Server:      SERVER_COUNT, VIRTUAL_COUNT, PHYSICAL_COUNT, OPERATIONAL_COUNT,
               NON_OP_COUNT, RETIRED_COUNT, PROD/DR/DEV_SERVER_COUNT,
               OS_DOMINANT, OS_DIVERSITY, OS_SUMMARY, SERVER_OS_GROUP,
               DECOM_CANDIDATE
  Conflict:    CONTESTED, CONFLICT_STATUS, CONTESTED_BLOCK
  NAT/PAT:     NAT_TYPE, NAT_POOL, NAT_PUBLIC_IP, NAT_SERVICE_MAP

app_subnet_index.csv carries 23 application fields per /24:
  IPAM_APP_ID, APM_IDS, APP_ACRONYMS, APP_COUNT, PROD/DR/DEV_APP_COUNT,
  APP_ENV_TYPES, PCI_DESIGNATION, RISK_TIER, HERITAGE, DNS_DOMAINS,
  PRIMARY_SITE, COMP_SENSITIVE, APP_LOCATION_GROUP, OS_LOCATION_GROUP,
  DECOM_CANDIDATE, SERVER_COUNT, SOURCE_FILE, BUILT_AT


INSTALLATION
------------
  1. Copy iplookup.sh, tree_diagram.py, and all five dataset files to the
     same directory.

  2. Make the script executable:

       chmod +x iplookup.sh

  3. Verify dataset versions:

       ./iplookup.sh -V

  4. Run your first lookup:

       ./iplookup.sh -l 10.130.142.5


USAGE
-----
  iplookup.sh <FLAG> <VALUE> [OPTIONS]

All output is automatically paged via less when writing to a terminal.
Use --no-pager to disable paging (useful in scripts).


LOOKUP MODES
------------

  -l <IP>
      Longest-prefix-match lookup against all_IP_networks.csv.
      Returns all matching prefixes from most specific (/32) to most
      general (/16), with full enrichment fields.
      Combine with --nat to include NAT/PAT service mapping.
      Combine with --app to include the app_subnet_index row.

      iplookup.sh -l 172.16.1.5
      iplookup.sh -l 10.130.142.10 --app
      iplookup.sh -l 172.16.1.1 --nat --app

  --hostname <fqdn>
      Search Display_Name and Comments fields in all_IP_networks for any
      FQDN or partial hostname string.

      iplookup.sh --hostname pgc1heaadl10v.corp.cvscaremark.com

  -dom <domain>
      Find all /24 subnets associated with a DNS domain or partial domain
      string. Searches the DNS_DOMAINS field in cidr_24 and returns a
      summary of matching network types, facility types, and routing
      domains.

      iplookup.sh -dom caremarkrx.net
      iplookup.sh -dom aeth.aetna.com
      iplookup.sh -dom corp.cvscaremark.com -n 50

  -app <APPID>
      Look up an application by IPAM_APP_ID, APM ID, or application
      acronym. IPAM_APP_ID format: NET-<oct1>-<oct2>-<oct3>.

      iplookup.sh -app NET-10-130-142
      iplookup.sh -app APM0012589
      iplookup.sh -app Genetec
      iplookup.sh -app RxConnect

  -k <keyword>
      Free-text search across 16 fields in cidr_24 (Location, CITIES,
      STATES, SITE_CODES, DNS_DOMAINS, NET_TYPE, FACILITY_TYPE,
      FUNCTION_LOC_ROLE, ROUTING_DOMAIN, OWNER, DIVISION, BU,
      APP_ENV_TYPES, PCI_DESIGNATION, RISK_TIER, IPAM_APP_ID).

      iplookup.sh -k MinuteClinic
      iplookup.sh -k Woonsocket

  -k field=value
      Structured single-field search using a field alias.
      Multiple -k flags apply AND logic (all filters must match).

      iplookup.sh -k city=Dallas
      iplookup.sh -k city=Dallas -k "risk=High Risk"
      iplookup.sh -k facility=DataCenter -k env=PROD
      iplookup.sh -k pci="PCI Connected" -k bu=HCB

  -k list
      Show all 16 searchable field aliases with example values.

  -k field=list
      Enumerate all unique values for a specific field.
      Example: -k bu=list   -k risk=list   -k facility=list

  Field aliases:
      city        CITIES
      state       STATES
      site        SITE_CODES
      owner       OWNER
      bu          BU
      routing     ROUTING_DOMAIN
      nettype     NET_TYPE
      facility    FACILITY_TYPE
      function    FUNCTION_LOC_ROLE
      pci         PCI_DESIGNATION
      risk        RISK_TIER
      env         APP_ENV_TYPES
      dns         DNS_DOMAINS
      appid       IPAM_APP_ID
      division    DIVISION
      location    LOCATION

  -loc <location>
      Location-based application lookup. Searches two paths simultaneously:
        1. cidr_24 CITIES / STATES / SITE_CODES / LOCATION / NAUTOBOT_ADDRESS
           -> IPAM_APP_ID -> app_subnet_index
        2. app_subnet_index PRIMARY_SITE direct match
      Returns application names, counts, risk tiers, and PCI designations
      for all matching subnets.

      iplookup.sh -loc Woonsocket
      iplookup.sh -loc Scottsdale
      iplookup.sh -loc RI                  # state code (exact token)
      iplookup.sh -loc WON                 # site code
      iplookup.sh -loc "Middletown" -n 30

  -loc group=<name>
      Filter app_subnet_index by APP_LOCATION_GROUP. Valid group names:

        All            All 1,998 subnets
        On-Premises    846 subnets  (on-prem DC sites)
        Cloud          534 subnets  (Azure, GCP, AWS)
        Remote         151 subnets  (Offshore, Work-at-Home)
        Unclassified   464 subnets  (no PRIMARY_SITE recorded)
        CVS Heritage  1,319 subnets
        Aetna Heritage 1,155 subnets
        PCI            369 subnets
        High Risk      655 subnets

      Subnets can belong to multiple groups simultaneously. For example,
      a subnet can be  On-Premises | CVS Heritage | PCI | High Risk.

      iplookup.sh -loc group=Cloud
      iplookup.sh -loc group="CVS Heritage"
      iplookup.sh -loc group=PCI
      iplookup.sh -loc group="High Risk" -n 50

  -loc group=list
      Show all APP_LOCATION_GROUP and OS_LOCATION_GROUP values with
      subnet counts.

  -loc group=os-list
      Show OS_LOCATION_GROUP values with subnet counts only.

  -r <os_group>
      Refine -loc results by server OS type. Applied after the location
      or group filter.  -r performs a case-insensitive substring match
      against OS_LOCATION_GROUP in app_subnet_index.

      Valid OS groups and approximate subnet counts:
        Windows          1,031 subnets
        Linux            1,186 subnets
        ESX-VMware         150 subnets
        AIX                171 subnets
        Kubernetes         118 subnets
        Cloud               11 subnets
        Mainframe-zOS       28 subnets  (IBM Mainframe, IBM zOS Server)
        Mainframe-iSeries   14 subnets  (IBM iSeries LPAR, OS/400)
        Mainframe           41 subnets  (rollup: zOS + iSeries combined)
        Solaris             16 subnets
        UNIX                21 subnets
        Hyper-V             15 subnets
        Appliance          375 subnets
        IBM-HMC              7 subnets
        Unclassified       118 subnets
        Other               34 subnets

      iplookup.sh -loc Woonsocket -r Linux
      iplookup.sh -loc Scottsdale -r Kubernetes
      iplookup.sh -loc group=PCI -r Windows
      iplookup.sh -loc group="High Risk" -r "Mainframe-zOS"
      iplookup.sh -loc group="Aetna Heritage" -r AIX
      iplookup.sh -loc group=Cloud -r Kubernetes

  -td <CIDR>
      Render a colour-coded CLI subnet tree for any prefix from /16 to /26.
      Requires tree_diagram.py in the same directory.

      iplookup.sh -td 10.90.0.0/16
      iplookup.sh -td 172.16.0.0/16 --max-24s 20
      iplookup.sh -td 172.16.1.0/24 --nat
      iplookup.sh -td 10.130.0.0/16 --no-pager > tree.txt


TAG LOOKUP  (-lt)
-----------------
  -lt                  List every tag category with its unique-value count.
                       Gives you the command to drill into each one.

  -lt -dom             All DNS_DOMAINS values, sorted by /24 count (4,256 values).
  -lt --city           All CITIES values, sorted by /24 count (3,638 values).
  -lt --state          All STATES codes, alphabetical (52 values).
  -lt -loc             All PRIMARY_SITE location names, sorted by subnet count.
  -lt -loc group       Both APP_LOCATION_GROUP and OS_LOCATION_GROUP values
                       with subnet counts -- the reference list to use before
                       running  -loc group=<n>  or  -r <group>.
  -lt -loc osgroup     OS_LOCATION_GROUP values only.

  -lt -k <alias>       All values for any -k field alias.  The most useful:

    -lt -k bu          38 BU values
    -lt -k owner        6 OWNER values
    -lt -k nettype     16 NET_TYPE values  (includes Cloud-Kubernetes)
    -lt -k facility     9 FACILITY_TYPE values
    -lt -k routing      6 ROUTING_DOMAIN values
    -lt -k env         15 APP_ENV_TYPES values
    -lt -k pci          5 PCI_DESIGNATION values
    -lt -k risk         3 RISK_TIER values
    -lt -k os          12 OS_DOMINANT values
    -lt -k site     9,527 SITE_CODES  (sorted by /24 count)
    -lt -k division     DIVISION values

  Notes:
  - -lt -dom and -lt -k site produce thousands of lines.  Output is
    automatically paged via less -- quit early with  q  without error.
  - -lt -k <alias> does NOT trigger a keyword search; it only enumerates
    the field values.  Standalone  -k  still works as normal.

FILTER SHORTCUTS
----------------
  --city <name>      Filter /24 blocks by CITIES  (partial match)
  --state <abbr>     Filter /24 blocks by STATES  (TX, CA, RI ...)
  --dns <domain>     Filter /24 blocks by DNS_DOMAINS (token match)
  --pci              Show all PCI-designated /24 blocks
  --prod             Show /24 blocks containing at least one PROD app
  --risk <tier>      Filter by RISK_TIER: High | Medium | Low
  --high-risk        Shortcut for --risk High

  iplookup.sh --city Dallas -n 30
  iplookup.sh --state RI
  iplookup.sh --dns aeth.aetna.com
  iplookup.sh --pci
  iplookup.sh --risk High
  iplookup.sh --high-risk -n 50


DISPLAY OPTIONS
---------------
  -V                Show current version of all five dataset files.
  -n <num>          Maximum results to show (default: 20).
                    Can appear anywhere on the command line.
  --nat             Include NAT/PAT fields (NAT_TYPE, NAT_POOL,
                    NAT_PUBLIC_IP, NAT_SERVICE_MAP) in -l output.
                    Also expands /32 device rows in -td output.
  --app             Include full app_subnet_index row in -l output.
  --max-24s <n>     Maximum /24 blocks to show in -td (default: 12).
  --no-colour       Disable ANSI colour codes. Use when piping output
                    to a file or non-terminal.
  --no-pager        Disable automatic paging via less. Use in scripts
                    or when redirecting output.
  --min-version X.Y Abort with exit code 1 if all_IP_networks.csv
                    version is below the specified minimum. Use in
                    automation scripts to enforce dataset currency.

  iplookup.sh -l 10.0.0.5 --min-version 1.14
  iplookup.sh -td 172.16.0.0/16 --nat --no-colour > tree.txt


TREE DIAGRAM  (-td)
-------------------
Renders a colour-coded hierarchical CLI tree for any CIDR. Input can be
any prefix from /16 down to /26 -- depth is auto-detected.

  Input CIDR    Levels rendered
  ----------    -------------------------------------------------------
  /16           /16 root (owner, type, location, app counts)
                  -> intermediate /17-/23 blocks
                  -> /24 children (app count, PCI, risk, capped by --max-24s)
                  -> /26 retail stores
                  -> /32 device count (or full rows with --nat)
  /24           /24 root with full fields
                  -> /26 retail stores + sub-allocations
                  -> /32 device count
  /26           /26 store detail -> all /32 device rows expanded

  Colour coding:
    Bold blue     /16 supernet root
    Yellow        /17-/23 intermediate blocks
    Green         /24 blocks
    Cyan          /26 retail store subnets
    Dim           /32 device rows (shown only with --nat)
    [PCI]         Red badge -- block carries PCI designation
    [HIGH RISK]   Amber badge -- block carries High Risk tier
    [MULTI-FN]    Magenta badge -- multi-function store (Rx + MC/Optical)
    [CLOSED]      Red badge -- ROUTING_DOMAIN=Inactive (store closed)

  iplookup.sh -td 10.90.0.0/16
  iplookup.sh -td 172.16.0.0/16 --max-24s 20
  iplookup.sh -td 172.16.1.0/24 --nat
  iplookup.sh -td 172.16.4.0/24 --nat --no-colour > store_tree.txt


EXAMPLES BY TASK
----------------

  -- IP and network identification --
  iplookup.sh -l 10.130.142.10
  iplookup.sh -l 172.16.1.1 --nat --app
  iplookup.sh -l 10.217.0.5 --min-version 1.14

  -- Find a server by hostname --
  iplookup.sh --hostname pgc1heaadl10v.corp.cvscaremark.com
  iplookup.sh --hostname rxcprd

  -- Find subnets by DNS domain --
  iplookup.sh -dom caremarkrx.net
  iplookup.sh -dom aeth.aetna.com -n 50
  iplookup.sh -dom activehealth.loc

  -- Application lookups --
  iplookup.sh -app NET-10-130-142
  iplookup.sh -app APM0012589
  iplookup.sh -app Genetec
  iplookup.sh -app RxConnect

  -- Find all apps at a data centre --
  iplookup.sh -loc Woonsocket
  iplookup.sh -loc Scottsdale -n 50
  iplookup.sh -loc "Middletown" -n 100
  iplookup.sh -loc WON                   # by site code
  iplookup.sh -loc RI                    # by state

  -- Find apps at a DC by OS type --
  iplookup.sh -loc Woonsocket -r Linux
  iplookup.sh -loc Scottsdale -r Kubernetes
  iplookup.sh -loc Woonsocket -r AIX
  iplookup.sh -loc Windsor -r "Mainframe-zOS"
  iplookup.sh -loc Windsor -r Mainframe    # both zOS and iSeries

  -- Cloud and on-prem app groups --
  iplookup.sh -loc group=Cloud
  iplookup.sh -loc group="CVS Heritage" -n 50
  iplookup.sh -loc group="Aetna Heritage" -r AIX
  iplookup.sh -loc group=Cloud -r Kubernetes
  iplookup.sh -loc group=list              # show all groups

  -- PCI and risk scoping --
  iplookup.sh --pci
  iplookup.sh -loc group=PCI
  iplookup.sh -loc group=PCI -r Windows
  iplookup.sh -loc group="High Risk" -r "Mainframe-zOS"
  iplookup.sh --risk High -n 50

  -- Keyword and structured search --
  iplookup.sh -k MinuteClinic
  iplookup.sh -k city=Dallas
  iplookup.sh -k city=Dallas -k "risk=High Risk"
  iplookup.sh -k facility=DataCenter -k env=PROD
  iplookup.sh -k nettype=Cloud-Kubernetes
  iplookup.sh -k list                      # show all searchable fields
  iplookup.sh -k bu=list                   # list all BU values

  -- Tag discovery (-lt) --
  iplookup.sh -lt                          # master tag index
  iplookup.sh -lt -dom                     # all DNS domains
  iplookup.sh -lt --city                   # all cities
  iplookup.sh -lt --state                  # all state codes
  iplookup.sh -lt -loc                     # all DC / site locations
  iplookup.sh -lt -loc group               # all APP + OS group values
  iplookup.sh -lt -k bu                    # all BU values
  iplookup.sh -lt -k nettype               # all NET_TYPE values
  iplookup.sh -lt -k pci                   # all PCI designation values
  iplookup.sh -lt -k site                  # all 9,527 site codes
  iplookup.sh -lt -k routing               # all routing domain values

  -- Decommission and retirement analysis --
  iplookup.sh -k DECOM_CANDIDATE           # find decom-candidate subnets

  -- Subnet tree diagrams --
  iplookup.sh -td 10.90.0.0/16
  iplookup.sh -td 172.16.0.0/16 --max-24s 20
  iplookup.sh -td 172.16.1.0/24 --nat
  iplookup.sh -td 10.130.0.0/16 --no-pager > tree.txt

  -- Dataset version checking --
  iplookup.sh -V
  iplookup.sh -l 10.0.0.5 --min-version 1.14


APP_LOCATION_GROUP REFERENCE
-----------------------------
Subnets in app_subnet_index are tagged with pipe-delimited group memberships.
A subnet can belong to multiple groups simultaneously.

  Group           Subnets  Description
  --------------  -------  --------------------------------------------------
  All               1,998  Every subnet in the app index
  On-Premises         846  Hosted at CVS/Aetna on-premises data centres
  Cloud               534  Azure, GCP, or AWS hosted
  Remote              151  Offshore/Offsite or Work-at-Home
  Unclassified        464  No PRIMARY_SITE recorded in ADL source
  CVS Heritage      1,319  Apps with CVS or Mixed enterprise heritage
  Aetna Heritage    1,155  Apps with AETNA or Mixed enterprise heritage
  PCI                 369  Any PCI designation (PCI, Connected, Security Tool)
  High Risk           655  RISK_TIER = High Risk

Use:  iplookup.sh -loc group=<name>
      iplookup.sh -loc group=list


OS_LOCATION_GROUP REFERENCE
----------------------------
App subnets are also tagged by the OS types of servers deployed on them,
derived from the Server Report. Used with the -r refine flag.

  Group              Subnets  Description
  -----------------  -------  -----------------------------------------------
  Windows              1,031  Windows Server (any version)
  Linux                1,186  Red Hat / RHEL / CentOS / Ubuntu / SuSE
  ESX-VMware             150  VMware ESX / ESXi hypervisors
  AIX                    171  IBM AIX (AIX 7.x)
  Kubernetes             118  Kubernetes Cluster nodes
  Cloud                   11  Cloud WebServer class
  Mainframe-zOS           28  IBM Mainframe + IBM zOS Server (z/OS)
  Mainframe-iSeries       14  IBM iSeries LPAR (OS/400)
  Mainframe               41  Rollup: zOS + iSeries combined
  Solaris                 16  Oracle / Sun Solaris
  UNIX                    21  Generic UNIX Server class
  Hyper-V                 15  Microsoft Hyper-V Server
  Appliance              375  Network/Security Appliance, DataPower, Web GW
  IBM-HMC                  7  IBM Hardware Management Console
  Unclassified           118  Class=Server with no OS data
  Other                   34  ServiceNow MID, OpenVMS, FreeBSD, etc.

Use:  iplookup.sh -loc <location> -r <group>
      iplookup.sh -loc group=<name> -r <group>
      iplookup.sh -loc group=os-list


NET_TYPE VALUES
---------------
  DataCenter            On-premises DC subnet
  Cloud                 Cloud-hosted subnet (Azure / GCP / AWS)
  Cloud-Kubernetes      Kubernetes cluster subnet (cloud-hosted)
  Corporate             Corporate office / support subnet
  Retail-Store          CVS Rx pharmacy retail store
  Retail-MinuteClinic   MinuteClinic subnet
  Retail-Optical        Retail Optical subnet
  Distribution          Distribution centre subnet
  VPN                   VPN / remote access subnet
  Omnicare              Omnicare subsidiary subnet
  Unallocated           Reserved / not yet assigned

  Note: NET_TYPE is pipe-delimited when a /24 contains multiple types.
  Subnets tagged Cloud-Reclassified in Source were reclassified from
  DataCenter to Cloud based on ADL application hosting data.
  Subnets tagged K8s-Classified were reclassified based on Server Report
  Kubernetes Cluster class data.


HOW IT WORKS
------------
1. Bash parses all command-line arguments in two passes. Pass 1 collects
   modifier flags (-n, --nat, --no-pager, -k filters). Pass 2 dispatches
   to the appropriate lookup function.  -loc is dispatched after both
   passes so that -r is always collected before the lookup runs.

2. Each lookup mode is implemented as a bash function that embeds a Python
   3 heredoc. Python reads the relevant CSV files using the csv module
   (stdlib only -- no external dependencies).

3. IP lookup (-l) uses longest-prefix-match: the most specific matching
   prefix (/32 beats /24 beats /16) is returned first.

4. All output is piped through  less -RFXS  when writing to a terminal,
   providing automatic pagination with colour preservation. Pass --no-pager
   to suppress this.

5. The -loc lookup combines two search paths and deduplicates results:
   (a) cidr_24 location fields -> IPAM_APP_ID -> app_subnet_index
   (b) app_subnet_index PRIMARY_SITE direct match
   The -r flag then filters the combined result by OS_LOCATION_GROUP.


DATASET CHANGE LOG
------------------
  all_IP_networks.csv  v1.14   +6 server-derived cols (SERVER_COUNT,
                               VIRTUAL_COUNT, PHYSICAL_COUNT,
                               PROD_SERVER_COUNT, OS_DOMINANT,
                               DECOM_CANDIDATE)
  cidr_24.csv          v1.12   +14 server-derived cols including OS_SUMMARY,
                               SERVER_OS_GROUP; 354 K8s subnets tagged
                               Cloud-Kubernetes; 67 PCI gaps filled;
                               148 DECOM_CANDIDATE flags set
  cidr_16.csv          v1.10   +8 server rollup cols; 189 rows updated
  app_subnet_index.csv  --     +4 cols: APP_LOCATION_GROUP, OS_LOCATION_GROUP,
                               DECOM_CANDIDATE, SERVER_COUNT
  iplookup.sh           v2.5   -lt tag lookup (16 subcommands: -dom, --city,
                               --state, -loc, -loc group, -loc osgroup,
                               -k <alias>). -r OS refine flag for -loc.
                               BrokenPipeError fix for large -lt outputs.
                               -V show_version fix for app_subnet_index.


TROUBLESHOOTING
---------------
  Problem: "Data file not found: ..."
  Fix:     All five CSV files and tree_diagram.py must be in the SAME
           directory as iplookup.sh. Run  iplookup.sh -V  to verify.

  Problem: Output is empty or truncated
  Fix:     Use --no-pager if piping to another command, or redirect to
           a file.  less may swallow output in non-interactive shells.

  Problem: "No results" for a keyword search
  Fix:     The keyword search covers 16 specific cidr_24 fields, not
           all_IP_networks. Try a more general term, or use -k list to
           see which fields are searched.

  Problem: -r returns fewer results than expected
  Fix:     OS_LOCATION_GROUP is only populated for subnets that appear
           in the Server Report (2,525 of 26,453 /24s). Subnets not in
           the server report will not match any -r filter.

  Problem: BrokenPipeError traceback when quitting -lt early
  Fix:     This was fixed in v2.5. If you see it on an older copy of
           iplookup.sh, update to the current version.  -lt -dom and
           -lt -k site produce thousands of lines; quitting less early
           with  q  is normal and will not produce an error.

  Problem: No colour output
  Fix:     Colour is only enabled when writing directly to a terminal.
           Pipe or redirect output to suppress it automatically, or use
           --no-colour explicitly.

  Problem: Python not found
  Fix:     Install Python 3.8+.  The script calls  python3  -- confirm
           it is on your PATH:   which python3


EXIT CODES
----------
  0   Success (result found or not found -- both are normal)
  1   Error   (missing file, --min-version failed, Python error)
  2   Invalid argument or missing required option


ENVIRONMENT
-----------
No environment variables required. The script locates dataset files
relative to its own directory using BASH_SOURCE[0].

Paging: output is piped to  less -RFXS  when stdout is a terminal.
Set  NO_PAGER=1  or use  --no-pager  to disable.


===============================================================================
