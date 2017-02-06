#!/bin/bash
################################################################################
################################################################################
# DESCRIPTION: this script splits a fasta file
# DEPENDENCIES: awk
# CONFIGURATION VARIABLES: ${NSEQ}
# EXIT CODES:
# 0    no errors
# 1    input/output error
# 5    config file not found or readable
# 6    config file format error
################################################################################
################################################################################


# splitrer exit codes
# 0    valid input
# 1    no valid url
# 2    no recognized downlaod file format
# 37   download failed

show_usage(){
  cat <<EOF
  Usage: ${0##*/} [-h] [-c|--config FILE] [-i|--input FILE] [-o|--outdir DIR]\
[-p|--prefix STRIG]

  -c|--config        configuration file
  -h|--help          display this help and exit
  -i|--input         input fasta file
  -o|--outdir        output directory
  -p|--prefix        prefix splitted file
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


function split_fasta() {

  local INPUT="${1}"
  local PREFIX="${2}"
  local OUTDIR="${3}"


  if [[ ! -r "${INPUT}" ]]; then
    echo "${INPUT} doesn't exist or is not readable"
  fi

  awk -v n="${NSEQ}" -v d="${OUTDIR}" -v p="${PREFIX}" \
  'BEGIN {n_seq=0; partid=1;} {
    if (/^>/) {
      if(n_seq%n==0) {
        file=sprintf(p"-%d.fasta",partid);
        partid++;
      }
      print $0 >> d"/"file; n_seq++; next;
    }
    print $0 >> d"/"file;
  }' < "${INPUT}"

  EXIT_CODE="$?"
}

main(){

  if [[ -n "${CONFIG_FILE}" ]]; then
    read_config "${CONFIG_FILE}"
  fi

  split_fasta "${INPUT}" "${PREFIX}" "${OUTDIR}" "${NSEQ}"

  if [[ "${EXIT_CODE}" -eq "0" ]]; then
    echo "Split successful"
  else
    echo "Split failed"
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

