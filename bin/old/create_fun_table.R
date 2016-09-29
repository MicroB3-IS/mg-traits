echo "Calculating functional table..." # this script should be independent

"${r_interpreter}" --vanilla --slave <<RSCRIPT
n.genes<-as.numeric("${NUM_GENES}")
t<-read.table(file = '${PFAMFILE}', header = F, stringsAsFactors=F, sep=",")
colnames(t)<-c("seq_id", "pfam_acc")
perc.cl<-(length(unique(t[,1]))/n.genes)*100
t<-subset(t, select = "pfam_acc")
p<-read.table(file = '${PFAM_ACCESSIONS}', header = F, stringsAsFactors=F)
colnames(p)<-'pfam_acc'
tf<-read.table(file = '${TFFILE}', header = F, stringsAsFactors=F)
colnames(tf)<-'pfam_acc'
t.t<-as.data.frame(table(t${pfam_acc}))
colnames(t.t)<-c("pfam_acc", "counts")
t.m<-merge(p, t.t, all = T, by= "pfam_acc")
t.m[is.na(t.m)]<-0
colnames(t.m)<-c("pfam_acc", "counts")
tf.m<-merge(t.t, tf, all = F, by= "pfam_acc")
colnames(tf.m)<-c("pfam_acc", "counts")
perc.tf<-( sum(as.numeric(tf.m[,2])) / sum(as.numeric(t.m[,2])) )*100
write.table(t.m, file = '${FUNCTIONALTABLE}', sep = "\t", row.names = F, quote =
F, col.names = F)
write.table(perc.tf, file = '${TFPERC}', sep = "\t", row.names = F, quote = F,
col.names = F)
write.table(perc.cl, file = '${CLPERC}', sep = "\t", row.names = F, quote = F,
col.names = F)
RSCRIPT
