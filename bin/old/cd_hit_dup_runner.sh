#$ -S /bin/bash
#$ -cwd 
#$ -V
#$ -j y
#$ -R y

INFILE=$1
OUTFILE=$2
LOG=$3

cd_hit_dup="/bioinf/projects/megx/mg-traits/resources/bin/cdhit-master/cd-hit-auxtools/cd-hit-dup"

"${cd_hit_dup}" -d 1 -i "${INFILE}" -o "${OUTFILE}" > "${LOG}"

