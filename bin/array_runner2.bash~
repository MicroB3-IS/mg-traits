#!/bin/bash
#$ -cwd
#$ -j y
#$ -t 1-1
#$ -pe threaded 1
#$ -tc 3


NSLOTS=4
SGE_TASK_ID=1
LABELS_LIST="/bioinf/projects/megx/mg-traits/mg-traits_github_floder/139_prokrich.txt"
SAMPLE_LABEL=$( awk -v L="${SGE_TASK_ID}" 'NR==L' "${LABELS_LIST}" );

###########################################################################################################
# 1 - Preprocess data
###########################################################################################################
PREPROCESS_DIR="/bioinf/projects/megx/mg-traits/TARA_crunch/preprocess_data"
preprocess="/bioinf/projects/megx/mg-traits/mg-traits_github_floder/bin/preprocess_runner.sh"
PREPROCESSJOB="mt-preprocess"
mt_admin_mail="epereira@mpi-bremen.de"

mkdir  "${PREPROCESS_DIR:?}"/"${SAMPLE_LABEL}"
qsub -sync y -pe threaded "${NSLOTS}" -N "${PREPROCESSJOB}" -M "${mt_admin_mail}" -o "${PREPROCESS_DIR:?}"/"${SAMPLE_LABEL}" -wd "${PREPROCESS_DIR}"/"${SAMPLE_LABEL}" -j y \
"${preprocess}" "${SAMPLE_LABEL}"

if [[ $? -ne "0" ]]; then
  mail -s "preprocess:${SAMPLE_LABEL} failed ${preprocess}"
  exit 2;
fi

###########################################################################################################
# 2 - mg_traits.sh
###########################################################################################################

RANDOM_STRING=$(date +%s.%N | sha256sum | base64 | head -c 10 ; echo )
RANDOM_LABEL="${SAMPLE_LABEL}_${RANDOM_STRING}"
# RANDOM_LABEL="test_label"

mv "${PREPROCESS_DIR:?}/${SAMPLE_LABEL}/pre-process.SR.fasta" "${PREPROCESS_DIR:?}/${SAMPLE_LABEL}/pre-process.SR.${RANDOM_LABEL}.fasta"
FILE="${PREPROCESS_DIR:?}/${SAMPLE_LABEL}/pre-process.SR.${RANDOM_LABEL}.fasta"

echo "INSERT INTO mg_traits.mg_traits_jobs VALUES ('anonymous','file://${FILE}','${RANDOM_LABEL}','marine');" | psql -U epereira -d megdb_r8 -h antares -p 5434
echo "${RANDOM_LABEL}" "${FILE}"

# RETURN_CODE=$( echo "SELECT return_code FROM mg_traits.mg_traits_jobs WHERE sample_label = '${RANDOM_LABEL}' \
# AND mg_url='file://${FILE}' ORDER BY time_started DESC LIMIT 1" | psql -U epereira -d megdb_r8 -h antares -p 5434 | sed -n 3p )
# 
# while [[ "${RETURN_CODE}" -eq "-1" ]]; do
#   echo "sleeping ..."
#   sleep 5m
#   RETURN_CODE=$( echo "SELECT return_code FROM mg_traits.mg_traits_jobs WHERE sample_label = '${RANDOM_LABEL}' ORDER BY time_started DESC LIMIT 1" | \
#   psql -U epereira -d megdb_r8 -h antares -p 5434 | sed -n 3p )
# done
# 
# rm -r  "${PREPROCESS_DIR:?}/${SAMPLE_LABEL}"

