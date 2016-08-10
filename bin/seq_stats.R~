args = commandArgs(trailingOnly=TRUE)

t<-read.table(file = args[1], header = F)
bp<-sum(as.numeric(t[,1]))
meanGC<-mean(as.numeric(t[,2]))
varGC<-var(as.numeric(t[,2]))
res<-paste(bp, meanGC, varGC, sep = ' ')
write(x=res,file=args[2])	


