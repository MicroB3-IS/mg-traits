#!/bin/bash -l

# set -x
source ~/.bash_profile

show_usage(){
  cat <<EOF
  Usage: ${0##*/} [-h] [-R1|--read1 FILE] [-R2|--read2 FILE] \
[-R|--single_end FILE] [-b|--bgc FILE] [-o|--outdir DIR]

-c  config file (default ./conf/conf)
-h  print this help
-o  output folder name
-R1 reads input pair 1
-R2 reads input pair 2
-R  single end reads
-t  number of slots
EOF
}

##############################################################################
#### parse parameters ########################################################
##############################################################################

while :; do
  case "${1}" in

    -h|-\?|--help) # Call a "show_help" function to display a synopsis, then
                   # exit.
    show_usage
    exit 1;
    ;;
#############
  -c|--config)
  if [[ -n "${2}" ]]; then
   CONFIG="${2}"
   shift
  fi
  ;;
  --config=?*)
  CONFIG="${1#*=}" # Delete everything up to "=" and assign the remainder.
  ;;
  --config=) # Handle the empty case
  printf 'Using default environment.\n' >&2
  ;;
#############
  -o|--outdir)
   if [[ -n "${2}" ]]; then
     OUT="${2}"
     shift
   fi
  ;;
  --outdir=?*)
  OUT="${1#*=}" # Delete everything up to "=" and assign the remainder.
  ;;
  --outdir=) # Handle the empty case
  printf 'Using default environment.\n' >&2
  ;;
#############
 -R|--single_end)
   if [[ -n "${2}" ]]; then
     SE="${2}"
     shift
   fi
  ;;
  --single_end=?*)
  SE="${1#*=}" # Delete everything up to "=" and assign the remainder.
  ;;
  --single_end=) # Handle the empty case
  printf 'Using default environment.\n' >&2
  ;;
#############
 -R1| --read1)
   if [[ -n "${2}" ]]; then
     R1="${2}"
     shift
   fi
  ;;
  --read1=?*)
  R1="${1#*=}" # Delete everything up to "=" and assign the remainder.
  ;;
  --read1=) # Handle the empty case
  printf "ERROR: --read1 requires a non-empty option argument.\n"  >&2
  exit 1
  ;;
#############
 -R2|--read2)
   if [[ -n "${2}" ]]; then
     R2="${2}"
     shift
   fi
  ;;
  --read2=?*)
  R2="${1#*=}" # Delete everything up to "=" and assign the remainder.
  ;;
  --read2=) # Handle the empty case
  printf "ERROR: --read2 requires a non-empty option argument.\n"  >&2
  exit 1
  ;;
#############
 -s|--sample_label)
   if [[ -n "${2}" ]]; then
     SAMPLE_LABEL="${2}"
     shift
   fi
  ;;
  --sample_label=?*)
  SAMPLE_LABEL="${1#*=}" # Delete everything up to "=" and assign the remainder.
  ;;
  --sample_label=) # Handle the empty case
  printf "ERROR: --sample_label requires a non-empty option argument.\n"  >&2
  exit 1
  ;;
#############
  -t|--nslots)
   if [[ -n "${2}" ]]; then
     NSLOTS="${2}"
     shift
   fi
  ;;
  --nslots=?*)
  NSLOTS="${1#*=}" # Delete everything up to "=" and assign the remainder.
  ;;
  --nslots=) # Handle the empty case
  printf 'Using default environment.\n' >&2
  ;;
############
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

################################################################################
## define variables
################################################################################
UFBGC_DIR="$(dirname "$(readlink -f "$0")")"

################################################################################
# 1 - Load general configuration
################################################################################
CONFIG="${UFBGC_DIR}/conf/conf"
if [[ -r "${CONFIG}" ]]; then
  source "${CONFIG}"
else
  exit 1
fi

################################################################################
# 2. Load functions
################################################################################
FUNCTIONS="${UFBGC_DIR}/conf/functions.bash"
if [[ -r "${FUNCTIONS}" ]]; then
  source "${FUNCTIONS}"
else
  exit 1
fi

######################################################
# Insert into database
######################################################

echo "INSERT INTO epereira.ufbgc_recruiter_jobs \
      (sample_label, \
      time_started, \
      hostname, \
      nslots, \
      files) \
      VALUES \
      ('${SAMPLE_LABEL}',\
       now(),\
      '${HOSTNAME}',\
      '${NSLOTS}',\
      '${SE}; ${R1}; ${R2}');" | \
      psql -U "${target_db_user}" \
      -h "${target_db_host}" \
      -p "${target_db_port}" \
      -d "${target_db_name}"


if [[ "$?" -ne "0" ]]; then
  email_comm "psql INSERT failed:${SAMPLE_LABEL}"
  db_error_comm "psql INSERT failed"
  exit 1
fi

##############################################################################
# 3. Create output directories
##############################################################################
if [[ -z "${OUT}"  ]]; then
  OUT="ufBGC_out"
fi

mkdir "${RUNNING_JOBS_DIR}"/"${OUT}"

if [[ "$?" -ne "0" ]]; then
   email_comm "could not create ${OUT} directory: ${SAMPLE_LABEL}"
   db_error_comm "could not create ${OUT} directory"
   exit 1
fi

THIS_JOB_TMP_DIR="${RUNNING_JOBS_DIR}"/"${OUT}"

################################################################################
# 3.Identify BGC reads
################################################################################
UPROC_PE_OUT="${THIS_JOB_TMP_DIR}"/all.pe.bgc.gz
UPROC_SE_OUT="${THIS_JOB_TMP_DIR}"/all.se.bgc.gz


if [[ -r "${R1}" ]]; then

  "${uproc_dna}" -s -z "${UPROC_PE_OUT}" -p -t "${NSLOTS}" \
  "${DBDIR}" "${MODELDIR}" "${R1}" "${R2}"

fi

if [[ "$?" -ne "0" ]]; then
   email_comm "uproc PE failed: ${SAMPLE_LABEL}"
   db_error_comm "uproc PE failed"
   cleanup
   exit 1
fi


if [[ -r "${SE}" ]]; then

  "${uproc_dna}" -s -z "${UPROC_SE_OUT}" -p -t "${NSLOTS}" \
  "${DBDIR}" "${MODELDIR}" "${SE}"

fi

if [[ "$?" -ne "0" ]]; then
   email_comm "uproc SE failed: ${SAMPLE_LABEL}"
   db_error_comm "uproc SE failed"
   cleanup
   exit 1
fi

################################################################################
# 4.Make abundance table
################################################################################

ALL_BGC=$(find  "${THIS_JOB_TMP_DIR}"/  -name "all.*bgc.gz" )

zcat "${ALL_BGC}" | cut -f7 -d"," | sort | uniq -c > \
"${THIS_JOB_TMP_DIR}"/counts.tbl

awk '{
    if (NR==FNR) {
      line[$2]=$1;
      next;
          }
      if( $2 in line ) {
        print $1,$2,line[$2];
      }
    }' "${THIS_JOB_TMP_DIR}"/counts.tbl "${CLASS2DOMAINS}" > \
"${THIS_JOB_TMP_DIR}"/class2domains2abund.tbl


if [[ "$?" -ne "0" ]]; then
   email_comm "awk table join failed: ${SAMPLE_LABEL}"
   db_error_comm "awk table join failed"
   cleanup
   exit 1
fi

rsync -a --remove-source-files "${THIS_JOB_TMP_DIR}" "${FINISHED_JOBS_DIR}"
rmdir "${THIS_JOB_TMP_DIR}"

if [[ "$?" -ne "0" ]]; then
 email_comm "rsync to finished_jobs failed: ${SAMPLE_LABEL}"
 db_error_comm  "rsync to finished_jobs failed"
 cleanup
 exit 1
fi


#########################################################################
# database update
#########################################################################
echo "UPDATE epereira.ufbgc_recruiter_jobs \
      SET \
      time_finished = now(), \
      return_code = 0 \
      WHERE sample_label = '${SAMPLE_LABEL}';" | \
      psql \
      -U "${target_db_user}" \
      -h "${target_db_host}" \
      -p "${target_db_port}" \
      -d "${target_db_name}"

