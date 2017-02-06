#!/bin/bash


source ./01-environment

function email_comm() {
mail -s "mg_traits:${JOB_ID} failed" "${mt_admin_mail}" <<EOF
"${1}"
EOF
}

function db_error_comm() {
  echo "UPDATE mg_traits.mg_traits_jobs SET time_finished = now(), return_code = 1, error_message = '${1}' \
  WHERE sample_label = '${SAMPLE_LABEL}' AND id = '${MG_ID}';" | psql -U "${target_db_user}" -h "${target_db_host}" -p "${target_db_port}" -d "${target_db_name}"
}


NSLOTS=$1
NFILES=$2
FGS_JOBARRAYID=$3

cat > fgs_runner << EOF
#!/bin/bash
#$ -j y
#$ -t 1-${NFILES}
#$ -pe threaded 4
#$ -cwd
#$ -N ${FGS_JOBARRAYID}


############################
# run fgs
############################


IN_FASTA_FILE="05-part-\${SGE_TASK_ID}.fasta"

${frag_gene_scan} -genome=\${IN_FASTA_FILE} -out=\${IN_FASTA_FILE}.genes10 -complete=0 -train=illumina_5 -thread="${NSLOTS}"

if [[ \$? -ne "0" ]]; then
  email_comm "frag_gene_scan failed: ${frag_gene_scan} -genome=\${IN_FASTA_FILE} -out=\${IN_FASTA_FILE}.genes10 ..."
  db_error_comm "frag_gene_scan failed. File \${IN_FASTA_FILE}. Job $JOB_ID"
  qdel -u megxnet
  exit 2;
fi  


# echo "UPDATE mg_traits.mg_traits_jobs SET total_run_time = total_run_time + \${RUN_TIME}, time_protocol = time_protocol || \
# ('\${JOB_ID}', 'mg_traits_fgs:\${SGE_TASK_ID}', \${RUN_TIME})::mg_traits.time_log_entry WHERE sample_label = '\${SAMPLE_LABEL}' AND id = '\${MG_ID}';" \
# | psql -U \${target_db_user} -h \${target_db_host} -p \${target_db_port} -d \${target_db_name}

EOF


qsub ./fgs_runner
rm ./fgs_runner


