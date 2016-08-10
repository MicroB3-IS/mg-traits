
LIST=/bioinf/projects/megx/mg-traits/resources/insert_commands.bash
#NUM_LIST=$(cat ${LIST} | wc -l )
NUM_LIST=12

for i in $(seq 1 ${NUM_LIST} ); do

while [[ $(qstat -u megxnet | egrep -c "mg_traits.*megxnet" ) -gt 4 ]]; do
  echo "sleeping ..."
  sleep 1m
done

insert_comm=$( sed -n "${i}"p "${LIST}" )
# echo $insert_comm
echo $insert_comm | psql -U epereira -d megdb_r8 -h antares -p 5434
sleep 10

done


