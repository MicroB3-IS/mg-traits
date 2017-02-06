#!/bin/bash
################################################################################
################################################################################
# DESCRIPTION: this script runs SortMeRNA
# DEPENDENCIES: SortMeRNA
# CONFIGURATION VARIABLES: ${sortmerna_version}, ${DB}, ${NSLOTS}, ${SMRNA_MEM}
# ${REF}
# EXIT CODES:
# 0    no errors
# 1    input/output error
# 5    config file not found or readable
# 6    config file error format
################################################################################
################################################################################

show_usage(){
  cat <<EOF
  Usage: ${0##*/} [-h] [-c|--config FILE] [-e|--evalue NUMBER] \
[-o|--outdir DIR] [-i|--inputdir DIR] [-p|--inprefix STRING] \
[-q|--outprefix STRING ]

  -h|--help          display this help and exit
  -c|--config        configuration file
  -e|--evalue        sortmerna evalue
  -i|--inputdir      input directory: where files are
  -o|--outdir        output directory
  -p|--inprefix      fasta file input prefix
  -q|--outprefix     fasta file output prefix
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

function smrna() {

  local INPUT="${1}"
  local OUTPUT="${2}"
  local EVALUE="${3}"

  if [[ ! -r "${INPUT}" ]]; then
    echo "${INPUT} doesn't exist or is not readable"
  fi

  ##### load sortmerna module #####
  source /bioinf/software/etc/profile.modules
  module load sortmerna/"${sortmerna_version}"
  ##### load sortmerna module #####

  REF="${DB}/rRNA_databases/silva-bac-16s-id90.fasta,\
${DB}/index/silva-bac-16s-db:${DB}/rRNA_databases/silva-arc-16s-id95.fasta,\
${DB}/index/silva-arc-16s-db:${DB}/rRNA_databases/silva-euk-18s-id95.fasta,\
${DB}/index/silva-euk-18s-db"

  sortmerna --reads "${INPUT}" -a "${NSLOTS}" --ref "${REF}" \
  --blast 1 --fastx --aligned "${OUTPUT}" -v --log -m "${SMRNA_MEM}" \
  -e "${EVALUE}" --best 1 2>> sortmerna.log

  EXIT_CODE="$?"
}

main(){

  if [[ -n "${CONFIG_FILE}" ]]; then
    read_config "${CONFIG_FILE}"
  fi

  INPUT="${INPUTDIR}"/"${INPREFIX}"-"${SGE_TASK_ID}".fasta
  OUTPUT="${OUTDIR}"/"${OUTPREFIX}"-"${SGE_TASK_ID}"

  smrna "${INPUT}" "${OUTPUT}" "${EVALUE}"

  if [[ "${EXIT_CODE}" -eq "0" ]]; then
    echo "sortmerna successful"
  else
    echo "sortmerna failed"
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
    -e|--evalue)  # Takes an option argument, ensuring it has been specified.
    if [[ -n "${2}" ]]; then
      EVALUE="${2}"
      shift
    else
      printf 'ERROR: "--evalue" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;
    --evalue=?*)
    EVALUE=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;
    --evalue=)         # Handle the case of an empty --file=
    printf 'ERROR: "--evalue" requires a non-empty option argument.\n' >&2
    exit 1
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
    -p|--inprefix)  # Takes an option argument, ensuring it has been specified.
    if [[ -n "${2}" ]]; then
      INPREFIX="${2}"
      shift
    else
      printf 'ERROR: "--inprefix" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;
    --inprefix=?*)
    INPREFIX=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;
    --inprefix=)         # Handle the case of an empty --file=
    printf 'ERROR: "--inprefix" requires a non-empty option argument.\n' >&2
    exit 1
    ;;
#############
    -q|--outprefix)  # Takes an option argument, ensuring it has been specified.
    if [[ -n "${2}" ]]; then
      OUTPREFIX="${2}"
      shift
    else
      printf 'ERROR: "--outprefix" requires a non-empty option argument.\n' >&2
      exit 1
    fi
    ;;
    --outprefix=?*)
    OUTPREFIX=${1#*=} # Delete everything up to "=" and assign the remainder.
    ;;
    --outprefix=)         # Handle the case of an empty --file=
    printf 'ERROR: "--outprefix" requires a non-empty option argument.\n' >&2
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

