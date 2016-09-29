#!/bin/bash
################################################################################
################################################################################
# DESCRIPTION: this script deduplicates a fasta file
# DEPENDENCIES: vsearch
# CONFIGURATION VARIABLES: ${vsearch_version}
# EXIT CODES:
# 0    no errors
# 1    input/output error
# 5    config file not found or readable
# 6    config file format error
################################################################################
################################################################################

show_usage(){
  cat <<EOF
  Usage: ${0##*/} [-h] [-c|--config FILE] [-i|--input FILE] [-l|--log FILE] \
[-o|--output FILE]

  -c|--config        configuration file
  -h|--help          display this help and exit
  -i|--input         input fasta file
  -l|--log           log file
  -o|--output        output fasta file
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


function deduplicate_fasta() {

  local INPUT="${1}"
  local OUTPUT="${2}"
  local LOG="${3}"

  if [[ ! -r "${INPUT}" ]]; then
    echo "${INPUT} doesn't exist or is not readable"
  fi

  ##### load vsearch module ##### 
  source /bioinf/software/etc/profile.modules
  module load vsearch/"${vsearch_version}"
  ##### load vsearch module #####

  vsearch --derep_prefix "${INPUT}" --fastaout --notrunclables --threads \
  "${NSLOTS}" --output "${OUTPUT}" --log "${LOG}"

  EXIT_CODE="$?"
}

main(){

  if [[ -n "${CONFIG_FILE}" ]]; then
    read_config "${CONFIG_FILE}"
  fi

  deduplicate_fasta "${INPUT}" "${OUTPUT}" "${LOG}"

  if [[ "${EXIT_CODE}" -eq "0" ]]; then
    echo "Deduplicate successful"
  else
    echo "Decuplicate failed"
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
##############
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
##############
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
##############
    -l|--log)  # Takes an option argument, ensuring it has been specified.
    if [[ -n "${2}" ]]; then
      LOG="${2}"
      shift
    else
      printf 'ERROR: "--log" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;
    --log=?*)
    LOG=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;
    --log=)         # Handle the case of an empty --file=
    printf 'ERROR: "--log" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
##############
    -o|--output) # Takes an option argument, ensuring it has been
                 # specified.
    if [[ -n "${2}" ]]; then
      OUTPUT="${2}"
      shift
    else
      printf 'ERROR: "--output" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;
    --output=?*)
    OUTPUT=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;
    --output=)     # Handle the case of an empty --file=
    printf 'ERROR: "--output" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
##############
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

