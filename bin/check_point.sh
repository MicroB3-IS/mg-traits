#!/bin/bash
################################################################################
################################################################################
# DESCRIPTION: this script checks the FragGeneScan, SortMeRNA and sina results
# It also holds the script before proceeding with the functional annotation
# DEPENDENCIES:
# CONFIGURATION VARIABLES:
# EXIT CODES:
# 0    no error
# 1    input/output error
# 2    FragGeneScan output error
# 3    SortMeRNA or sina error, or no RNA seq found
# 5    config file not found or readable
# 6    config file format error
################################################################################
################################################################################

show_usage(){
  cat <<EOF
  Usage: ${0##*/} [-h] [-c|--config FILE] [-i|--inputdir FILE] \
[-p| prfix1 STRING] [-q| prfix2 STRING]

  -c|--config        configuration file
  -h|--help          display this help and exit
  -i|--inputdir      input fasta file
  -p|--prefix1       prefix for cheking fgs
  -q|--prefix2       prefix for cheking sina
EOF
}

read_config(){
  CONFIG_FILE="${1}"

  if [[ ! -r "${CONFIG_FILE}" ]]; then
    echo "${CONFIG_FILE} doesn't exist or is not readable"
    exit 5
  fi

  CONFIG_SYNTAX="^\s*#|^\s*$|^[0-9a-zA-Z_]+=\"[^\"]*$|^[0-9a-zA-Z_]+\=\"[^\"]\
*\"$|[^\"]*\"$"

  if egrep -q -v "${CONFIG_SYNTAX}" "${CONFIG_FILE}"; then
    echo "Error parsing config file ${CONFIG_FILE}." >&2
    echo "The following lines in the configfile do not fit the syntax:" >&2
    egrep -vn "${CONFIG_SYNTAX}" "$CONFIG_FILE"
    exit 6
  fi

  source "${CONFIG_FILE}"
}


function check_results_fgs() {

  local THIS_JOB_TMP_DIR="${1}"
  local PREFIX="${2}"
  local PREFIX="${3}"

  FAA_RESULTS=$( find "${THIS_JOB_TMP_DIR}" -name "${PREFIX1}*.faa" | wc -l )
  FFN_RESULTS=$( find "${THIS_JOB_TMP_DIR}" -name "${PREFIX1}*.ffn" | wc -l )
  SUBJOBS=$( find "${THIS_JOB_TMP_DIR}" -name "${PREFIX1}*.fasta" | wc -l)

  NUM_RNA=$( cat "${THIS_JOB_TMP_DIR}/${PREFIX2}"*.classify.fasta \
  | grep -c '>' )
  SLV_CLASSIFY_RESULTS=$( find "${THIS_JOB_TMP_DIR}" -name "06-part-1.fasta" \
  | wc -l)

  if [[ "${FAA_RESULTS}" -ne "${SUBJOBS}" ]] || \
     [[ "${FFN_RESULTS}" -ne "${SUBJOBS}" ]]; then
    EXIT_CODE=2
  elif [[ "${NUM_RNA}" -eq "0" ]] || \
       [[ "${SLV_CLASSIFY_RESULTS}" -eq "0" ]]; then
    EXIT_CODE=3
  else
    EXIT_CODE=0
  fi
}


main(){

  if [[ -n "${CONFIG_FILE}" ]]; then
    read_config "${CONFIG_FILE}"
  fi

  check_results_fgs "${INPUTDIR}" "${PREFIX1}" "${PREFIX2}"

  if [[ "${EXIT_CODE}" -eq "0" ]]; then
    echo "FGS successful"
  else
    echo "FGS failed"
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
#############
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
#############
    -i|--inputdir) # Takes an option argument, ensuring it has been
                # specified.
    if [[ -n "${2}" ]]; then
      INPUTDIR="${2}"
      shift
    else
      printf 'ERROR: "--inputdir" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;
    --inputdir=?*)
    INPUTDIR=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;
    --inputdir=)     # Handle the case of an empty --file=
    printf 'ERROR: "--inputdir" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
#############
    -p|--prefix1) # Takes an option argument, ensuring it has been
                 # specified.
    if [[ -n "${2}" ]]; then
      PREFIX1="${2}"
      shift
    else
      printf 'ERROR: "--prefix1" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;
    --prefix1=?*)
    PREFIX1=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;
    --prefix1=)     # Handle the case of an empty --file=
    printf 'ERROR: "--prefix1" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
#############
   -q|--prefix2) # Takes an option argument, ensuring it has been
                 # specified.
    if [[ -n "${2}" ]]; then
      PREFIX2="${2}"
      shift
    else
      printf 'ERROR: "--prefix2" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;
    --prefix2=?*)
    PREFIX2=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;
    --prefix2=)     # Handle the case of an empty --file=
    printf 'ERROR: "--prefix2" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
#############
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

