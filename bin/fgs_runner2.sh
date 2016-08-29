#!/bin/bash
#$ -j y
#$ -cwd

##### load fraggenescan module #####
source /bioinf/software/etc/profile.modules
module load fraggenescan/1.19
##### load fraggenescan module #####

source ./01-subjobs_env
source /bioinf/projects/megx/mg-traits/mg-traits_github_floder/config_files/config.bash
source /bioinf/projects/megx/mg-traits/mg-traits_github_floder/config_files/config.functions.bash

############################
# run fgs
############################

IN_FASTA_FILE="05-part-${SGE_TASK_ID}.fasta"

run_FragGeneScan.pl -genome="${IN_FASTA_FILE}" -out="${IN_FASTA_FILE}".genes10 -complete=0 -train=illumina_5 -thread="${NSLOTS}"
# "${frag_gene_scan}" -genome="${IN_FASTA_FILE}" -out="${IN_FASTA_FILE}".genes10 -complete=0 -train=illumina_5 -thread="${NSLOTS}"

if [[ $? -ne "0" ]]; then
  email_comm "frag_gene_scan failed: ${frag_gene_scan} -genome=${IN_FASTA_FILE} -out=${IN_FASTA_FILE}.genes10 ..."
  db_error_comm "frag_gene_scan failed. File ${IN_FASTA_FILE}. Job $JOB_ID"
  exit 2;
fi





