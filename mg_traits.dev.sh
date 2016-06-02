#!/bin/bash
set -x
set -o pipefail

START_TIME=`date +%s.%N`

echo "Environment variables:"

source ~/.bashrc
source config.bash

echo -e "\tJob ID: ${JOB_ID}"
echo -e "\tTarget database: ${target_db_user}@${target_db_host}:${target_db_port}/${target_db_name}"
echo -e "\tCD-HIT-DUP: ${cd_hit_dup}"
echo -e "\tCD-HIT-EST: ${cd_hit_est}"
echo -e "\tCD-HIT-MMS: ${cd_hit_mms}"
echo -e "\tFragGeneScan: ${frag_gene_scan}"
echo -e "\tUPro: ${uproc}"
echo -e "\tR: ${r_interpreter}"
echo -e "\tTemp dir: ${temp_dir}"
echo -e "\tMG traits dir: ${mg_traits_dir}"
echo -e "\tJob out dir: ${job_out_dir}"
echo -e "\tMT admin mail: ${mt_admin_mail}"



###########################################################################################################
# Parse parameters
###########################################################################################################

# urldecode input
string=$(echo $1 | sed -e 's/&/|/g' -e 's/\+/ /g' -e 's/%25/%/g' -e 's/%20/ /g' -e 's/%09/ /g' -e 's/%21/!/g' -e 's/%22/"/g' -e 's/%23/#/g' -e 's/%24/\$/g' -e 's/%26/\&/g' -e 's/%27/'\''/g' -e 's/%28/(/g' -e 's/%29/)/g' -e 's/%2a/\*/g' -e 's/%2b/+/g' -e 's/%2c/,/g' -e 's/%2d/-/g' -e 's/%2e/\./g' -e 's/%2f/\//g' -e 's/%3a/:/g' -e 's/%3b/;/g' -e 's/%3d/=/g' -e 's/%3e//g' -e 's/%3f/?/g' -e 's/%40/@/g' -e 's/%5b/\[/g' -e 's/%5c/\\/g' -e 's/%5d/\]/g' -e 's/%5e/\^/g' -e 's/%5f/_/g' -e 's/%60/`/g' -e 's/%7b/{/g' -e 's/%7c/|/g' -e 's/%7d/}/g' -e 's/%7e/~/g' -e 's/%09/      /g')

# set delimiter
IFS="|"

# parse input
echo "Input parameters:"
for pair in $string; do
key=${pair%%=*}
value=${pair#*=}

printf "\t$key=$value\n";

if [ "$key" = "sample_label" ]; then
	SAMPLE_LABEL=$value;
fi

if [ "$key" = "mg_url" ]; then
	MG_URL=$value;
fi

if [ "$key" = "customer" ]; then
	CUSTOMER=$value;
fi

if [ "$key" = "sample_environment" ]; then
	SAMPLE_ENVIRONMENT=$value;
fi

if [ "$key" = "time_submitted" ]; then
	SUBMIT_TIME=$value;
fi

if [ "$key" = "make_public" ]; then
	MAKE_PUBLIC=$value;
fi

if [ "$key" = "keep_data" ]; then
	KEEP_DATA=$value;
fi

if [ "$key" = "id" ]; then
	MG_ID=$value;
fi


done

###########################################################################################################
# write JobID and Hostname to database
###########################################################################################################

SAMPLE_LABEL=test1
JOB_ID=1
MG_ID=1

echo "UPDATE mg_traits.mg_traits_jobs SET time_started = now(), job_id = $JOB_ID, cluster_node = '$HOSTNAME' WHERE sample_label = '$SAMPLE_LABEL' AND id = $MG_ID;"

DB_RESULT=`echo "UPDATE mg_traits.mg_traits_jobs SET time_started = now(), job_id = $JOB_ID, cluster_node = '$HOSTNAME' WHERE sample_label = '$SAMPLE_LABEL' AND id = $MG_ID;" | psql -U $target_db_user -h $target_db_host -p $target_db_port -d $target_db_name`

if [ "$?" -ne "0" ]; then
  echo "Cannot connect to database"
  mail -s "mg_traits:$JOB_ID failed" "$mt_admin_mail" <<EOF
Cannot connect to database. Output:
$DB_RESULT
EOF
  exit 2
fi


if [ "$DB_RESULT" != "UPDATE 1" ]; then
	echo "sample name '$SAMPLE_LABEL' is not in database"
	mail -s "mg_traits:$JOB_ID failed" "$mt_admin_mail" <<EOF
sample name '$SAMPLE_LABEL' is not in database
Result: $DB_RESULT
EOF
	exit 2
fi

## creating output dir for all job results
#job_out_dir="${job_out_dir}/${JOB_ID}"
#mkdir -P ${job_out_dir}


###########################################################################################################
# Check for utilities and directories
###########################################################################################################

ERROR_MESSAGE=$(\
check_required_writable_directories "${temp_dir}" "${RUNNING_JOBS_DIR}" "${FAILED_JOBS_DIR}" "${job_out_dir}";
check_required_readable_directories "${mg_traits_dir}"; 
check_required_programs "${cd_hit_dup}" "${cd_hit_est}" "${cd_hit_mms}" "${uproc}" "${r_interpreter}";)

if [ -n "$ERROR_MESSAGE" ]; then
	echo "UPDATE mg_traits.mg_traits_jobs SET return_code = 2, error_message = '$ERROR_MESSAGE failed' WHERE sample_label = '$SAMPLE_LABEL' AND id = $MG_ID;" | psql -U $target_db_user -h $target_db_host -p $target_db_port -d $target_db_name
	mail -s "mg_traits:$JOB_ID failed" "$mt_admin_mail" <<EOF
$ERROR_MESSAGE
EOF
	exit 2
fi

###########################################################################################################
# Create job directory
###########################################################################################################

echo "This job tmp dir: $THIS_JOB_TMP_DIR"
mkdir $THIS_JOB_TMP_DIR
cd $THIS_JOB_TMP_DIR

mkdir $THIS_JOB_TMP_DIR_DATA
mkdir $SINA_LOG_DIR

echo "Logs, data and temp files will be written to:$(pwd)"

if [ "$(pwd)" != "$THIS_JOB_TMP_DIR" ]; then
    echo "UPDATE mg_traits.mg_traits_jobs SET time_finished = now(), return_code = 2, error_message = 'could not access job temp dir' WHERE sample_label = '$SAMPLE_LABEL' AND id = '$MG_ID';" | psql -U $target_db_user -h $target_db_host -p $target_db_port -d $target_db_name
    mail -s "mg_traits:$JOB_ID failed" "$mt_admin_mail" <<EOF
could not access job temp dir $THIS_JOB_TMP_DIR
EOF
    exit 2
fi

###########################################################################################################
# Download data files from SVN
###########################################################################################################

echo "$PFAM_ACCESSIONS_URL"
curl -s $PFAM_ACCESSIONS_URL > $PFAM_ACCESSIONS
if [ "$?" -ne "0" ]; then
  echo "failed"
  echo "UPDATE mg_traits.mg_traits_jobs SET time_finished = now(), return_code = 1, error_message = 'Could not retrieve $PFAM_ACCESSIONS_URL' WHERE sample_label = '$SAMPLE_LABEL' AND id = $MG_ID;" | psql -U $target_db_user -h $target_db_host -p $target_db_port -d $target_db_name
  cd ..
  mv $THIS_JOB_TMP_DIR $FAILED_JOBS_DIR
  #rm -rf $THIS_JOB_TMP_DIR
  mail -s "mg_traits:$JOB_ID failed" "$mt_admin_mail" <<EOF
Couldn't retrive pfam_file
EOF

  exit 1
fi

echo "$TFFILE_URL"
curl -s $TFFILE_URL > $TFFILE
if [ "$?" -ne "0" ]; then
  echo "failed"
  echo "UPDATE mg_traits.mg_traits_jobs SET time_finished = now(), return_code = 1, error_message = 'Could not retrieve $TFFILE_URL' WHERE sample_label = '$SAMPLE_LABEL' AND id = '$MG_ID';" | psql -U $target_db_user -h $target_db_host -p $target_db_port -d $target_db_name
  cd ..
  mv $THIS_JOB_TMP_DIR $FAILED_JOBS_DIR
  #rm -rf $THIS_JOB_TMP_DIR
  mail -s "mg_traits:$JOB_ID failed" "$mt_admin_mail" <<EOF
Couldn't retrive tf_file
EOF

  exit 1
fi


echo "$SLV_TAX_URL"
curl -s $SLV_TAX_URL > $SLV_FILE
if [ "$?" -ne "0" ]; then
  echo "failed"
  echo "UPDATE mg_traits.mg_traits_jobs SET time_finished = now(), return_code = 1, error_message = 'Could not retrieve $SLV_TAX_URL' WHERE sample_label = '$SAMPLE_LABEL' AND id = $MG_ID;" | psql -U $target_db_user -h $target_db_host -p $target_db_port -d $target_db_name
  cd ..
  mv $THIS_JOB_TMP_DIR $FAILED_JOBS_DIR
  #rm -rf $THIS_JOB_TMP_DIR
  mail -s "mg_traits:$JOB_ID failed" "$mt_admin_mail" <<EOF
Couldn't retrive pfam_file
EOF

  exit 1
fi



###########################################################################################################
# Download file
###########################################################################################################

# validate URL
echo "$MG_URL"
regex='(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
if [[ ! "$MG_URL" =~ $regex ]]; then
  echo "Not a valid URL"
  echo "UPDATE mg_traits.mg_traits_jobs SET time_finished = now(), return_code = 1, error_message = 'Not a valid URL' WHERE sample_label = '$SAMPLE_LABEL' AND id = '$MG_ID';" | psql -U $target_db_user -h $target_db_host -p $target_db_port -d $target_db_name
  cd ..
  mv $THIS_JOB_TMP_DIR $FAILED_JOBS_DIR
  #rm -rf $THIS_JOB_TMP_DIR
  mail -s "mg_traits:$JOB_ID failed" "$mt_admin_mail" <<EOF
Invalid URL.
EOF

  exit 1
fi


#Check if the url already exist on our DB

URLDB=$(psql -t -U $target_db_user -h $target_db_host -p $target_db_port -d $target_db_name -c "SELECT count(*) FROM mg_traits.mg_traits_jobs where mg_url = '${MG_URL}' AND sample_label NOT ILIKE '%test% AND return_code = 0'")

if [ ${URLDB} -gt 1 ]; then
  echo "UPDATE mg_traits.mg_traits_jobs SET time_finished = now(), return_code = 1, error_message = 'The URL $MG_URL has been already succesfully crunched. If the file is different please change the file name.' WHERE sample_label = '$SAMPLE_LABEL' AND id = '$MG_ID';" | psql -U $target_db_user -h $target_db_host -p $target_db_port -d $target_db_name
  cd ..
  mv $THIS_JOB_TMP_DIR $FAILED_JOBS_DIR
  mail -s "mg_traits:$JOB_ID failed" "$mt_admin_mail" <<EOF
The URL $MG_URL has been already succesfully crunched. If the file is different please change the file name.
EOF
  exit 1
fi


printf "Downloading $MG_URL to $RAW_DOWNLOAD..."
curl -s $MG_URL > $RAW_DOWNLOAD

if [ "$?" -ne "0" ]; then
  echo "failed"
  echo "UPDATE mg_traits.mg_traits_jobs SET time_finished = now(), return_code = 1, error_message = 'Could not retrieve $MG_URL' WHERE sample_label = '$SAMPLE_LABEL' AND id = '$MG_ID';" | psql -U $target_db_user -h $target_db_host -p $target_db_port -d $target_db_name
  cd ..
  mv $THIS_JOB_TMP_DIR $FAILED_JOBS_DIR
  mail -s "mg_traits:$JOB_ID failed" "$mt_admin_mail" <<EOF
Couldn't retrive $MG_URL.
EOF
  exit 1
fi
echo "OK"

gunzip -qc $RAW_DOWNLOAD > $RAW_FASTA
if [ "$?" -ne "0" ]; then
  echo "File was uncompressed"
  rm $RAW_FASTA
  mv $RAW_DOWNLOAD $RAW_FASTA
fi

###########################################################################################################
# Validate file
###########################################################################################################

printf "Validating file..."
perl <<PERLSCRIPT
use Bio::SeqIO;
\$in = Bio::SeqIO->new(-file => '$RAW_FASTA', '-format' => 'Fasta');
\$out = Bio::SeqIO->new(-file => '>$FASTA_BAD', '-format' => 'Fasta');
while (my \$seq = \$in->next_seq) {
  if (\$seq->validate_seq(\$seq->seq) == 0 ){
     \$out->write_seq(\$seq);
     exit(1);
  } elsif (\$seq->length < 10){
     \$out->write_seq(\$seq);
     exit(2);
  }
}
PERLSCRIPT

FASTA_ERROR_CODE=$?

if [ "$FASTA_ERROR_CODE" -eq "1" ]; then
  FASTA_BAD_HEADER=$(grep '>' $FASTA_BAD | tr -d '>')
  FASTA_BAD_SEQ=$(cat $FASTA_BAD)
  echo "failed"
  echo "UPDATE mg_traits.mg_traits_jobs SET time_finished = now(), return_code = 1, error_message = '$MG_URL is not a valid FASTA file. FASTA validation failed at sequence $FASTA_BAD_HEADER.' WHERE sample_label = '$SAMPLE_LABEL' AND id = '$MG_ID';" | psql -U $target_db_user -h $target_db_host -p $target_db_port -d $target_db_name
  cd ..
  mv $THIS_JOB_TMP_DIR $FAILED_JOBS_DIR
  #rm -rf $THIS_JOB_TMP_DIR
  mail -s "mg_traits:$JOB_ID failed" "$mt_admin_mail" <<EOF
$MG_URL is not a valid FASTA file. Sequence validation failed.
$FASTA_BAD_SEQ
EOF
  exit 1
elif [ "$FASTA_ERROR_CODE" -eq "2" ]; then
  FASTA_BAD_HEADER=$(grep '>' $FASTA_BAD | tr -d '>')
  FASTA_BAD_SEQ=$(cat $FASTA_BAD)
  echo "failed"
  echo "UPDATE mg_traits.mg_traits_jobs SET time_finished = now(), return_code = 2, error_message = '$MG_URL is not a valid FASTA file. Sequence $FASTA_BAD_HEADER too short.' WHERE sample_label = '$SAMPLE_LABEL' AND id = '$MG_ID';" | psql -U $target_db_user -h $target_db_host -p $target_db_port -d $target_db_name
  cd ..
  mv $THIS_JOB_TMP_DIR $FAILED_JOBS_DIR
  #rm -rf $THIS_JOB_TMP_DIR
  mail -s "mg_traits:$JOB_ID failed" "$mt_admin_mail" <<EOF
$MG_URL is not a valid FASTA file. Sequence too short found.
$FASTA_BAD_SEQ
EOF
  exit 1
elif [ "$FASTA_ERROR_CODE" -ne "0" ]; then
  FASTA_BAD_HEADER=$(grep '>' $FASTA_BAD | tr -d '>')
  FASTA_BAD_SEQ=$(cat $FASTA_BAD)
  echo "failed"
  echo "UPDATE mg_traits.mg_traits_jobs SET time_finished = now(), return_code = 2, error_message = '$MG_URL is not a valid FASTA file.' WHERE sample_label = '$SAMPLE_LABEL' AND id = '$MG_ID';" | psql -U $target_db_user -h $target_db_host -p $target_db_port -d $target_db_name
  cd ..
  mv $THIS_JOB_TMP_DIR $FAILED_JOBS_DIR
  #rm -rf $THIS_JOB_TMP_DIR
  mail -s "mg_traits:$JOB_ID failed" "$mt_admin_mail" <<EOF
$MG_URL is not a valid FASTA file.
EOF
  exit 1
fi

echo "OK"

###########################################################################################################
# Check for duplicates
###########################################################################################################
printf "Removing duplicated sequences..."
$cd_hit_dup -i $RAW_FASTA -o $UNIQUE > $UNIQUE_LOG
if [ "$?" -ne "0" ]; then
  echo "failed"
  echo "UPDATE mg_traits.mg_traits_jobs SET time_finished = now(), return_code = 2, error_message = '$MG_URL could not be processed by cd-hit-dup' WHERE sample_label = '$SAMPLE_LABEL' AND id = '$MG_ID';" | psql -U $target_db_user -h $target_db_host -p $target_db_port -d $target_db_name
  cd ..
  mv $THIS_JOB_TMP_DIR $FAILED_JOBS_DIR
  mail -s "mg_traits:$JOB_ID failed" "$mt_admin_mail" <<EOF
$cd_hit_dup -i $RAW_FASTA -o /dev/null > $UNIQUE_LOG
exited with RC $? in job $JOB_ID.
Files are at: $FAILED_JOBS_DIR/job-$JOB_ID
EOF
  exit 2
fi
echo "OK"

NUM_READS=$(grep 'Total number of sequences:'  $UNIQUE_LOG|awk '{print $(NF)}')
NUM_UNIQUE=$(grep 'Number of clusters found:'  $UNIQUE_LOG|awk '{print $(NF)}')

echo "Number of sequences: "$NUM_READS
echo "Number of unique sequences: "$NUM_UNIQUE
if [ "$NUM_READS" -ne "$NUM_UNIQUE" ]; then
  echo "We found duplicates. Please provide a pre-processed metagenome."
  echo "UPDATE mg_traits.mg_traits_jobs SET time_finished = now(), return_code = 2, error_message = '$MG_URL contains duplicates. Please provide a pre-processed metagenome.' WHERE sample_label = '$SAMPLE_LABEL' AND id = '$MG_ID';" | psql -U $target_db_user -h $target_db_host -p $target_db_port -d $target_db_name
  cd ..
  mv $THIS_JOB_TMP_DIR $FAILED_JOBS_DIR
  exit 1
fi

# ###########################################################################################################
# # Cluster
# ###########################################################################################################
# printf 'Clustering at 95%%...'

# $cd_hit_est -i $RAW_FASTA -o $CLUST95 -c 0.95 -T 8 -M 50000 -d 0 > $CLUST95_LOG
# if [ "$?" -ne "0" ]; then
#   echo "failed"
#   echo "UPDATE mg_traits.mg_traits_jobs SET return_code = 2, error_message = '$MG_URL cannot be processed by cd-hit-est' WHERE sample_label = '$SAMPLE_LABEL';" | psql -U $target_db_user -h $target_db_host -p $target_db_port -d $target_db_name
#   cd ..
#   mv $THIS_JOB_TMP_DIR $tFAILED_JOBS_DIR
#   mail -s "mg_traits:$JOB_ID failed" "$mt_admin_mail" <<EOF
# $cd_hit_est -i $UNIQUE -o $CLUST95 -c 0.95 -T 8 -M 50000 -d 0 > $CLUST95_LOG
# exited with RC $? in job $JOB_ID.
# Files are at: $FAILED_JOBS_DIR/job-$JOB_ID
# EOF
#   exit 2
# fi
# echo "OK"

# NUM_CLUST95=$(grep -c '^>' $CLUST95_CLSTR)

# ###########################################################################################################
# # Remove singletons
# ###########################################################################################################
# printf "Removing singletons..."

# $cd_hit_mms $CLUST95 $CLUST95_CLSTR tmp_seqs 2
# if [ "$?" -ne "0" ]; then
#   echo "failed"
#   echo "UPDATE mg_traits.mg_traits_jobs SET return_code = 2, error_message = '$MG_URL cannot be processed by cd-hit' WHERE sample_label = '$SAMPLE_LABEL';" | psql -U $target_db_user -h $target_db_host -p $target_db_port -d $target_db_name
#   cd ..
#   mv $THIS_JOB_TMP_DIR $FAILED_JOBS_DIR
#   mail -s "mg_traits:$JOB_ID failed" "$mt_admin_mail" <<EOF
# $cd_hit_mms $CLUST95 $CLUST95_CLSTR tmp_seqs 2
# exited with RC $? in job $JOB_ID.
# Files are at: $FAILED_JOBS_DIR/job-$JOB_ID
# EOF
#   exit 2
# fi
# echo "OK"

###########################################################################################################
# Calculate sequence statistics
###########################################################################################################
printf "Calculating sequence statistics..."

infoseq $RAW_FASTA -only -pgc -length -noheading -auto > $INFOSEQ_TMPFILE
if [ "$?" -ne "0" ]; then
  echo "failed"
  echo "UPDATE mg_traits.mg_traits_jobs SET time_finished = now(), return_code = 2, error_message = 'Cannot calculate sequence statistics. Please contact adminitrator.' WHERE sample_label = '$SAMPLE_LABEL' AND id = '$MG_ID';" | psql -U $target_db_user -h $target_db_host -p $target_db_port -d $target_db_name
  cd ..
  mv $THIS_JOB_TMP_DIR $FAILED_JOBS_DIR
  mail -s "mg_traits:$JOB_ID failed" "$mt_admin_mail" <<EOF
infoseq $RAW_FASTA -only -pgc -length -noheading -auto > $INFOSEQ_TMPFILE
exited with RC $? in job $JOB_ID.
Files are at: $FAILED_JOBS_DIR/job-$JOB_ID
EOF
  exit 2
fi

$r_interpreter --vanilla --slave <<RSCRIPT
t<-read.table(file = "$INFOSEQ_TMPFILE", header = F)
bp<-sum(t[,1])
meanGC<-mean(t[,2])
varGC<-var(t[,2])
res<-paste(bp, meanGC, varGC, sep = ' ')
write(res, file = "$INFOSEQ_MGSTATS")
RSCRIPT

if [ "$?" -ne "0" ]; then
  echo "failed"
  echo "UPDATE mg_traits.mg_traits_jobs SET time_finished = now(), return_code = 2, error_message = 'Cannot process sequence statistics. Please contact adminitrator.' WHERE sample_label = '$SAMPLE_LABEL' AND id = '$MG_ID';" | psql -U $target_db_user -h $target_db_host -p $target_db_port -d $target_db_name
  cd ..
  mv $THIS_JOB_TMP_DIR $FAILED_JOBS_DIR
  mail -s "mg_traits:$JOB_ID failed" "$mt_admin_mail" <<EOF
$r_interpreter --vanilla --slave
exited with RC $? in job $JOB_ID.
Infoseq script!
Files are at: $FAILED_JOBS_DIR/job-$JOB_ID
EOF
  exit 2
fi
echo "OK"

NUM_BASES=$(cut -f1 $INFOSEQ_MGSTATS -d ' ')
GC=$(cut -f2 $INFOSEQ_MGSTATS -d ' ')
VARGC=$(cut -f3 $INFOSEQ_MGSTATS -d ' ')
printf "Number of bases: %d\nGC content: %f\nGC variance: %f\n" $NUM_BASES $GC $VARGC

###########################################################################################################
# Get ORFS
###########################################################################################################

#Split original
printf "Splitting file ($NSEQ seqs file)..."
awk -vO=$NSEQ 'BEGIN {n_seq=0;partid=1;} /^>/ {if(n_seq%O==0){file=sprintf("05-part-%d.fasta",partid);partid++;} print >> file; n_seq++; next;} { print >> file; }' < $RAW_FASTA
SUBJOBS=$(ls -1 05-part*.fasta | wc -l)
echo "OK"
echo "Split into $SUBJOBS sub jobs..."

# write out variables for sub jobs
echo frag_gene_scan=$frag_gene_scan >> 00-environment
echo sina=$sina >> 00-environment
echo sina_arb_pt_server=$sina_arb_pt_server >> 00-environment
echo sina_seed=$sina_seed >> 00-environment
echo sina_ref=$sina_ref >> 00-environment
echo uproc=$uproc >> 00-environment
echo r_interpreter=$r_interpreter >> 00-environment
echo target_db_host=$target_db_host >> 00-environment
echo target_db_port=$target_db_port >> 00-environment
echo target_db_user=$target_db_user >> 00-environment
echo target_db_name=$target_db_name >> 00-environment
echo mt_admin_mail=$mt_admin_mail >> 00-environment
echo THIS_JOB_TMP_DIR=$THIS_JOB_TMP_DIR >> 00-environment
echo TFFILE=$TFFILE >> 00-environment
echo PFAM_ACCESSIONS=$PFAM_ACCESSIONS >> 00-environment
echo SAMPLE_LABEL=$SAMPLE_LABEL >> 00-environment
echo RAW_FASTA=$RAW_FASTA >> 00-environment
echo GC=$GC >> 00-environment
echo VARGC=$VARGC >> 00-environment
echo NUM_BASES=$NUM_BASES >> 00-environment
echo NUM_READS=$NUM_READS >> 00-environment
echo THIS_JOB_ID=$JOB_ID >> 00-environment
echo temp_dir=$temp_dir >> 00-environment
echo FAILED_JOBS_DIR=$FAILED_JOBS_DIR >> 00-environment
echo RUNNING_JOBS_DIR=$RUNNING_JOBS_DIR >> 00-environment
echo FINISHED_JOBS_DIR=$FINISHED_JOBS_DIR >> 00-environment
echo SUBJOBS=$SUBJOBS >> 00-environment
echo uproc_pfam=$uproc_pfam >> 00-environment
echo uproc_model=$uproc_model >> 00-environment
echo MG_ID=$MG_ID >> 00-environment
echo SINA_LOG_DIR=$SINA_LOG_DIR >> 00-environment
echo SLV_FILE=$SLV_FILE >> 00-environment
echo ARBHOME=$ARBHOME >> 00-environment
echo LD_LIBRARY_PATH=$LD_LIBRARY_PATH >> 00-environment

echo "Submitting job array for SINA..."
qsub -pe threaded 2 -l mem_free=4500M  -t 1-$SUBJOBS -o $THIS_JOB_TMP_DIR -e $THIS_JOB_TMP_DIR -l ga -j y -terse -P megx.p -R y -m sa -M $mt_admin_mail -N $SINA_JOBARRAYID $mg_traits_dir/mg_traits_sina.sh $THIS_JOB_TMP_DIR

echo "Submitting job array for FGS..."
qsub -pe threaded 1 -t 1-$SUBJOBS -o $THIS_JOB_TMP_DIR -e $THIS_JOB_TMP_DIR -l ga -j y -terse -P megx.p -R y -m sa -M $mt_admin_mail -N $FGS_JOBARRAYID $mg_traits_dir/mg_traits_fgs.sh $THIS_JOB_TMP_DIR

echo "Submitting finishing job..."
qsub -pe threaded 8 -l h=\!mg32 -N $FINISHJOBID -o $THIS_JOB_TMP_DIR -e $THIS_JOB_TMP_DIR -l ga -j y -terse -P megx.p -R y -m sa -M $mt_admin_mail -hold_jid $FGS_JOBARRAYID,$SINA_JOBARRAYID $mg_traits_dir/mg_traits_finish.sh $THIS_JOB_TMP_DIR

## permantly copying local cluster node files to NFS
#cp ${job_out_dir}/* $THIS_JOB_TMP_DIR

END_TIME=`date +%s.%N`
RUN_TIME=`echo $END_TIME-$START_TIME | bc -l`


# update mg_traits_jobs
echo "UPDATE mg_traits.mg_traits_jobs SET total_run_time = total_run_time + $RUN_TIME, time_protocol = time_protocol || ('$JOB_ID', 'mg_traits', $RUN_TIME)::mg_traits.time_log_entry WHERE sample_label = '$SAMPLE_LABEL' AND id = '$MG_ID';" | psql -U $target_db_user -h $target_db_host -p $target_db_port -d $target_db_name
