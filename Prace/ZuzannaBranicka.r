#required packages:
library(rpart)
library(MASS)
library(randomForest)
library(ipred)

################################################
#heteroforest - constructs a heterogeneous ensemble of classifiers (trees, LDA and knn classifiers)

#Arguments:
#formula - formula describing the model of the form: factor variable containing labels~predictors
#data - data frame containing the variables in the model
#nclas - number of classifiers in the ensemble
#ntree - number of trees in the ensemble
#nknn - number of knn classifiers in the ensemble
#mtr - number of variables randomly sampled at each node of a tree
#mlda - number of variables randomly sampled for each LDA classifier
#mknn - number of variables randomly sampled for each knn classifier
#kknn - number of neighbours for knn classifiers
#sd.dt, mean.dt - vectors of standard deviation and mean for variables used; if not provided, their values are computed from the data set
#wtype - type of weights to be used for weighted ensemble (possible values: "boost" - w=log((1-err)/err), "rec" - w=(1-2err)/err, "sq" - w=(1-2err)/err^2)

#Result: a list of the following components:
#forest - a list of classifiers in the ensemble
#inderr - a vector of individual OOB errors of classifiers
#weights - a vector of weights assigned to classifiers
#ntree - number of trees
#nlda - number of LDA classifiers
#sd.dt, mean.dt - as above
#nobs - number of observations in the provided data set
#err.lev - a matrix of individual OOB errors of classifiers computed for each level of the factor variable separately
#w.lev - a matrix of weights assigned to classifiers for each level of the factor variable separately
#vars - names of the variables appearing in the formula

heteroForest<-function(formula,data,nclas,ntree=floor(nclas/2),nknn=0,mtr=floor(sqrt(ncol(data)-1)),mlda=2*floor(sqrt(ncol(data)-1)),mknn=2*floor(sqrt(ncol(data)-1)),kknn=5,sd.dt=NULL,mean.dt=NULL,wtype="boost"){
nobs<-nrow(data)
ncols<-ncol(data)
forest<-list()
length(forest)<-nclas
nlda<-nclas-ntree-nknn
err<-rep(NA,nclas)
varnames<-all.vars(formula)
nvar<-length(varnames)
ncolvar<-vector(length=nvar)
if (is.element(".",varnames)) {varnames<-c(varnames[1],setdiff(names(data),varnames)); nvar<-ncols}
for (i in 1:nvar) ncolvar[i]<-which(names(data)==varnames[i])
data<-data[,ncolvar]
names(data)[1]<-"factor"
lnames<-levels(data[,1])
nlev<-length(lnames)
err.lev<-matrix(NA,nlev,nclas)
w.lev<-matrix(NA,nlev,nclas)
M<-1000
if(is.null(sd.dt)) sd.data<-apply(data[,-1],2,sd) else sd.data<-sd.dt
if(is.null(mean.dt)) mean.data<-apply(data[,-1],2,mean) else mean.data<-mean.dt
data.sc<-data
data.sc[,-1]<-scale(data[,-1],center=mean.data,scale=sd.data)
if (ntree>0){for (i in 1:ntree){
		tr<-randomForest(factor~., data, ntree=1, keep.inbag=T, mtry=mtr)
		data.oob<-data[which(tr$inbag==0),]
		forest[[i]]<-tr
		tr.pred<-predict(tr,data.oob)
		err[i]<-mean(tr.pred!=data.oob[,1])
		for (j in 1:nlev) {lev<-tr.pred==lnames[j]
		lev.oob<-data.oob[,1]==lnames[j]
		err.lev[j,i]<-ifelse(sum(lev)!=0,mean(tr.pred[lev]!=data.oob[lev,1]),ifelse(sum(lev.oob)==0,0,1))}
		}}
if (nlda>0){for (i in (ntree+1):(ntree+nlda)){
			I<-sample(nobs,nobs,rep=T)
			J<-sample(2:nvar,mlda)
			data.train<-data[I,c(1,J)]
			data.oob<-data[-I,J]
			y.oob<-data[-I,1]
			ldacl<-lda(factor~.,data.train)
			forest[[i]]<-ldacl
			ldacl.pred<-predict(ldacl,newdata=data.oob)
			err[i]<-mean(ldacl.pred$class!=y.oob)
			for (j in 1:nlev) {lev<-ldacl.pred$class==lnames[j]
			lev.oob<-y.oob==lnames[j]
			err.lev[j,i]<-ifelse(sum(lev)!=0,mean(ldacl.pred$class[lev]!=y.oob[lev]),ifelse(sum(lev.oob)==0,0,1))}
			}}
if (nknn>0){for (i in (ntree+nlda+1):nclas){
			I<-sample(nobs,nobs,rep=T)
			J<-sample(2:nvar,mknn)
			data.train<-data.sc[I,c(1,J)]
			data.oob<-data.sc[-I,J]
			y.oob<-data.sc[-I,1]
			knncl<-ipredknn(factor~.,data.train,k=kknn)
			forest[[i]]<-knncl
			knncl.pred<-predict(knncl,newdata=data.oob,"class")
			err[i]<-mean(knncl.pred!=y.oob)
			for (j in 1:nlev) {lev<-knncl.pred==lnames[j]
			lev.oob<-y.oob==lnames[j]
			err.lev[j,i]<-ifelse(sum(lev)!=0,mean(knncl.pred[lev]!=y.oob[lev]),ifelse(sum(lev.oob)==0,0,1))}
			}}
err[err==0]<-mean(err)/M
err.lev[err.lev==0]<-mean(err.lev)/M
if (wtype=="boost") w<-log((1-err)/err) else {if (wtype=="rec") w<-(1-2*err)/err else {if (wtype=="sq") w<-(1-2*err)/err^2 else print("Improper value of argument 'wtype'!", quote=F)}}
w[w<0]<-0
if (wtype=="boost") w.lev<-log((1-err.lev)/err.lev) else {if (wtype=="rec") w.lev<-(1-2*err.lev)/err.lev else {if (wtype=="sq") w.lev<-(1-2*err.lev)/err.lev^2 else print("Improper value of argument 'wtype'!", quote=F)}}
w.lev[w.lev<0]<-0
list(forest=forest,inderr=err,weights=w,ntree=ntree,nlda=nlda,sd.dt=sd.data,mean.dt=mean.data,nobs=nobs,err.lev=err.lev,w.lev=w.lev, vars=varnames)
}

###################################################
#predict.hf - applies a previously constructed heterogeneous ensemble to classification

#Arguments:
#hf - heterogeneous ensemble(a result of heteroForest function)
#data - data frame containing data set to be classified (without the variable containing labels)
#use.weights - TRUE if the ensemble should be weighted, FALSE otherwise
#sd.dt, mean.dt - as above (if not provided, their values are computed from the training set and the data set to be classified)

#Result: a list of the following components:
#aggr - a vector of predicted labels (normal weights used)
#aggr.lev - a vector of predicted labels (weights 'w.lev' used)
#ind - a matrix of individual predictions of the classifiers

predict.hf<-function(hf,data,use.weights=F,sd.dt=NULL,mean.dt=NULL){
nclas<-length(hf$forest)
nobs<-nrow(data)
pred<-matrix(NA,nobs,nclas)
ntree<-hf$ntree
nlda<-hf$nlda
nvar<-length(hf$vars)-1
ncolvar<-vector(length=nvar)
for (i in 1:nvar) ncolvar[i]<-which(names(data)==hf$vars[i+1])
data<-data[,ncolvar]
mean.pr<-apply(data,2,mean)
sd.pr<-apply(data,2,sd)
if(is.null(mean.dt)){mean.data<-(mean.pr*nobs+hf$mean.dt*hf$nobs)/(nobs+hf$nobs)} else {mean.data<-mean.dt}
if(is.null(sd.dt)){sd.data<-sqrt((sd.pr^2*nobs+hf$sd.dt^2*hf$nobs)/(nobs+hf$nobs))} else {sd.data<-sd.dt}
data.sc<-as.data.frame(scale(data,center=mean.data,scale=sd.data))
if (ntree>0){for (k in 1:ntree){
			pred[,k]<-as.vector(predict(hf$forest[[k]],data,type="class"))}
			}
if (nlda>0){for (k in (ntree+1):(nlda+ntree)){
			pred[,k]<-as.vector(predict(hf$forest[[k]],newdata=data)$class)}
			}
if (ntree+nlda<nclas){for (k in (ntree+nlda+1):nclas){
			pred[,k]<-as.vector(predict(hf$forest[[k]],newdata=data.sc,"class"))}
			}

lnames<-levels(as.factor(pred))
nlev<-length(lnames)
vote.list<-list()
length(vote.list)<-nlev
for(j in 1:nlev){
	vote.list[[j]]<-pred==lnames[j]}
vote<-matrix(NA,nlev,nobs)
vote.lev<-matrix(NA,nlev,nobs)
w<-hf$weights
w.lev<-hf$w.lev
for(j in 1:nlev){
	if (use.weights) {vote[j,]<-vote.list[[j]]%*%w
				vote.lev[j,]<-vote.list[[j]]%*%w.lev[j,]/sum(w.lev[j,])}
	else {vote[j,]<-apply(vote.list[[j]],1,sum)}
}
resp<-apply(vote,2,which.max)
resp.lev<-apply(vote.lev,2,which.max)
for(j in 1:nlev){
	resp[resp==j]<-lnames[j]
	resp.lev[resp.lev==j]<-lnames[j]}
list(aggr=resp,aggr.lev=resp.lev,ind=pred)
}

######################################################
#repeatHFcorr - repeates simulations (constructing heterogeneous ensembles and using them to classification)

#Arguments:
#formula - as above
#data - a data frame containing the whole data set (to be divided into training and testing sets)
#nclas, ntree, nknn - as above
#ntimes - number of simulations to be conducted
#mtr, mlda, mknn, kknn - as above
#method - method for computing correlation between classifiers (possible values: "cor"-Spearman's rank correlation coefficient, "kappa"-Cohen's kappa coefficient)
#use.weights, wtype - as above

#Result: a list of the following components (all vectors are of length 'ntimes'):
#corr - a vector of mean correlation between classifiers in the ensemble
#corr.tree - a vector of mean correlation between trees in the ensembles
#corr.lda - a vector of mean correlation between LDA classifiers in the ensembles
#corr.knn - a vector of mean correlation between knn classifiers in the ensembles
#err - a vector of classification errors of the ensembles (if weighted, normal weights used)
#err.lev - a vector of classification errors of the ensembles (if weighted, 'w.lev' weights used)
#inderr - a vector of mean individual errors of the classifiers in the ensembles
#inderr.tree - a vector of mean individual errors of trees in the ensembles
#inderr.lda - a vector of mean individual errors of LDA classifiers in the ensembles
#inderr.knn - a vector of mean individual errors of knn classifiers in the ensembles
#w.sd - a vector of standard deviations of weights
#w.tree - a vector of mean weights assigned to trees 
#w.lda - a vector of mean weights assigned to LDA classifiers 
#w.knn - a vector of mean weights assigned to knn classifiers 

repeatHFcorr<-function(formula, data, nclas, ntree=floor(nclas/2), nknn=0, ntimes,mtr=floor(sqrt(ncol(data)-1)),mlda=2*floor(sqrt(ncol(data)-1)),mknn=2*floor(sqrt(ncol(data)-1)),method="cor",use.weights=F,kknn=5,wtype="boost"){
nobs<-nrow(data)
ncols<-ncol(data)
test.len<-floor(nobs/3)
hf.corr<-rep(NA,ntimes)
tree.corr<-rep(NA,ntimes)
lda.corr<-rep(NA,ntimes)
knn.corr<-rep(NA,ntimes)
inderr<-rep(NA,ntimes)
inderr.tree<-rep(NA,ntimes)
inderr.lda<-rep(NA,ntimes)
inderr.knn<-rep(NA,ntimes)
err<-rep(NA,ntimes)
err.lev<-rep(NA,ntimes)
w.sd<-rep(NA,ntimes)
w.tree<-rep(NA,ntimes)
w.lda<-rep(NA,ntimes)
w.knn<-rep(NA,ntimes)
nlda<-nclas-ntree-nknn
varnames<-all.vars(formula)
nvar<-length(varnames)
ncolvar<-vector(length=nvar)
if (is.element(".",varnames)) {varnames<-c(varnames[1],setdiff(names(data),varnames)); nvar<-ncols}
for (i in 1:nvar) ncolvar[i]<-which(names(data)==varnames[i])
ncolf<-ncolvar[1]
sd.dt<-apply(data[,ncolvar[-1]],2,sd)
mean.dt<-apply(data[,ncolvar[-1]],2,mean)
for (i in 1:ntimes){
	I<-sample(nobs,nobs-test.len)
	hf<-heteroForest(formula,data[I,],nclas=nclas,ntree=ntree,nknn=nknn,mtr=mtr,mlda=mlda,mknn=mknn,kknn=kknn,sd.dt=sd.dt,mean.dt=mean.dt,wtype=wtype)
	hf.pred<-predict.hf(hf, data[-I,-ncolf],use.weights=use.weights,sd.dt=sd.dt,mean.dt=mean.dt)
	w.sd[i]<-sd(hf$weights)
	inderrm<-hf.pred$ind!=data[-I,ncolf]
	inderr[i]<-mean(inderrm)				
	err[i]<-mean(hf.pred$aggr!=data[-I,ncolf])
	err.lev[i]<-mean(hf.pred$aggr.lev!=data[-I,ncolf])
	hf.corr[i]<-cor.mean(hf.pred$ind,method)
	if (ntree>0) {inderr.tree[i]<-mean(inderrm[,1:ntree]);
			tree.corr[i]<-cor.mean(hf.pred$ind[,1:ntree],method);
			w.tree[i]<-sum(hf$weights[1:ntree])/sum(hf$weights)}
	if (nlda>0){inderr.lda[i]<-mean(inderrm[,(ntree+1):(ntree+nlda)]);
			lda.corr[i]<-cor.mean(hf.pred$ind[,(ntree+1):(ntree+nlda)],method);
			w.lda[i]<-sum(hf$weights[(ntree+1):(ntree+nlda)])/sum(hf$weights)}
	if (nknn>0){inderr.knn[i]<-mean(inderrm[,(ntree+nlda+1):nclas]);
			knn.corr[i]<-cor.mean(hf.pred$ind[,(ntree+nlda+1):nclas],method);
			w.knn[i]<-sum(hf$weights[(ntree+nlda+1):nclas])/sum(hf$weights)}
	}
list(corr=hf.corr,corr.tree=tree.corr,corr.lda=lda.corr,corr.knn=knn.corr,err=err,err.lev=err.lev,inderr=inderr,inderr.tree=inderr.tree,inderr.lda=inderr.lda,inderr.knn=inderr.knn,w.sd=w.sd,w.tree=w.tree,w.lda=w.lda,w.knn=w.knn)
}

#################################################
#cor.mean - computes mean correlation between columns of a matrix x using method 'method'
#(possible values: "cor"-Spearman's rank correlation coefficient, "kappa"-Cohen's kappa coefficient)

cor.mean<-function(x,method){
if (!is.numeric(x)){nnum<-x[,!apply(x,2,is.numeric)]
			lev<-levels(as.factor(nnum))
			nlev<-length(lev)
			for (i in 1:nlev){x[x==lev[i]]<-i-1}
			x<-apply(x,2,as.numeric)}
if (method=="cor") corr<-cor(x,method="spearman") else {if (method=="kappa") corr<-ckappa(x) else print("Improper value of argument 'method'!", quote=F)}
mean(corr[upper.tri(corr)])
}

################################################
#ckappa - computes Cohen's kappa coefficient between columns of a matrix x

ckappa<-function(x){
nobs<-nrow(x)
nvar<-ncol(x)
coin<-matrix(NA,nvar,nvar)
diag(coin)<-nobs
lev<-levels(as.factor(x))
nlev<-length(lev)
p.coin<-0
for (i in 1:nlev){
prob<-apply((x==lev[i]),2,sum)/nobs
p.coin<-p.coin+prob%*%t(prob)
}
if (nvar>2) {for (i in 1:(nvar-2)){
xi<-(x[,-(1:i)]==x[,i])
coin[i,-(1:i)]<-apply(xi,2,sum)
}}
xlast<-(x[,nvar]==x[,(nvar-1)])
coin[(nvar-1),nvar]<-sum(xlast)
k<-(coin/nobs-p.coin)/(1-p.coin)
k[lower.tri(k)]<-t(k)[lower.tri(k)]
k}
