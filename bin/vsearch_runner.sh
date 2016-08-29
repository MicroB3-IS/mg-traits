#!/bin/bash
#$ -S /bin/bash
#$ -cwd 
#$ -V
#$ -j y
#$ -R y

INFILE=$1
OUTFILE=$2
LOG=$3

##### load vsearch module #####
source /bioinf/software/etc/profile.modules
module load vsearch/2.0.2
##### load vsearch module #####

vsearch="/bioinf/software/vsearch/vsearch-2.0.2/bin/vsearch"

vsearch --derep_prefix "${INFILE}" --fastaout --notrunclables --threads $NSLOTS --output "${OUTFILE}" --log "${LOG}"
# ${vsearch} -derep_prefix "${INFILE}" -fastaout --notrunclables --threads $NSLOTS --output "${OUTFILE}" --log "${LOG}"
