#!/bin/bash
################################################################################
################################################################################
# DESCRIPTION: this script parses the taxonomic annotation and checks if there
# are enough orders found
# DEPENDENCIES: awk
# CONFIGURATION VARIABLES: ${SLV_FILE}
# EXIT CODES:
# 0    no errors
# 1    input/output error
# 2    error in parsing files
# 3    not enough orders found
# 5    config file not found or readable
# 6    config file format error

################################################################################
################################################################################
show_usage(){
  cat <<EOF
  Usage: ${0##*/} [-h] [-c|--config FILE] [-i|input FILE] \
[-o|--slv_order FILE] [-r|--slv_raw FILE]

  -c|--config        configuration file
  -i|--input         input classified sina fasta file
  -h|--help          display this help and exit
  -o|--slv_order     output svl taxa oder
  -r|--slv_raw       output svl taxa raw
EOF
}

read_config(){
  CONFIG_FILE="${1}"

  if [[ ! -r "${CONFIG_FILE}" ]]; then
    echo "${CONFIG_FILE} doesn't exist or is not readable"
    exit 1
  fi

  CONFIG_SYNTAX="^\s*#|^\s*$|^[0-9a-zA-Z_]+=\"[^\"]*$|^[0-9a-zA-Z_]+\=\"[^\"]\
*\"$|[^\"]*\"$"

  if egrep -q -v "${CONFIG_SYNTAX}" "${CONFIG_FILE}"; then
    echo "Error parsing config file ${CONFIG_FILE}." >&2
    echo "The following lines in the configfile do not fit the syntax:" >&2
    egrep -vn "${CONFIG_SYNTAX}" "$CONFIG_FILE"
    exit 5
  fi

  source "${CONFIG_FILE}"
}


function taxa_parser() {

  local GENERNA="${1}"
  local SLV_TAX_RAW="${2}"
  local SLV_TAX_ORDER="${3}"

  local SLV_TMP_ORDER=$(dirname "${GENERNA}" )/09-slv-tmp-order
  local SLV_TMP_UNIQUE=$(dirname "${GENERNA}" )/09-slv-tmp-unique

  EXIT_CODE="0"

  # raw taxonomic classification
  grep lca_tax_slv "${GENERNA}" | cut -d '=' -f 2 | sort | \
  uniq -c | awk '{print substr($0, index($0, $2))"=>"$1}' | tr '\n' ',' | \
  sed -e 's/ /_/g' -e 's/^/\"/' -e 's/,$/\"/' > "${SLV_TAX_RAW}"

  if [[ "$?" -ne "0" ]]; then #CHANGE THIS FOR REAL DATA!!!!
    echo "Raw taxonomic classificaion parsing failed"
    EXIT_CODE=2
  fi

  # order taxonomic classification
  grep lca_tax_slv "${GENERNA}" | cut -d '=' -f 2 | \
  awk 'BEGIN{FS=";"}{if (NF > 4) {print $4}}' | sort | uniq -c | \
  awk '{print substr($0, index($0, $2))"=>"$1}' > "${SLV_TMP_ORDER}"


  if [[ "$?" -ne "0" ]]; then #CHANGE THIS FOR REAL DATA!!!!
    echo "Oder taxonomic classificaion parsing failed"
    EXIT_CODE=2
  fi

  # Check order classification number 
  NUM_ORDER=$(wc -l "${SLV_TMP_ORDER}" | cut -f 1 -d ' ')

  if [[ "${NUM_ORDER}" -lt "1" ]]; then #CHANGE THIS FOR REAL DATA!!!!
    echo "Taxonomic analysis error: Not enough ORDERS found"
    EXIT_CODE=3
  fi

  # taxonomic classification for rank order
  cut -f1 -d "=" "${SLV_TMP_ORDER}" | cat - "${SLV_FILE}" | sort | uniq -u | \
  awk '{print $0"=>0"}' > "${SLV_TMP_UNIQUE}"

  cat "${SLV_TMP_ORDER}" "${SLV_TMP_UNIQUE}" |  tr '\n' ',' | \
  sed -e 's/ /_/g' -e 's/^/\"/' -e 's/,$/\"/' > "${SLV_TAX_ORDER}"

  if [[ "$?" -ne "0" ]]; then
    echo "Error getting taxonomic classification for rank=order"
    EXIT_CODE=2
  fi

  rm "${SLV_TMP_ORDER}" ${SLV_TMP_UNIQUE}

}

main(){

  if [[ -n "${CONFIG_FILE}" ]]; then
    read_config "${CONFIG_FILE}"
  fi

  taxa_parser "${INPUT}" "${SLV_TAX_RAW}" "${SLV_TAX_ORDER}"

  if [[ "${EXIT_CODE}" -eq "0" ]]; then
    echo "Taxa parsing successful"
  else
    echo "Taxa parsing failed"
  fi
  exit "${EXIT_CODE}"
}


if  [[ "$#" -eq 0 ]]; then
    show_usage
fi

#######################################
# parse positional parameters
#######################################

while :; do
  case "${1}" in

    -h|-\?|--help) # Call a "show_help" function to display a synopsis, then
                   # exit.
    show_usage
    exit
    ;;
###########
   -c|--config) # Takes an option argument, ensuring it has been specified.
    if [ -n "${2}" ]; then
      CONFIG_FILE="${2}"
      shift
    else
      printf 'ERROR: "--config" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;

    --config=?*)
    CONFIG_FILE=${1#*=} # Delete everything up to "=" and assign the
                        # remainder.
    ;;

    --config=) # Handle the case of an empty --file=
    printf 'WARN: Using default environment.\n' >&2
    ;;
###########
    -i|--input) # Takes an option argument, ensuring it has been
                # specified.
    if [[ -n "${2}" ]]; then
      INPUT="${2}"
      shift
    else
      printf 'ERROR: "--input" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;

    --input=?*)
    INPUT=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;

    --input=)     # Handle the case of an empty --file=
    printf 'ERROR: "--input" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
###########
  -o|--slv_order) # Takes an option argument, ensuring it has been
                 # specified.
    if [[ -n "${2}" ]]; then
      SLV_TAX_ORDER="${2}"
      shift
    else
      printf 'ERROR: "--slv_order" requires a non-empty option argument.\n'>&2
      exit 1
    fi
    ;;

    --slv_order=?*)
    SLV_TAX_ORDER=${1#*=} # Delete everything up to "=" and assign the
                            # remainder.
    ;;

    --slv_order=)     # Handle the case of an empty --file=
    printf 'ERROR: "--slv_order" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
##########
    -r|--slv_raw) # Takes an option argument, ensuring it has been
                 # specified.
    if [[ -n "${2}" ]]; then
      SLV_TAX_RAW="${2}"
      shift
    else
      printf 'ERROR: "--slv_raw non-empty option argument.\n' >&2
      exit 1
    fi
    ;;

    --slv_raw=?*)
    SLV_TAX_RAW=${1#*=} # Delete everything up to "=" and assign the
                            # remainder.
    ;;

    --slv_raw=)     # Handle the case of an empty --file=
    printf 'ERROR: "--slv_raw" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
################
    --)              # End of all options.
    shift
    break
    ;;

    -?*)
    printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
    ;;

    *) # Default case: If no more options then break out of the loop.
    break
    esac

    shift
done

main "$@"








