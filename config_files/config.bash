NSLOTS=4

## proxy
export http_proxy="http://webproxy.mpi-bremen.de:3128"
export https_proxy="https://webproxy.mpi-bremen.de:3128"

## folders
#mg_traits_dir="/bioinf/projects/megx/mg-traits/bin"
RESOURCES_BIN="/bioinf/projects/megx/mg-traits/resources/bin"
RESOURCES="/bioinf/projects/megx/mg-traits/resources"
temp_dir="/bioinf/projects/megx/scratch/mg-traits"
job_out_dir="/vol/tmp/megx/"

RUNNING_JOBS_DIR="${temp_dir}/running_jobs/"
FAILED_JOBS_DIR="${temp_dir}/failed_jobs/"
FINISHED_JOBS_DIR="${temp_dir}/finished_jobs/"

## mails
mt_admin_mail="epereira@mpi-bremen.de"

## cdhit
# cd_hit_dup="${RESOURCES_BIN}/cd-hit-otu-illumina-0.0.1/cd-hit-dup-0.0.1-2011-09-30/cd-hit-dup"
# cd_hit_est="${RESOURCES_BIN}/cdhit-master/cd-hit-est"
# cd_hit_mms="${RESOURCES_BIN}/cdhit-master/make_multi_seq.pl"
# cd_hit_version="4.6"

## fgs
frag_gene_scan="/bioinf/software/fraggenescan/fraggenescan-1.19/run_FragGeneScan.pl"
frag_gene_scan_version="1.19"

## uproc
uproc_version="1.2"
uproc="/bioinf/software/uproc/uproc-1.2/bin/uproc-dna"
uproc_pfam="/local/biodb/uproc/pfam28"
uproc_pfam_version="pfam28"
uproc_model="/local/biodb/uproc/model"

## sortmerna
sortmerna_version="2.0"
sortmerna="/bioinf/software/sortmerna/sortmerna-${sortmerna_version}/bin/sortmerna"
DB="/bioinf/software/sortmerna/sortmerna-${sortmerna_version}/"

## sina                                
sina_version="1.2.13"
#sina="/bioinf/software/sina/sina-1.3.0rc/sina"
sina="/bioinf/projects/megx/mg-traits/resources/sina/sina-${sina_version}/sina"
sina_arb_pt_server="/bioinf/projects/megx/mg-traits/bin/sina-${sina_version}/lib/arb_pt_server"

sina_seed_version="ssu_seed_50_26_05_13_cut_t"
sina_seed="/local/biodb/mg-traits/sina/${sina_seed_version}.arb"  # SINA SEED HAS TO BE UPDATED????!!!!!

#sina_ref="/local/biodb/mg-traits/sina/ssuref_silva_nr99_115_20_07_13.arb"
#sina_ref="${RESOURCES}/sina/SSURef_Nr99_123.1_SILVA_03_03_16_opt.arb" NEEDS PERMISSIONS TO RUN IN /bioinf/projects/megx !!!!
sina_ref_version="SSURef_Nr99_123.1_SILVA_03_03_16"
sina_ref="/bioinf/home/epereira/workspace/mg-traits/resources/sina/${sina_ref_version}_opt.arb"

ARBHOME="/bioinf/projects/megx/mg-traits/bin/sina-${sina_version}/"
LD_LIBRARY_PATH="/bioinf/projects/megx/mg-traits/bin/sina-1.2.13/lib:/bioinf/software/gcc/gcc-4.9/lib64:/usr/lib/libgomp.so.1:$LD_LIBRARY_PATH"
export LD_LIBRARY_PATH

## R
r_interpreter_version="3.2.3"
r_interpreter="/bioinf/software/R/R-${r_interpreter_version}/bin/R"

## scripts
fasta_file_check="${RESOURCES_BIN}/fasta_file_check.pl"
fgs_runner="${RESOURCES_BIN}/fgs_runner2.sh"
sina_runner="${RESOURCES_BIN}/sina_runner2.sh"
finish_runner="${RESOURCES_BIN}/finish_runner.sh"
#finish_runner2="/bioinf/projects/megx/mg-traits/resources/bin/test/finish_runner.sh"

seq_stats="${RESOURCES_BIN}/seq_stats.R"
#cd_hit_dup_runner="${RESOURCES_BIN}/cd_hit_dup_runner.sh"
vsearch_version="2.0.2"
vsearch="/bioinf/software/vsearch/vsearch-${vsearch_version}/bin/vsearch"
vsearch_runner="${RESOURCES_BIN}/vsearch_runner.sh"
sortmerna_runner2="${RESOURCES_BIN}/sortmerna_runner2.sh"

## URLs: pfam, silva, tf_file
#PFAM_ACCESSIONS_URL="https://colab.mpi-bremen.de/micro-b3/svn/analysis-scripts/trunk/mg-traits/data/pfam27_acc.txt"
PFAM_ACCESSIONS_URL="file:///bioinf/projects/megx/mg-traits/resources/pfam/pfam28_acc.txt"
TFFILE_URL="https://colab.mpi-bremen.de/micro-b3/svn/analysis-scripts/trunk/mg-traits/data/TF.txt"
SLV_TAX_URL="https://colab.mpi-bremen.de/micro-b3/svn/analysis-scripts/trunk/mg-traits/data/silva_tax_order_115.txt"

## names
RAW_DOWNLOAD="01-raw-download"
RAW_FASTA="01-raw-fasta"
FASTA_BAD="01-bad-fasta"
UNIQUE="02-unique-sequences"
UNIQUE_LOG="02-unique-sequences.log"
CLUST95="03-clustered-sequences"
CLUST95_LOG=$CLUST95".log"
CLUST95_CLSTR=$CLUST95".clstr"
INFOSEQ_TMPFILE="04-stats-tempfile"
INFOSEQ_MGSTATS="04-mg_stats"
SORTMERNA_OUT="06-smrna"
NSEQ=1000000 # set to 2000 000 
nSEQ=1000  # set to 2000
# NSEQ=50000 # set to 2000 000 
# nSEQ=500  # set to 2000

