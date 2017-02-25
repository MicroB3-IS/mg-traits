#!/bin/bash
################################################################################
################################################################################
# DESCRIPTION: this script runs UProC
# DEPENDENCIES: uproc
# CONFIGURATION VARIABLES: ${uproc_version}, ${uproc_pfam}, ${uproc_model}
# EXIT CODES:
# 0    no errors
# 1    input/output error
# 5    no config file found or readable
# 6    config file format error
################################################################################
################################################################################
show_usage(){
  cat <<EOF
  Usage: ${0##*/} [-h] [-c|--config FILE] [-i|--input FILE] [-o|--output FILE] \
[-l|--log FILE] 

  -h|--help          display this help and exit
  -c|--config        configuration file
  -i|--input         input fasta file
  -l|--log           log file
  -o|--output        output annotation file
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


function uproc {

  local INPUT="${1}"
  local OUTPUT="${2}"
  local LOG="${3}"

  if [[ ! -r "${INPUT}" ]]; then
    echo "${INPUT} doesn't exist or is not readable"
  fi

  ##### load fraggenescan module #####
  source /bioinf/software/etc/profile.modules
  module load uproc/"${uproc_version}"
  ##### load fraggenescan module #####


  "${uproc}" -t "${NSLOTS}" -p -l -O 2 -P 3 -o "${OUTPUT}" "${uproc_pfam}"\
  "${uproc_model}" "${INPUT}" > "${LOG}"

  EXIT_CODE="$?"
}

main(){

  if [[ -n "${CONFIG_FILE}" ]]; then
    read_config "${CONFIG_FILE}"
  fi


  INPUT="${INPUTDIR}"/"${PREFIX}"-"${SGE_TASK_ID}".genes.ffn
  OUTPUT="${OUTDIR}"/"${PREFIX}"-"${SGE_TASK_ID}"-pfam-raw

  uproc "${INPUT}" "${OUTPUT}" "${LOG}"

  if [[ "${EXIT_CODE}" -eq "0" ]]; then
    echo "Uproc successful"
  else
    echo "Uproc failed"
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
#############
    -o|--outdir) # Takes an option argument, ensuring it has been
                 # specified.
    if [[ -n "${2}" ]]; then
      OUTDIR="${2}"
      shift
    else
      printf 'ERROR: "--outdir" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;
    --outdir=?*)
    OUTDIR=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;
    --outdir=)     # Handle the case of an empty --file=
    printf 'ERROR: "--outdir" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
#############
    -p|--prefix)  # Takes an option argument, ensuring it has been specified.
    if [[ -n "${2}" ]]; then
      PREFIX="${2}"
      shift
    else
      printf 'ERROR: "--prefix" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;
    --prefix=?*)
    PREFIX=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;
    --prefix=)         # Handle the case of an empty --file=
    printf 'ERROR: "--prefix" requires a non-empty option argument.\n' >&2
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

