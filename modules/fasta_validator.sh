#!/bin/bash
################################################################################
################################################################################
# DESCRIPTION: this script chacks if the fasta file is valid
# DEPENDENCIES: FastaValidator
# CONFIGURATION VARIABLES: ${fasta_validator}
# EXIT CODES:
# 0    no errors
# 1    unknown error
# 2    input/output error
# 3    invalid character in sequence
# 5    config file not found or readable
# 6    config file format error
################################################################################
################################################################################

show_usage(){
    cat <<EOF
    Usage: ${0##*/} [-h] [-c|--config FILE] [-f|--fastafile FILE] \
[-t|--seqtype TYPE] ...

    -c|--config        configuration file
    -h|--help          display this help and exit
    -f|--fastafile     fasta file to validate
    -t|--seqtype       alphabet to be used (allowed values: all|dna|rna|protein)
EOF
}

read_config(){
  CONFIG_FILE="${1}"

  if [[ ! -r "${CONFIG_FILE}" ]]; then
    echo "${CONFIG_FILE} doesn't exist or is not readable"
    exit 5
  fi

  CONFIG_SYNTAX="^\s*#|^\s*$|^[0-9a-zA-Z_]+=\"[^\"]*$|^[0-9a-zA-Z_]+=\"[^\"]*\
\"$|[^\"]*\"$"

  if egrep -q -v "${CONFIG_SYNTAX}" "${CONFIG_FILE}"; then
    echo "Error parsing config file ${CONFIG_FILE}." >&2
    echo "The following lines in the configfile do not fit the syntax:" >&2
    egrep -vn "${CONFIG_SYNTAX}" "$CONFIG_FILE"
    exit 6
  fi
  source "${CONFIG_FILE}"
}

validate_fasta(){
  SFILE=${1}
  STYPE=${2}

  if [[ ! -r "${SFILE}" ]]; then
    echo "${SFILE} doesn't exist or is not readable"
  fi

  java -jar "${fasta_validator}" -nogui -f "${SFILE}" -t "${STYPE}"
  EXIT_CODE="$?"
}


main(){
  if [[ -n "${CONFIG_FILE}" ]]; then
    read_config "${CONFIG_FILE}"
  fi

  validate_fasta "${SFILE}" "${STYPE}"

  if [ "${EXIT_CODE}" -eq 0 ]; then
    echo "Valid FASTA file."
  else
    echo "Invalid FASTA file."
  fi
  exit "${EXIT_CODE}"
}

if [ "$#" -eq 0 ]; then
  show_usage
fi


#######################################
# parse positional parameters
#######################################

while :; do
  case "${1}" in
    -h|-\?|--help) # Call a "show_help" function to display a synopsis,
                   # then exit.
    show_usage
    exit
    ;;
###############
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
###############
    -f|--fastafile) # Takes an option argument, ensuring it has been specified.
    if [ -n "${2}" ]; then
      SFILE="${2}"
      shift
    else
      printf 'ERROR: "--fastafile" requires a non-empty option argument.\n'>&2
      exit 1
    fi
    ;;
    --fastafile=?*)
    SFILE=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;
    --fastafile=)         # Handle the case of an empty --file=
    printf 'ERROR: "--fastafile" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
###############
    -t|--seqtype) # Takes an option argument, ensuring it has been specified.
    if [ -n "${2}" ]; then
      STYPE="${2}"
      shift
    else
      printf 'ERROR: "--seqtype" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;
    --seqtype=?*)
    STYPE=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;
    --seqtype=)         # Handle the case of an empty --file=
    printf 'ERROR: "--seqtype" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
###############
    --)              # End of all options.
    shift
    break
    ;;
    -?*)
    printf 'WARN: Unknown option (ignored): %s\n' "${1}" >&2
    ;;
    *)  # Default case: If no more options then break out of the loop.
    break
    esac
    shift
done

main "$@"
