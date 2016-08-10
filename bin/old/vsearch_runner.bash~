#!/bin/bash
#$ -S /bin/bash
#$ -cwd 
#$ -V
#$ -j y
#$ -R y

INFILE=$1
OUTFILE=$2
LOG=$3
NSLOTS=$4

vsearch="/bioinf/software/vsearch/vsearch-1.9.10/bin/vsearch"

${vsearch} -derep_prefix "${INFILE}" -fastaout --notrunclables --threads $NSLOTS --output "${OUTFILE}" --log "${LOG}"