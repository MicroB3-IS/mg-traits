#!/bin/bash
################################################################################
################################################################################
# DESCRIPTION: this script runs SINA
# DEPENDENCIES: sina
# CONFIGURATION VARIABLES: ${sina}, ${sina_seed}, ${sina_ref}
# EXIT CODES:
# 0    no errors
# 1    input/output error
# 5    config file not found or readable
# 6    config file format error
################################################################################
################################################################################

show_usage(){
  cat <<EOF
  Usage: ${0##*/} [-h] [-c|--config FILE] [-i|--inputdir DIR] \
[-o|--prefix STRIG] [-o|--outdir DIR]

  -c|--config        configuration file
  -h|--help          display this help and exit
  -i|--inputdir      input directory: where files are
  -o|--outdir        output directory
  -p|--prefix        fasta file input prefix
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


function sina() {

  local INPUTDIR="${1}"
  local OUTDIR="${2}"
  local PREFIX="${3}"

  ############################
  # sina files
  ############################

  IN_FASTA_FILE="${INPUTDIR}/${PREFIX}-${SGE_TASK_ID}.fasta"
  SINA_OUTFILE_SCREEN="${OUTDIR}/${PREFIX}-${SGE_TASK_ID}.16S.screen.fasta"
  SINA_OUTFILE_ALIGN="${OUTDIR}/${PREFIX}-${SGE_TASK_ID}.16S.align.fasta"
  SINA_OUTFILE_CLASSIFY="${OUTDIR}/${PREFIX}-${SGE_TASK_ID}.16S.classify.fasta"
  SINA_SCREEN_LOG="${OUTDIR}/${PREFIX}-${SGE_TASK_ID}.16S.screen.log"
  SINA_ALIGN_LOG="${OUTDIR}/${PREFIX}-${SGE_TASK_ID}.16S.align.log"
  SINA_CLASSIFY_LOG="${OUTDIR}/${PREFIX}-${SGE_TASK_ID}.16S.classify.log"
  SINA_SCREEN_RUN_LOG="${OUTDIR}/${PREFIX}-${SGE_TASK_ID}.16S.screen.run.log"
  SINA_ALIGN_RUN_LOG="${OUTDIR}/${PREFIX}-${SGE_TASK_ID}.16S.align.run.log"
  SINA_CLASSIFY_RUN_LOG="${OUTDIR}/${PREFIX}-${SGE_TASK_ID}\
.16S.classify.run.log"

  SINA_SOCKET=":/tmp/mg_traits_pt_"$(tr -cd '[:alnum:]' < /dev/urandom | \
fold -w 32 | head -n 1)

  ################
  # aling
  ################

  "${sina}" -i "${IN_FASTA_FILE}" -o "${SINA_OUTFILE_ALIGN}" \
  --intype fasta --ptdb "${sina_seed}" --ptport "${SINA_SOCKET}" \
  --fs-min 40 --fs-max 40 --fs-req=1 --fs-kmer-no-fast \
  --fs-min-len=50 --fs-req-full=0 --min-idty 60 \
  --meta-fmt comment \
  --show-conf \
  --log-file="${SINA_ALIGN_LOG}" \
  2> "${SINA_ALIGN_RUN_LOG}"

  if [[ "$?" -ne "0" ]]; then
    echo "SINA alignment file ${IN_FASTA_FILE} failed"
    exit 2
  fi

  NUM_RNA_ALIGN=$(grep -c '>' "${SINA_OUTFILE_ALIGN}")
  if [[ "${NUM_RNA_ALIGN}" -eq "0" ]]; then
    echo "No aligned RNA sequences by sina in file ${IN_FASTA_FILE}"
    exit 2;
  fi

  ##################
  # classify
  #################

  "${sina}" -i "${SINA_OUTFILE_ALIGN}" -o "${SINA_OUTFILE_CLASSIFY}" \
    --ptdb "${sina_ref}" \
    --ptport "${SINA_SOCKET}" \
    --prealigned \
    --meta-fmt comment \
    --search \
    --search-db "${sina_ref}" \
    --lca-fields tax_slv \
    --show-conf \
    --log-file="${SINA_CLASSIFY_LOG}" \
    2> "${SINA_CLASSIFY_RUN_LOG}"


  if [[ "$?" -ne "0" ]]; then
    echo "SINA classify file ${IN_FASTA_FILE} failed"
    exit 2
  fi

  NUM_RNA_CLASSIFY=$(grep -c '>' "${SINA_OUTFILE_CLASSIFY}")
  if [[ "${NUM_RNA_CLASSIFY}" -eq "0" ]]; then
    echo "No classified RNA sequences by sina in file ${IN_FASTA_FILE}"
    exit 2;
  fi

  EXIT_CODE="$?"
}



main(){

  if [[ -n "${CONFIG_FILE}" ]]; then
    read_config "${CONFIG_FILE}"
  fi

  export LD_LIBRARY_PATH
  sina "${INPUTDIR}" "${OUTDIR}" "${PREFIX}"

  if [[ "${EXIT_CODE}" -eq "0" ]]; then
    echo "sina alignment successful"
  else
    echo "sina alignment failed"
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

