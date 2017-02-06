#!/bin/bash
#$ -j y
#$ -cwd

set -x
set -o pipefail

#####################################
## define variables 
#####################################
START_TIME=$( date +%s.%N )

source ./00-preprocess_env

SAMPLE_LABEL="${1}"

##### load modules #####
source /bioinf/software/etc/profile.modules
module load pear/0.9
module load bbmap/35.14
##### load modules #####

# pear
SOFTWARE_FOLDER="/bioinf/software/"
pear="${SOFTWARE_FOLDER}/pear/pear-0.9.8/bin/pear"
# bbduk
bbduk="${SOFTWARE_FOLDER}/bbmap/bbmap-35.14/bbduk.sh"
# vsearch
MGTRAITS_FOLDER="/bioinf/projects/megx/mg-traits/mg-traits_github_floder"
vsearch_runner="${MGTRAITS_FOLDER}/modules/vsearch_runner.sh"

# email
mt_admin_mail=epereira@mpi-bremen.de

# declare AFILE="/bioinf/projects/megx/TARA/rDNAs/compute/input/assem-file-name2url.txt"
declare AFILE="${MGTRAITS_FOLDER}/assem-file-name2url.txt"

######################################
# Functions
######################################

FUNCTIONS="${MGTRAITS_FOLDER}/config_files/config.bash"

if [[ -r "${FUNCTIONS}" ]]; then
  source "${FUNCTIONS}"
else
  mail -s "mg_traits:${JOB_ID} failed" "${mt_admin_mail}" <<EOF
"No ${FUNCTIONS} file"
EOF
  exit 1
fi

#####################################################
# Map and link the TARA samples name with their file.
#####################################################

declare -r MINOV='10'
RFILES=$(grep "${SAMPLE_LABEL}" "${AFILE}")
NRFILE=$(echo "${RFILES}" | wc -l) #How many files do we have

echo "${RFILES}" | \
    cut -f 2 -d ' ' | \
    while read LINE
    do
        N=$(basename "${LINE}")
        #ln -s "/bioinf/projects/megx/TARA/assemblies/FASTQ/${N}" .
        ln -s "/bioinf/home/epereira/workspace/mg-traits/tara_prepross/data/\
toyFASTQ/${N}" .
    done


RFILES=$( echo "${RFILES}" | sed 's/TARA[^\ ]\+ //g');
echo "UPDATE mg_traits.mg_traits_jobs SET mg_url = '${RFILES}' \
WHERE sample_label = '${SAMPLE_LABEL}' AND id = '${MG_ID}';" | \
psql -U "${target_db_user}" -h "${target_db_host}" -p "${target_db_port}" -d
"${target_db_name}"

######################################################    
# Combine all TARA files from the same sample name.
######################################################
R1_raw_all=R1_raw_all.fastq.gz
R2_raw_all=R2_raw_all.fastq.gz

# cat > remote_run.bash << EOF
# cat "${THIS_JOB_TMP_DIR}"/*_1.fastq.gz > "${THIS_JOB_TMP_DIR}"/"${R1_raw_all}"
# cat "${THIS_JOB_TMP_DIR}"/*_2.fastq.gz > "${THIS_JOB_TMP_DIR}"/"${R2_raw_all}"
# EOF

cat "${THIS_JOB_TMP_DIR}"/*_1.fastq.gz > "${THIS_JOB_TMP_DIR}"/"${R1_raw_all}"
cat "${THIS_JOB_TMP_DIR}"/*_2.fastq.gz > "${THIS_JOB_TMP_DIR}"/"${R2_raw_all}"

# ssh arcturus 'bash -s' < remote_run.bash

# rm remote_run.bash
rm *_1.fastq.gz #Remove original file links
rm *_2.fastq.gz 

########################################################
# Remove adapters
########################################################
PE1_rmadapt="R1_rmadapt.fastq"
PE2_rmadapt="R2_rmadapt.fastq"
SE_rmadapt="SR_rmadapt.fastq"
TARAADAP="/bioinf/software/bbmap/bbmap-35.14/resources/tara.fa.gz"

bbduk.sh \
in="${R1_raw_all}" \
in2="${R2_raw_all}" \
out1="${PE1_rmadapt}" \
out2="${PE2_rmadapt}" \
outs="${SE_rmadapt}" \
qin=33 \
minlen=45 \
ktrim=r \
k=25 \
mink=11 \
ref="${TARAADAP}" \
hdist=1 \
tbo \
tpe \
maxns=0 \
threads="${NSLOTS}"

# ${bbduk} in="${R1_raw_all}" in2="${R2_raw_all}" out1="${PE1_rmadapt}" \
# out2="${PE2_rmadapt}"  outs="${SE_rmadapt}" qin=33 minlen=45 ktrim=r k=25 \
# mink=11 ref="${TARAADAP}" hdist=1 tbo tpe maxns=0 threads="${NSLOTS}"

if [[ "$?" -ne "0" ]]; then 
  email_comm "remove adaptares bbduk.sh failed"
  db_error_comm "remove adaptares bbduk.sh failed"
  cleanup && exit 2
fi

rm R1_raw_all.fastq.gz #Remove raw data
rm R2_raw_all.fastq.gz 

#######################################################
# Define memory usage. 
#######################################################
# We use one third of the memory available
declare MEM=$(free -g | grep Mem | awk '{printf "%dG",$2/3}')

echo "${MEM}"

########################################################
# Run PEAR to merge the data
########################################################
pear \
-j "${NSLOTS}" \
-y "${MEM}" \
-v "${MINOV}" \
-f "${PE1_rmadapt}" \
-r "${PE2_rmadapt}" \
-o "pear"

# ${pear} -j "${NSLOTS}" -y "${MEM}" -v "${MINOV}" -f "${PE1_rmadapt}" -r
# "${PE2_rmadapt}" -o "pear"

if [[ "$?" -ne "0" ]]; then 
  email_comm "pear merge sequences failed"
  db_error_comm "pear merge sequences failed"
  cleanup && exit 2
fi

NDISCARD=$(echo $(wc *.discarded.fastq -l | cut -f1 -d" " ) / 4 | bc)
echo "${NDISCARD}"

rm "${PE1_rmadapt}" "${PE2_rmadapt}" # Remove the unmerged reads and discarded
                                     # data
[[ -s pear.discarded.fastq ]] && rm *discarded.fastq

#########################################################
# Quality trim non merged
#########################################################

if [[ -s "pear.unassembled.forward.fastq" ]]; then
  PE1_qc_nonmerged="R1_qc_nonmerged.fasta"
  PE2_qc_nonmerged="R2_qc_nonmerged.fasta"

  bbduk.sh \
  in="pear.unassembled.forward.fastq" \
  in2="pear.unassembled.reverse.fastq" \
  out1="${PE1_qc_nonmerged}" \
  out2="${PE2_qc_nonmerged}" \
  outs="tmp.SR.fasta" \
  qin=33 minlen=45 qtrim=rl \
  trimq=20 \
  ktrim=r \
  k=25 \
  mink=11 \
  ref="${TARAADAP}" \
  hdist=1 \
  tbo \
  tpe \
  maxns=0 \
  threads="${NSLOTS}"
  
#   ${bbduk}  in="pear.unassembled.forward.fastq" in2="pear.unassembled.reverse.fastq" \
#   out1="${PE1_qc_nonmerged}" out2="${PE2_qc_nonmerged}" outs="tmp.SR.fasta" qin=33 minlen=45 qtrim=rl \
#   trimq=20 ktrim=r k=25 mink=11 ref="${TARAADAP}" hdist=1 tbo tpe maxns=0 threads="${NSLOTS}"

  
  if [[ "$?" -ne "0" ]]; then  
    email_comm "bbduk.sh quality trim non merged failed"
    db_error_comm "bbduk.sh quality trim non merged failed"
    cleanup && exit 2
  fi  
 
  NUNMERGED=$(echo $(wc "pear.unassembled.forward.fastq" -l | cut -f1 -d" " ) / 4 | bc)
  echo "${NUNMERGED}"
  rm pear.unassembled*.fastq

fi

#########################################################
# Quality trim merged + SE_rmadapt
#########################################################

if [[ -s "pear.assembled.fastq" || -s "${SE_rmadapt}" ]]; then

  NMERGED=$(echo $(wc "pear.assembled.fastq" -l | cut -f1 -d" " ) / 4 | bc)
  echo "${NMERGED}"

  cat *assembled.fastq >> "${SE_rmadapt}"
  SR_qc="SR.qc.fasta"
  
  bbduk.sh \
  in="${SE_rmadapt}" \
  out1="${SR_qc}" \
  qin=33 \
  minlen=45 \
  qtrim=rl \
  trimq=20 \
  ktrim=r \
  k=25 \
  mink=11 \
  ref="${TARAADAP}" \
  hdist=1 \
  tbo \
  tpe \
  maxns=0 \
  threads="${NSLOTS}"


# ${bbduk} in="${SE_rmadapt}" out1="${SR_qc}" qin=33 minlen=45 qtrim=rl trimq=20
# ktrim=r k=25 mink=11 ref="${TARAADAP}" hdist=1 tbo tpe maxns=0
# threads="${NSLOTS}"

  if [[ "$?" -ne "0" ]]; then 
    email_comm "bbduk.sh quality trim merged + SE failed"
    db_error_comm "bbduk.sh quality trim merged + SE failed"
    cleanup && exit 2
  fi   
fi


##########################################################
# Concatenate all results
##########################################################

cat "${PE1_qc_nonmerged}" "${PE2_qc_nonmerged}" "tmp.SR.fasta" >> "${SR_qc}"

rm \
"tmp.SR.fasta" \
"${SE_rmadapt}" \
"${PE1_qc_nonmerged}" \
"${PE2_qc_nonmerged}" \
*assembled.fastq \
pear.discarded.fastq

#####################################################################
# Remove duplicates
#####################################################################

RAW_FASTA=01-raw-fasta  # Same name as PROCESS_FASTA in config.bash. It is
                        # defined here so it can be run independelty.

SE_log=01-raw_SR_vsearch.log


#-l
# h="mg9.mpi-bremen.de|mg10.mpi-bremen.de|\
# mg11.mpi-bremen.de|mg12.mpi-bremen.de|\
# mg13.mpi-bremen.de|mg14.mpi-bremen.de|\
# mg15.mpi-bremen.de|mg16.mpi-bremen.de,\
# exclusive"

qsub \
-sync y \
-pe threaded "${NSLOTS}" \
"${vsearch_runner}" \
"${SR_qc}" \
"${RAW_FASTA}" \
"${SE_log}"

 if [[ "$?" -ne "0" ]]; then  
    email_comm "vsearch failed"
    db_error_comm  "vsearch failed"
    cleanup && exit 2
  fi

rm "${SR_qc}"
END_TIME=$( date +%s.%N )
RUN_TIME=$(echo "${END_TIME}" - "${START_TIME}" | bc -l)

#########################################################################
# time registration
#########################################################################


#  echo "UPDATE epereira.preprocess_jobs SET total_run_time = total_run_time \
# + "${RUN_TIME}", time_protocol = time_protocol \
# || ('${JOB_ID}', 'mg_traits', ${RUN_TIME})::mg_traits.time_log_entry WHERE
# sample_label = '${SAMPLE_LABEL}' AND job_id = '${JOB_ID}';" \
# | psql -U "${target_db_user}" -h "${target_db_host}" -p "${target_db_port}" \
# -d "${target_db_name}"
