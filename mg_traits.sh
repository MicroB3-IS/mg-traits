#!/bin/bash

# # $ -l mg_traits=1

# set +x
# set -o pipefail

START_TIME=$(date +%s.%N)
MG_TRAITS_DIR="$(dirname "$(readlink -f "$0")")"

# in case we do not get JOB_ID from an SGE like environment
if [[ -z "${JOB_ID}" ]]; then
  #JOB_ID=$(date +%s.%N | sha256sum | base64 | head -c 10 )
   JOB_ID="${RANDOM}"
fi

################################################################################
# 0 - Load general configuration
################################################################################

CONFIG="${MG_TRAITS_DIR}/conf/mg-traits.conf"
if [[ -r "${CONFIG}" ]]; then
  source "${CONFIG}"
else
  mail -s "mg_traits:${JOB_ID} failed" epereira@mpi-bremen.de << EOF
"No ${CONFIG} file"
EOF
  exit 2
fi

################################################################################
# 1 - Parse parameters
################################################################################

if [[ -z "${1}" ]]; then
  echo "no input data"  
  exit 2
fi

# urldecode input
declare INPUT=$(echo "$1" | sed -e 's/&/|/g' -e 's/\+/ /g' -e 's/%25/%/g' \
-e 's/%20/ /g' -e 's/%09/ /g' -e 's/%21/!/g' -e 's/%22/"/g' -e 's/%23/#/g' \
-e 's/%24/\$/g' -e 's/%26/\&/g' -e 's/%27/'\''/g' -e 's/%28/(/g' \
-e 's/%29/)/g' -e 's/%2a/\*/g' -e 's/%2b/+/g' -e 's/%2c/,/g' -e 's/%2d/-/g' \
-e 's/%2e/\./g' -e 's/%2f/\//g' -e 's/%3a/:/g' -e 's/%3b/;/g' -e 's/%3d/=/g' \
-e 's/%3e//g' -e 's/%3f/?/g' -e 's/%40/@/g' -e 's/%5b/\[/g' -e 's/%5c/\\/g' \
-e 's/%5d/\]/g' -e 's/%5e/\^/g' -e 's/%5f/_/g' -e 's/%60/`/g' -e 's/%7b/{/g' \
-e 's/%7c/|/g' -e 's/%7d/}/g' -e 's/%7e/~/g' -e 's/%09/      /g')

IFS="|"

declare -A params;
# parse input
for pair in ${INPUT}; do
   key=${pair%%=*};
   key=${key,,};
   val=${pair#*=}
   #echo "key=$key and value=$val"
   params[$key]=$val
   #echo "${params[$key]}"
done
unset IFS

keys2check="sample_label mg_url customer sample_environment time_submitted
make_public keep_data id"

for i in ${keys2check}; do
  if [[ -n ${params["${i}"]} ]]; then
    VAR=$( echo "${i}" | tr '[:lower:]' '[:upper:]' )
    declare  "${VAR}"=${params["${i}"]};
  else
    mail -s "mg_traits:${JOB_ID} failed" "${mt_admin_mail}" << EOF
"Mandatory ${i} not defined"
EOF
    exit 2
  fi
done

################################################################################
# 2 - Set mg traits job specific variables
################################################################################
THIS_JOB_TMP_DIR=$(readlink -m "${RUNNING_JOBS_DIR}/job-${JOB_ID}")
THIS_JOB_TMP_DIR_DATA="${THIS_JOB_TMP_DIR}/data/"
SINA_LOG_DIR="${THIS_JOB_TMP_DIR}/sina_log"
FGS_JOBARRAYID="mt-${JOB_ID}-fgs"
SMRNA_JOBARRAYID="mt-${JOB_ID}-smrna"
SINA_JOBARRAYID="mt-${JOB_ID}-sina"
FINISHJOBID="mt-${JOB_ID}-finish"
TMP_VOL_FILE="/vol/tmp/megx/${JOB_NAME}.${JOB_ID}"

# names
RAW_DOWNLOAD="${THIS_JOB_TMP_DIR}/01-raw-download"
RAW_FASTA="${THIS_JOB_TMP_DIR}/01-raw-fasta"
FASTA_BAD="${THIS_JOB_TMP_DIR}/01-bad-fasta"
UNIQUE="${THIS_JOB_TMP_DIR}/02-unique-sequences-fasta"
UNIQUE_LOG="${THIS_JOB_TMP_DIR}/02-unique-sequences.log"
CLUST95="${THIS_JOB_TMP_DIR}/03-clustered-sequences"
CLUST95_LOG="${THIS_JOB_TMP_DIR}/${CLUST95}.log"
CLUST95_CLSTR="${THIS_JOB_TMP_DIR}/${CLUST95}.clstr"
INFOSEQ_TMPFILE="${THIS_JOB_TMP_DIR}/04-stats-tempfile"
INFOSEQ_MGSTATS="${THIS_JOB_TMP_DIR}/04-mg_stats"
GENEAA="${THIS_JOB_TMP_DIR}/05-gene-aa-seqs"
GENENT="${THIS_JOB_TMP_DIR}/05-gene-nt-seqs"
GENERNA="${THIS_JOB_TMP_DIR}/06-gene-rna-seqs"
PFAMDB="${THIS_JOB_TMP_DIR}/07-pfamdb"
PFAMFILERAW="${THIS_JOB_TMP_DIR}/07-pfam-raw"
PFAMFILERAW_LOG="${THIS_JOB_TMP_DIR}/07-pfam-raw.log"
PFAMFILE="${THIS_JOB_TMP_DIR}/07-pfam"
FUNCTIONALTABLE="${THIS_JOB_TMP_DIR}/07-pfam-functional-table"
CODONCUSP="${THIS_JOB_TMP_DIR}/07-codon.cusp"
TFPERC="${THIS_JOB_TMP_DIR}/07-tfperc"
CLPERC="${THIS_JOB_TMP_DIR}/07-clperc"
AA_TABLE="${THIS_JOB_TMP_DIR}/08-aa-table"
CODON_TABLE="${THIS_JOB_TMP_DIR}/08-codon-table"
ABRATIO_FILE="${THIS_JOB_TMP_DIR}/08-ab-ratio"
NUC_FREQS="${THIS_JOB_TMP_DIR}/08-nuc-freqs"
DINUC_FREQS="${THIS_JOB_TMP_DIR}/08-dinuc-freqs"
ODDS_TABLE="${THIS_JOB_TMP_DIR}/08-odds-table"
SLV_TAX_RAW="${THIS_JOB_TMP_DIR}/09-slv-tax-raw"
SLV_TAX_ORDER="${THIS_JOB_TMP_DIR}/09-slv-tax-order"
PCA_CODON_FILE="${THIS_JOB_TMP_DIR}/10-pca-codon"
PCA_AA_FILE="${THIS_JOB_TMP_DIR}/10-pca-aa"
PCA_DINUC_FILE="${THIS_JOB_TMP_DIR}/10-pca-dinuc"
PCA_FUNCTIONAL_FILE="${THIS_JOB_TMP_DIR}/10-pca-functional"
PCA_TAXONOMY_FILE="${THIS_JOB_TMP_DIR}/10-pca-taxonomy"
PCA_CODON_DB="${THIS_JOB_TMP_DIR}/10-pca-codon-db"
PCA_AA_DB="${THIS_JOB_TMP_DIR}/10-pca-aa-db"
PCA_DINUC_DB="${THIS_JOB_TMP_DIR}/10-pca-dinuc-db"
PCA_FUNCTIONAL_DB="${THIS_JOB_TMP_DIR}/10-pca-functional-db"
PCA_TAXONOMY_DB="${THIS_JOB_TMP_DIR}/10-pca-taxonomy-db"


################################################################################
# 3 - Load functions: Only after all the variables have been defined
################################################################################

FUNCTIONS="${MG_TRAITS_DIR}/conf/mg-traits.functions.sh"

if [[ -r "${FUNCTIONS}" ]]; then
  source "${FUNCTIONS}"
else
  mail -s "mg_traits:${JOB_ID} failed" "${mt_admin_mail}" <<EOF
"No ${FUNCTIONS} file"
EOF
  exit 2
fi

################################################################################
# 4 - Check database connection by setting starting time
################################################################################
if [[ -n "${target_db_name}" ]]; then
  DB_RESULT=$( \
    echo "UPDATE mg_traits.mg_traits_jobs SET time_started = now(), \
          job_id = '${JOB_ID}', cluster_node = '${HOSTNAME}' \
          WHERE sample_label = '${SAMPLE_LABEL}' \
            AND id = ${ID};" \
         | psql -U "${target_db_user}" -h "${target_db_host}" \
                -p "${target_db_port}" -d "${target_db_name}" \
  )
  if [[ "$?" -ne "0" ]]; then
    error_exit "Cannot connect to database. Output:${DB_RESULT}" 1; exit
  fi

  if [[ "${DB_RESULT}" != "UPDATE 1" ]]; then
    error_exit "sample name ${SAMPLE_LABEL} is not in database \
Result:${DB_RESULT}" 1; exit
  fi
fi

################################################################################
# 5 - Create job directory
################################################################################

mkdir "${THIS_JOB_TMP_DIR}"

RETURN_CODE="$?"
if [[ "${RETURN_CODE}" -ne "0" ]]; then
  db_error_comm "Could not access job temp dir ${THIS_JOB_TMP_DIR}. \
  RETURN_CODE = ${RETURN_CODE}"
  error_exit  "Could not access job temp dir ${THIS_JOB_TMP_DIR}. \
  RETURN_CODE = ${RETURN_CODE}" 1; exit
fi


################################################################################
# 6 - Check for utilities, files and directories
################################################################################

ERROR_MESSAGE=$(\
  check_required_readable_directories \
  "${MG_TRAITS_DIR}/conf" \
  "${MG_TRAITS_DIR}/bin";

  check_required_writable_directories \
  "${temp_dir:?}" \
  "${RUNNING_JOBS_DIR:?}" \
  "${FAILED_JOBS_DIR:?}" \
  "${job_out_dir:?}";

  check_required_programs \
  "${vsearch}" \
  "${uproc}" \
  "${r_interpreter:?}" \
  "${sina:?}" \
  "${frag_gene_scan:?}" \
  "${sortmerna:?}";
)

if [[ "${ERROR_MESSAGE}" ]]; then
  db_error_comm "check utilities, files and dirs failed: ${ERROR_MESSAGE}"
  error_exit "check utilities, files and dirs failed: ${ERROR_MESSAGE}" 2; exit
fi

################################################################################
# 7 - check if it already exist on our DB
################################################################################

if [[ -n "${target_db_name}" ]]; then

  if [[ "${SAMPLE_LABEL}" != "test_label" ]]; then
    URLDB=$(
           psql -t -U "${target_db_user}" -h "${target_db_host}" \
                   -p "${target_db_port}" -d "${target_db_name}" -c \
           "SELECT count(*) FROM mg_traits.mg_traits_jobs where \
           mg_url = '${MG_URL}' AND sample_label NOT ILIKE 'test_label \
           AND return_code = 0'"
          )

  if [[ "${URLDB}" -gt 1 ]]; then
    db_error_comm "The URL ${MG_URL} has been already succesfully crunched. If
the file is different please change the file name."
    error_exit "The URL ${MG_URL} has been already succesfully crunched. If
the
file is different please change the file name" 1;
    fi
  fi

fi

################################################################################
# 8 -  Download file
################################################################################

"${MG_TRAITS_DIR}"/bin/file_downloader.sh --config "${CONFIG}" \
--dout "${RAW_DOWNLOAD}" \
--url "${MG_URL}" \
--fout "${RAW_FASTA}"

RETURN_CODE="$?"
if [[ "${RETURN_CODE}" != "0" ]]; then
  db_error_comm "Downlaod failed: url: ${MG_URL}. RETURN_CODE = ${RETURN_CODE}"
  error_exit "Downlaod failed: url: ${MG_URL}. RETURN_CODE = ${RETURN_CODE}" 1;
  exit
fi

################################################################################
# 9 -  Validate file
################################################################################

${MG_TRAITS_DIR}/bin/fasta_validator.sh --config "${CONFIG}" \
--seqtype dna \
--fastafile "${RAW_FASTA}";

RETURN_CODE="$?"
if [[ "${RETURN_CODE}" != "0" ]]; then
  db_error_comm "Not valid fasta file. RETURN_CODE = ${RETURN_CODE}"
  error_exit "Not valid fasta file. RETURN_CODE = ${RETURN_CODE}" 1; exit
fi

################################################################################
# 7 - Check for duplicates
################################################################################

${MG_TRAITS_DIR}/bin/deduplicator.sh --config "${CONFIG}" \
--input "${RAW_FASTA}" \
--output "${UNIQUE}" \
--log "${UNIQUE_LOG}"

RETURN_CODE="$?"
if [[ "${RETURN_CODE}" != "0" ]]; then
  db_error_comm "Deduplicator failed. See ${UNIQUE_LOG}. Error ${RETURN_CODE}"
  error_exit "Deduplicator failed. ${UNIQUE_LOG}. Error ${RETURN_CODE}" 1;
  exit
fi

NUM_READS=$( egrep -o  "in\ [0-9]+\ seqs"  "${UNIQUE_LOG}" | \
awk '{ print $2}'\ )


################################################################################
# 8 - Calculate sequence statistics
################################################################################

# infoseq
infoseq "${UNIQUE}" -only -pgc -length -noheading -auto > "${INFOSEQ_TMPFILE}"

if [[ "$?" -ne "0" ]]; then  
  db_error_comm "Infoseq cannot calculate sequence statistics"
  error_exit "Infoseq cannot calculate sequence statistics" 1; exit
fi

# seq stats
${MG_TRAITS_DIR}/bin/seq_basic_stats.sh --config "${CONFIG}" \
--input "${INFOSEQ_TMPFILE}" \
--output "${INFOSEQ_MGSTATS}"

RETURN_CODE="$?"

if [[ "${RETURN_CODE}" -ne "0" ]]; then
  db_error_comm "Rscript ${seq_stats} cannot process sequence statistics"
  error_exit "Rscript ${seq_stats} cannot process sequence statistics" 1; exit
fi

NUM_BASES=$(cut -f1 "${INFOSEQ_MGSTATS}" -d ' '); 
GC=$(cut -f2 "${INFOSEQ_MGSTATS}" -d ' '); 
VARGC=$(cut -f3 "${INFOSEQ_MGSTATS}" -d ' ')
printf "Number of bases: %d\nGC content: %f\nGC variance: %f\n" "${NUM_BASES}"\
 "${GC}" "${VARGC}"


################################################################################
# Split original
################################################################################

${MG_TRAITS_DIR}/bin/fasta_splitter.sh --config "${CONFIG}" \
--input "${RAW_FASTA}" \
--prefix 05-part \
--outdir "${THIS_JOB_TMP_DIR}"

RETURN_CODE="$?"
if [[ "${RETURN_CODE}" != "0" ]]; then
  db_error_comm "fasta_splitter failed. RETURN_CODE = ${RETURN_CODE}"
  error_exit "fasta_splitter failed. RETURN_CODE = ${RETURN_CODE}" 1; exit
fi

################################################################################
# 1 - run fgs
################################################################################

NFILES=$(find "${THIS_JOB_TMP_DIR}" -name "05-part*.fasta" | wc -l)

qsub -j y -o "${THIS_JOB_TMP_DIR}" -t 1-"${NFILES}" \
-pe threaded "${NSLOTS}" -N "${FGS_JOBARRAYID}" \
${MG_TRAITS_DIR}/bin/fgs_runner.sh --config "${CONFIG}" \
--inputdir "${THIS_JOB_TMP_DIR}" \
--prefix 05-part \
--outdir "${THIS_JOB_TMP_DIR}"

RETURN_CODE=$?
if [[ "${RETURN_CODE}" -ne "0" ]]; then
  db_error_comm "qsub fgs_runner.sh failed. RETURN_CODE = ${RETURN_CODE}"
  error_exit "qsub fgs_runner.sh failed. RETURN_CODE = ${RETURN_CODE}" 1; exit
fi

################################################################################
## 2 - run sortmerna
################################################################################

# redefine evalue for sormerna
EVALUE=$( echo 1 / $(find "${THIS_JOB_TMP_DIR}" -name "05-part-[0-9]*.fasta" |\
wc -l) | bc -l)

qsub -sync y -j y -o "${THIS_JOB_TMP_DIR}" -t 1-"${NFILES}" \
-pe threaded "${NSLOTS}" -N "${SMRNA_JOBARRAYID}" \
${MG_TRAITS_DIR}/bin/sortmerna_runner.sh --config "${CONFIG}" \
--inputdir "${THIS_JOB_TMP_DIR}" \
--inprefix 05-part \
--outprefix 06-part \
--outdir "${THIS_JOB_TMP_DIR}" \
--evalue "${EVALUE}" > sortmerna_runner.log

RETURN_CODE="$?"
if [[ "${RETURN_CODE}" -ne "0" ]]; then
  db_error_comm "sortmerna failed. RETURN_CODE = ${RETURN_CODE}"
  error_exit db_error_comm "sortmerna failed. RETURN_CODE = ${RETURN_CODE}" 1;
  exit
fi

################################################################################
# 3 - run SINA
################################################################################

NUM_RNA=$(egrep -c ">" <(cat "${THIS_JOB_TMP_DIR}"/06-part-*.fasta) )

if [[ "${NUM_RNA}" -eq "0" ]]; then
  db_error_comm "no RNA sequence found by sortmerna"
  error_exit "no RNA sequence found by sortmerna" 1: exit
fi

echo "${SINA_JOBARRAYID}"
qsub -j y -o "${THIS_JOB_TMP_DIR}" -t 1-"${NFILES}" -pe threaded "${NSLOTS}" \
-hold_jid "${SMRNA_JOBARRAYID}" -N "${SINA_JOBARRAYID}" \
${MG_TRAITS_DIR}/bin/sina_runner.sh --config "${CONFIG}" \
--inputdir "${THIS_JOB_TMP_DIR}" \
--prefix 06-part \
--outdir "${THIS_JOB_TMP_DIR}"

RETURN_CODE=$?
if [[ "${RETURN_CODE}" -ne "0" ]]; then
  db_error_comm "sina failed. RETURN_CODE = ${RETURN_CODE}"
  error_exit "sina failed. RETURN_CODE = ${RETURN_CODE}" 1; exit
fi

################################################################################
# 1 - Check results: fgs
################################################################################

qsub -sync y -j y -o "${THIS_JOB_TMP_DIR}" -pe threaded "${NSLOTS}" \
-hold_jid "${FGS_JOBARRAYID}","${SINA_JOBARRAYID}" \
${MG_TRAITS_DIR}/bin/check_point.sh --config "${CONFIG}" \
--inputdir "${THIS_JOB_TMP_DIR}" \
--prefix1 05-part \
--prefix2 06-part

RETURN_CODE="$?"
if [[ "${RETURN_CODE}" -ne "0" ]]; then
  db_error_comm "Check point failed. RETURN_CODE = ${RETURN_CODE}"
  error_exit "Check point failed. RETURN_CODE = ${RETURN_CODE}" 1; exit
fi

################################################################################
# 2 - Concatenate CDS
################################################################################

cat "${THIS_JOB_TMP_DIR}"/05-part*.genes.faa > "${GENEAA}"
cat "${THIS_JOB_TMP_DIR}"/05-part*.genes.ffn > "${GENENT}"

################################################################################
# 4 - Functional annotation
################################################################################

NUM_GENES=$( grep -c '>' "${GENENT}" )

if [[ "${NUM_GENES}" -eq "0" ]]; then
  db_error_comm "No genes found by fgs. NUM_GENES = ${NUM_GENES}"
  error_exit  "No genes found by fgs. NUM_GENES = ${NUM_GENES}" 1; exit
fi

${MG_TRAITS_DIR}/bin/uproc_runner.sh --config "${CONFIG}" \
--input "${GENENT}" \
--output "${PFAMFILERAW}" \
--log "${PFAMFILERAW_LOG}"

RETURN_CODE="$?"
if [[ "${RETURN_CODE}" != "0" ]]; then
  db_error_comm "uproc_runner.sh failed. RETURN_CODE = ${RETURN_CODE}"
  error_exit "uproc_runner.sh failed. RETURN_CODE = ${RETURN_CODE}" 1; exit
fi

cut -f2,7 -d ',' "${PFAMFILERAW}" > "${PFAMFILE}"

################################################################################
# 5 - Create functional table
################################################################################

${MG_TRAITS_DIR}/bin/create_fun_table.sh --config "${CONFIG}" \
--num_genes "${NUM_GENES}" \
--input "${PFAMFILE}" \
--fun_table "${FUNCTIONALTABLE}" \
--tfperc "${TFPERC}" \
--clperc "${CLPERC}"

RETURN_CODE="$?"
if [[ "${RETURN_CODE}" != "0" ]]; then
  db_error_comm "create_fun_table.sh failed. RETURN_CODE = ${RETURN_CODE}"
  error_exit "create_fun_table failed. RETURN_CODE = ${RETURN_CODE}" 1; exit
fi

sort -k1 "${FUNCTIONALTABLE}" | sed -e 's/\t/=>/g' | tr '\n' ',' | \
sed -e 's/^/\"/' -e 's/,$/\"/' > "${PFAMDB}"

################################################################################
# 6 - Compute codon usage
################################################################################

cusp --auto -stdout "${GENENT}" |awk '{if ($0 !~ "*" && $0 !~ /[:alphanum:]/ \
&& $0 !~ /^$/){ print $1,$2,$5}}' > "${CODONCUSP}"

RETURN_CODE="$?"
if [[ "${RETURN_CODE}" -ne "0" ]]; then
  db_error_comm "cusp failed. RETURN_CODE = ${RETURN_CODE}"
  error_exit "cusp failed. RETURN_CODE = ${RETURN_CODE}" 1; exit
fi

################################################################################
# 7 - Create codon and aa usage table
################################################################################

${MG_TRAITS_DIR}/bin/create_codon_aa_table.sh --config "${CONFIG}" \
--input "${CODONCUSP}" \
--aa_table "${AA_TABLE}" \
--codon_table "${CODON_TABLE}" \
--ab_ratio "${ABRATIO_FILE}"

RETURN_CODE="$?"
if [[ "${RETURN_CODE}" -ne "0" ]]; then
  db_error_comm "create_codon_aa_table failed. RETURN_CODE = ${RETURN_CODE}"
  error_exit "create_codon_aa_table failed. RETURN_CODE = ${RETURN_CODE}" 1;
  exit
fi

ABRATIO=$(cat "${ABRATIO_FILE}" )
PERCTF=$(cat "${TFPERC}" )
PERCCL=$(cat "${CLPERC}" )

################################################################################
# 8 - Words composition: nuc frec
################################################################################

compseq --auto -stdout -word 1 "${RAW_FASTA}" | awk '{if (NF == 5 && \
$0 ~ /^A|T|C|G/ && $0 !~ /[:alphanum:]/ ) {print $1,$2,$3}}' > "${NUC_FREQS}"

RETURN_CODE="$?"
if [[ "${RETURN_CODE}" -ne "0" ]]; then
  db_error_comm "Compseq for nucleotide freqs failed. \
  RETURN_CODE = ${RETURN_CODE}"
  error_exit "Compseq for nucleotide freqs failed. \
  RETURN_CODE = ${RETURN_CODE}" 1; exit
fi

################################################################################
# 9 - Words composition: dinuc frec
################################################################################

compseq --auto -stdout -word 2 "${RAW_FASTA}" |awk '{if (NF == 5 && \
$0 ~ /^A|T|C|G/ && $0 !~ /[:alphanum:]/ ) {print $1,$2,$3}}' > "${DINUC_FREQS}"

RETURN_CODE="$?"
if [[ "${RETURN_CODE}" -ne "0" ]]; then
  db_error_comm "compseq for dinucleotide frec failed. \
  RETURN_CODE = ${RETURN_CODE}"
  error_exit "compseq for dinucleotide frec failed. \
  RETURN_CODE = ${RETURN_CODE}" 1; exit
fi

################################################################################
# 10 -  Create nucleotide table
################################################################################

${MG_TRAITS_DIR}/bin/create_nuc_table.sh --config "${CONFIG}" \
--nuc_freqs "${NUC_FREQS}" \
--dinuc_freqs "${DINUC_FREQS}" \
--odds_table "${ODDS_TABLE}"

RETURN_CODE="$?"
if [[ "${RETURN_CODE}" -ne "0" ]]; then
  db_error_comm "create_nuc_table failed. RETURN_CODE = ${RETURN_CODE}"
  error_exit "create_nuc_table failed. RETURN_CODE = ${RETURN_CODE}" 1; exit
fi

################################################################################
# 11 - Getting taxonomic classification from SINA output
################################################################################

cat "${THIS_JOB_TMP_DIR}"/06-part-*.classify.fasta > "${GENERNA}"

${MG_TRAITS_DIR}/bin/taxa_parser.sh --config "${CONFIG}" \
--input "${GENERNA}" \
--slv_raw "${SLV_TAX_RAW}" \
--slv_order "${SLV_TAX_ORDER}"

RETURN_CODE="$?"
if [[ "${RETURN_CODE}" -ne "0" ]]; then
  db_error_comm "Taxa parsing failed. RETURN_CODE = ${RETURN_CODE}"
  error_exit "Taxa parsing failed. RETURN_CODE =  ${RETURN_CODE}" 1; exit
fi

################################################################################
# 14 - load mg_traits_codon
################################################################################

db_table_load1 "${CODON_TABLE}" mg_traits_codon

RETURN_CODE="$?"
if [[ "$?" -ne "0" ]]; then
  db_error_comm "Error inserting CODON results. RETURN_CODE = ${RETURN_CODE}"
  error_exit "Error inserting CODON results. RETURN_CODE = ${RETURN_CODE}" 1;
  exit
fi

################################################################################
# 15 - load mg_traits_aa
################################################################################

db_table_load2 "${AA_TABLE}" mg_traits_aa

RETURN_CODE="$?"
if [[ "$?" -ne "0" ]]; then
  db_error_comm "Error inserting AA results. RETURN_CODE = ${RETURN_CODE}"
  error_exit "Error inserting AA results. RETURN_CODE = ${RETURN_CODE}" 1;
  exit
fi

################################################################################
# 16 - load mg_traits_pfam
################################################################################

db_table_load1 "${PFAMDB}" mg_traits_functional

RETURN_CODE="$?"
if [[ "$?" -ne "0" ]]; then
  db_error_comm "Error inserting PFAMDB results. RETURN_CODE = ${RETURN_CODE}"
  error_exit "Error inserting PFAMDB results. RETURN_CODE = ${RETURN_CODE}" 1;
  exit
fi

################################################################################
# 17 - load mg_traits_taxonomy
################################################################################

db_table_load1 <( paste "${SLV_TAX_ORDER}" "${SLV_TAX_RAW}" ) mg_traits_taxonomy

RETURN_CODE="$?"
if [[ "$?" -ne "0" ]]; then
  db_error_comm "Error inserting TAXA results. RETURN_CODE = ${RETURN_CODE}"
  error_exit "Error inserting TAXA results. RETURN_CODE = ${RETURN_CODE}" 1;
  exit
fi

################################################################################
# 18 - load mg_traits_dinuc
################################################################################

db_table_load2 "${ODDS_TABLE}" mg_traits_dinuc

RETURN_CODE="$?"
if [[ "$?" -ne "0" ]]; then
  db_error_comm "Error inserting DINUC results. RETURN_CODE = ${RETURN_CODE}"
  error_exit "Error inserting DINUC results. RETURN_CODE = ${RETURN_CODE}" 1;
  exit
fi

################################################################################
# # 19 - insert simple traits into mg_traits_results
################################################################################

echo "INSERT INTO epereira.mg_traits_results \
(sample_label, gc_content, gc_variance, num_genes, total_mb, \
num_reads, ab_ratio, perc_tf, perc_classified, id) VALUES \
('${SAMPLE_LABEL}',${GC},${VARGC}, ${NUM_GENES}, ${NUM_BASES},${NUM_READS},\
${ABRATIO}, ${PERCTF}, ${PERCCL}, ${ID});" | psql \
-U "${target_db_user}" -h "${target_db_host}" \
-p "${target_db_port}" -d "${target_db_name}"

RETURN_CODE="$?"
if [[ "${RETURN_CODE}" -ne "0" ]]; then
  db_error_comm "Error inserting SIMPLE TRAITS results. \
  RETURN_CODE = ${RETURN_CODE}"
  error_exit "Error inserting SIMPLE TRAITS results. \
  RETURN_CODE = ${RETURN_CODE}" 1; exit
fi

################################################################################
# 20 - PCAs. We calculate the PCAs if we have more than 30 metagenomes in the
# database. For functional and taxonomy we apply hellinger transformation to
# the data before PCA
################################################################################

# Get existing data for CODON

NUMROWS=$( echo "SELECT COUNT(C.*) FROM mg_traits.mg_traits_codon C INNER JOIN \
mg_traits.mg_traits_jobs_public P ON C.id = P.id" | psql -t \
-U "${target_db_user}" -h "${target_db_host}" \
-p "${target_db_port}" -d "${target_db_name}" )

RETURN_CODE="$?"
if [[ "${RETURN_CODE}" -ne "0" ]]; then
  db_error_comm "Error exporting codon data. RETURN_CODE = ${RETURN_CODE}"
  error_exit "Error exporting codon data. RETURN_CODE = ${RETURN_CODE}" 1;
  exit
fi

if [[ "${NUMROWS}" -ge "30" ]]; then

  data_retriever1 mg_traits_codon "${PCA_CODON_FILE}"

  RETURN_CODE="$?"
  if [[ "${RETURN_CODE}" -ne "0" ]]; then
    db_error_comm "Error retrieving CODON results. RETURN_CODE = ${RETURN_CODE}"
    error_exit "Error retrieving CODON results. RETURN_CODE = ${RETURN_CODE}" 1;
    exit
  fi

  data_retriever1 mg_traits_aa "${PCA_AA_FILE}"

  RETURN_CODE="$?"
  if [[ "${RETURN_CODE}" -ne "0" ]]; then
    db_error_comm "Error retrieving AA results. RETURN_CODE = ${RETURN_CODE}"
    error_exit "Error retrieving AA results. RETURN_CODE = ${RETURN_CODE}" 1;
    exit
  fi

  data_retriever1 mg_traits_dinuc "${PCA_DINUC_FILE}"

  RETURN_CODE="$?"
  if [[ "${RETURN_CODE}" -ne "0" ]]; then
    db_error_comm "Error retrieving DINUC results. RETURN_CODE = ${RETURN_CODE}"
    error_exit "Error retrieving DINUC results. RETURN_CODE = ${RETURN_CODE}" 1;
    exit
  fi

  data_retriever2 functional mg_traits_functional "${PCA_FUNCTIONAL_FILE}"

  RETURN_CODE="$?"
  if [[ "${RETURN_CODE}" -ne "0" ]]; then
    db_error_comm "Error retrieving FUN results. RETURN_CODE = ${RETURN_CODE}"
    error_exit "Error retrieving FUN results. RETURN_CODE = ${RETURN_CODE}" 1;
    exit
  fi

  data_retriever2 taxonomy_order mg_traits_taxonomy "${PCA_TAXONOMY_FILE}"

  RETURN_CODE="$?"
  if [[ "${RETURN_CODE}" -ne "0" ]]; then
    db_error_comm "Error retrieving TAXA results. RETURN_CODE = ${RETURN_CODE}"
    error_exit "Error retrieving TAXA results. RETURN_CODE = ${RETURN_CODE}" 1;
    exit
  fi

  ${MG_TRAITS_DIR}/bin/pca.sh --config "${CONFIG}" \
  --table "${PCA_CODON_FILE}" \
  --output "${PCA_CODON_DB}" \
  --id "${ID}"

  RETURN_CODE="$?"
  if [[ "${RETURN_CODE}" -ne "0" ]]; then
    db_error_comm "Error in codon PCA. RETURN_CODE = ${RETURN_CODE}"
    error_exit "Error in codon PCA. RETURN_CODE = ${RETURN_CODE}" 1; exit
  fi

  ${MG_TRAITS_DIR}/bin/pca.sh --config "${CONFIG}" \
  --table "${PCA_AA_FILE}" \
  --output "${PCA_AA_DB}" \
  --id "${ID}"

  RETURN_CODE="$?"
  if [[ "${RETURN_CODE}" -ne "0" ]]; then
    db_error_comm "Error in aa PCA. RETURN_CODE = ${RETURN_CODE}"
    error_exit "Error in aa PCA. RETURN_CODE = ${RETURN_CODE}" 1; exit
  fi

  ${MG_TRAITS_DIR}/bin/pca.sh --config "${CONFIG}" \
  --table "${PCA_DINUC_FILE}" \
  --output "${PCA_DINUC_DB}" \
  --id "${ID}"

  RETURN_CODE="$?"
  if [[ "${RETURN_CODE}" -ne "0" ]]; then
    db_error_comm "Error in dinuc PCA. RETURN_CODE = ${RETURN_CODE}"
    error_exit "Error in aa dinuc. RETURN_CODE = ${RETURN_CODE}" 1; exit
  fi


  ${MG_TRAITS_DIR}/bin/pca_data_trans.sh --config "${CONFIG}" \
  --table "${PCA_FUNCTIONAL_FILE}" \
  --output "${PCA_FUNCTIONAL_DB}" \
  --id "${ID}"

  RETURN_CODE="$?"
  if [[ "${RETURN_CODE}" -ne "0" ]]; then
    db_error_comm "Error in functional PCA. RETURN_CODE = ${RETURN_CODE}"
    error_exit "Error in aa functional. RETURN_CODE = ${RETURN_CODE}" 1; exit
  fi

  ${MG_TRAITS_DIR}/bin/pca_data_trans.sh --config "${CONFIG}" \
  --table "${PCA_TAXONOMY_FILE}" \
  --output "${PCA_TAXONOMY_DB}" \
  --id "${ID}"

  RETURN_CODE="$?"
  if [[ "${RETURN_CODE}" -ne "0" ]]; then
    db_error_comm "Error in taxonomy PCA. RETURN_CODE = ${RETURN_CODE}"
    error_exit "Error in aa taxonomy. RETURN_CODE = ${RETURN_CODE}" 1; exit
  fi

  db_pca_load "${PCA_CODON_DB}"

  RETURN_CODE="$?"
  if [[ "${RETURN_CODE}" -ne "0" ]]; then
    db_error_comm "Error inserting CODON PCA. RETURN_CODE = ${RETURN_CODE}"
    error_exit "Error inserting CODON PCA. RETURN_CODE = ${RETURN_CODE}" 1; exit
  fi

  db_pca_load "${PCA_AA_DB}"

  RETURN_CODE="$?"
  if [[ "${RETURN_CODE}" -ne "0" ]]; then
    db_error_comm "Error inserting AA PCA. RETURN_CODE = ${RETURN_CODE}"
    error_exit "Error inserting AA PCA. RETURN_CODE = ${RETURN_CODE}" 1; exit
  fi

  db_pca_load "${PCA_DINUC_DB}"

  RETURN_CODE="$?"
  if [[ "${RETURN_CODE}" -ne "0" ]]; then
    db_error_comm "Error inserting DINUC PCA. RETURN_CODE = ${RETURN_CODE}"
    error_exit "Error inserting DINUC PCA. RETURN_CODE = ${RETURN_CODE}" 1; exit
  fi

  db_pca_load "${PCA_FUNCTIONAL_DB}"

  RETURN_CODE="$?"
  if [[ "${RETURN_CODE}" -ne "0" ]]; then
    db_error_comm "Error inserting FUN PCA. RETURN_CODE = ${RETURN_CODE}"
    error_exit "Error inserting FUN PCA. RETURN_CODE = ${RETURN_CODE}" 1; exit
  fi

  db_pca_load "${PCA_TAXONOMY_DB}"

  RETURN_CODE="$?"
  if [[ "${RETURN_CODE}" -ne "0" ]]; then
    db_error_comm "Error inserting TAXA PCA. RETURN_CODE = ${RETURN_CODE}"
    error_exit "Error inserting TAXA PCA. RETURN_CODE = ${RETURN_CODE}" 1; exit
  fi

fi

################################################################################
# update mg_traits_jobs
################################################################################

END_TIME=$( date +%s.%N )
RUN_TIME=$( echo "${END_TIME}"-"${START_TIME}" | bc -l )


RETURN=$( echo "UPDATE mg_traits.mg_traits_jobs SET time_finished = now(), \
return_code = 0, total_run_time = ${RUN_TIME}, \
time_protocol = time_protocol || ('${JOB_ID}', 'mg_traits_finish', \
${RUN_TIME})::mg_traits.time_log_entry \
 WHERE sample_label = '${SAMPLE_LABEL}' AND id = '${ID}';" | psql \
-U "${target_db_user}" -h "${target_db_host}" \
-p "${target_db_port}" -d "${target_db_name}" )


if [[ "${RETURN}" != "UPDATE 1" ]]; then
  db_error_comm "Error updating job table. RETURN_CODE = ${RETURN_CODE}"
  error_exit "Error updating jobs table. RETURN_CODE = ${RETURN_CODE}" 1; exit
fi


mv "${THIS_JOB_TMP_DIR}" "${FINISHED_JOBS_DIR}"

RETURN_CODE="$?"
if [[ "${RETURN_CODE}" -ne "0" ]]; then
  db_error_comm "Error moving files mv ${THIS_JOB_TMP_DIR} ${FINISHED_JOBS_DIR}"
  error_exit "Error moving files mv ${THIS_JOB_TMP_DIR} ${FINISHED_JOBS_DIR}" 1;
  exit
fi

TOTAL_TIME=$( echo "SELECT (time_finished - time_started) FROM \
mg_traits.mg_traits_jobs WHERE sample_label = '${SAMPLE_LABEL}' \
AND id = '${ID}';" | psql -t \
-U "${target_db_user}" -h "${target_db_host}" \
-p "${target_db_port}" -d "${target_db_name}" | tr -d ' ')


RETURN_CODE="$?"
if [[ "${RETURN_CODE}" -eq "0" ]]; then
  mail -s "mg_traits:Analysis of ${SAMPLE_LABEL} with job id ${JOB_ID} done." \
"${mt_admin_mail}" <<EOF
Analysis of ${SAMPLE_LABEL} done in ${TOTAL_TIME}.
EOF
  exit 0
fi

# echo "UPDATE mg_traits.mg_traits_jobs SET total_run_time = total_run_time + \
# ${RUN_TIME}, time_protocol = time_protocol || ('${JOB_ID}', 'mg_traits', \
# ${RUN_TIME})::mg_traits.time_log_entry WHERE \
# sample_label = '${SAMPLE_LABEL}' AND id = '${MG_ID}';" \
# | psql -U "${target_db_user}" -h "${target_db_host}" -p "${target_db_port}" \
# -d "${target_db_name}"




