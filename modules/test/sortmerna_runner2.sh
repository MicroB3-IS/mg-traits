#!/bin/bash
#$ -j y
#$ -cwd


##### load sortmerna module #####
source /bioinf/software/etc/profile.modules
module load sortmerna/2.0
##### load sortmerna module #####

source ./01-subjobs_env
source /bioinf/projects/megx/mg-traits/resources/config_files/config.bash
source /bioinf/projects/megx/mg-traits/resources/config_files/config.functions.bash

#MEM=$(free -m | grep Mem | awk '{printf "%d",$2/3}')
MEM=4000


IN_FASTA_FILE="05-part-${SGE_TASK_ID}.fasta"

sortmerna --reads "${IN_FASTA_FILE}" -a "${NSLOTS}" --ref \
"${DB}"/rRNA_databases/silva-bac-16s-id90.fasta,\
"${DB}"/index/silva-bac-16s-db:"${DB}"/rRNA_databases/silva-arc-16s-id95.fasta,\
"${DB}"/index/silva-arc-16s-db:"${DB}"/rRNA_databases/silva-euk-18s-id95.fasta,\
"${DB}"/index/silva-euk-18s-db --blast 1 --fastx --aligned "06-part-${SGE_TASK_ID}" -v --log -m "${MEM}" --best 1 >> sortmerna.log

if [[ $? -ne "0" ]]; then
  email_comm "sortmerna failed: sortmerna --reads "${IN_FASTA_FILE}" -a ${NSLOTS} --ref ${DB}/rRNA_databases/silva-bac-16s-id90.fasta ..."
  db_error_comm "sortmerna failed. File "${IN_FASTA_FILE}". Job ${JOB_ID}"
  qdel -u megxnet
  exit 2;
fi
