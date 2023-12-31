# Set working directories
path.dropbox <-"/Users/alba/Dropbox (Partners HealthCare)/p53MPNAML/p53_paper_RawData/01.Preprocessing/HT_transcriptome_revised/06-SinglCellaR/"
#path.dropbox <- "/Users/seanwen/Dropbox/p53_paper_IAD/01.Preprocessing/HT_transcriptome_revised/SinglCellaR/"
#path.local <- "/Users/seanwen/Documents/Alba/data_check/01.Preprocessing/HT_transcriptome_revised/SinglCellaR/"
#setwd(path.local)

# Load additional packages
library(SingCellaR)

#High throughput scRNA-seq of MPNAML samples - SingleCellaR processing
#Data preprocessing and QC metrics
#Author:Alba Rodriguez-Meira
#Date: 6th March 2021
#Modified last: 4th May 2021
####################################################

###################################
library(SingleCellExperiment)
library(Rcpp)
library(Matrix)
library(matrixStats)
library(bigmemory)
library(LinkedMatrix)
library(irlba)
library(Rtsne)
library(ggplot2)
library(gridExtra)
library(cccd)
library(ggpubr)
library(statmod)
library(umap)
library(reticulate)
library(data.table)
library(pbapply)
library(fgsea)
library(limma)
library(RANN)
library(ComplexHeatmap)
library(circlize)
library(threejs)
library(RColorBrewer)
library(igraph)
library(pheatmap)
library(AUCell)
library(diffusionMap)
library(destiny)
library(harmony)
##################################
load(file="Robjects/HTMPNAML_final.revised.rdata")
######################################
table(HTMPNAML@meta.data$stage)

# Select APhase donors
AP<-c("GH001_003","GR003_AP","IF0392","GST010","GR004_AP","IF0131","JB4211",
      "IF0393","GR001","GR005_AP","GR007_AP","GR006_AP","IF0391","GR002","SB5702","IF0318")

HTMPNAML@meta.data$IsPassed<-FALSE
HTMPNAML@meta.data$IsPassed[HTMPNAML@meta.data$stage %in% AP]<-TRUE
table(HTMPNAML@meta.data$IsPassed) #10539 (Revised: 10459)

HTMPNAML@meta.data$genotype.collapsed<-HTMPNAML@meta.data$genotype.classification
HTMPNAML@meta.data$genotype.collapsed[HTMPNAML@meta.data$genotype.classification=="TP53_multihit_HOM"]<-"TP53_multihit"
HTMPNAML@meta.data$genotype.collapsed[HTMPNAML@meta.data$genotype.classification=="TP53_multihit_M2"]<-"TP53_multihit"

#Check which cells don't have an assigned genotype
new_DF <- HTMPNAML@meta.data[is.na(HTMPNAML@meta.data$genotype.collapsed),]
table(new_DF$stage)

AP.HTMPNAML<-HTMPNAML
rm(HTMPNAML)

normalize_UMIs(AP.HTMPNAML,use.scaled.factor = F)

#############################################################################
remove_unwanted_confounders(AP.HTMPNAML,residualModelFormulaStr="~detectedGenesPerCell+UMI_count") 
#############################################################################

get_variable_genes_by_fitting_GLM_model(AP.HTMPNAML,mean_expr_cutoff = 1,disp_zscore_cutoff = 0.1,
                                        quantile_genes_expr_for_fitting = 0.6,quantile_genes_cv2_for_fitting = 0.3)

#"Identified :3683 variable genes"

remove_unwanted_genes_from_variable_gene_set(AP.HTMPNAML,gmt.file = paste(path.dropbox,"SingleCellaR.0.1.4/Data/genesets/human.signature.genes.gmt",sep=""),
                                             removed_gene_sets=c("Ribosomal_gene","Mitocondrial_gene"))

#"10 genes are removed from the variable gene set."
plot_variable_genes(AP.HTMPNAML,quantile_genes_expr_for_fitting = 0.6,quantile_genes_cv2_for_fitting = 0.3)
#####################################
runPCA(AP.HTMPNAML,use.components=50,use.regressout.data = T)
plot_PCA_Elbowplot(AP.HTMPNAML)
######################################
source("../../../Sources/SingleCell_Integration_Edit.R") # Disable requirement that object should be SingCellaR
runHarmony(AP.HTMPNAML,covariates = c("stage"),n.dims.use=20,harmony.max.iter = 20,harmony.theta = 1,n.seed = 1)
#Harmony converged after 2 iterations
######################################
runUMAP(AP.HTMPNAML,useIntegrativeEmbeddings = T,integrative_method = "harmony",n.dims.use=20,umap_method = "uwot", n.neighbors=30,uwot.metric = "cosine",uwot.min.dist=0.30, n.seed = 1)

plot_umap_label_by_a_feature_of_interest(AP.HTMPNAML,feature = "genotype.collapsed")
plot_umap_label_by_a_feature_of_interest(AP.HTMPNAML,feature = "stage")
plot_umap_label_by_a_signature_gene_set(AP.HTMPNAML,gene_list=c("GATA1","KLF1"),gene_set_name=c("erythroid"))
plot_umap_label_by_a_signature_gene_set(AP.HTMPNAML,gene_list=c("AVP","HLF"),gene_set_name=c("preleukemic"))
plot_umap_label_by_a_signature_gene_set(AP.HTMPNAML,gene_list=c("HOXA9","IL2RG"),gene_set_name=c("LSC"))
plot_umap_label_by_a_signature_gene_set(AP.HTMPNAML,gene_list=c("ASPM","CENPE","CENPF","DLGAP5","MKI67","NUSAP1","PCLAF","STMN1","TOP2A","TUBB"),
                                                      gene_set_name=c("cycle_vanGalen"))
plot_umap_label_by_a_signature_gene_set(AP.HTMPNAML,gene_list=c("HMGB2","NUSAP1","UBE2C","CDK1","BIRC5","TPX2","TOP2A","NDC80","CKS2","NUF2"),
                                         gene_set_name=c("G2M"))

######################################

#runFA2_ForceDirectedGraph(AP.HTMPNAML,useIntegrativeEmbeddings=T,
                          #integrative_method=c("harmony"),
                          #knn.metric=c("euclidean"),n.dims.use=20,n.neighbors=30,n.seed = 1)

#plot_forceDirectedGraph_label_by_a_feature_of_interest(AP.HTMPNAML,feature = "genotype.collapsed",
                                                       #title="force-directed graph",
                                                       #vertex.size = 1)
#plot_forceDirectedGraph_label_by_a_feature_of_interest(AP.HTMPNAML,feature = "genotype.classification",
                                                       #title="force-directed graph",vertex.size = 1)

# plot_forceDirectedGraph_label_by_a_signature_gene_set(AP.HTMPNAML,gene_list=c("AVP","HLF","MLLT4","CRHBP"),gene_set_name=c("preleukemic"),vertex.color1="grey70")
# plot_forceDirectedGraph_label_by_a_signature_gene_set(AP.HTMPNAML,gene_list=c("GATA1","KLF1","ITAG2B","FCER1A","EPOR","HBD"),gene_set_name=c("erythroid"),vertex.color1="grey70")
# plot_forceDirectedGraph_label_by_a_signature_gene_set(AP.HTMPNAML,gene_list=c("IL2RG","SPINK2"),gene_set_name=c("LSC"),vertex.color1="grey70")
# plot_forceDirectedGraph_label_by_a_signature_gene_set(AP.HTMPNAML,gene_list=c("ASPM","CENPE","CENPF","DLGAP5","MKI67","NUSAP1","PCLAF","STMN1","TOP2A","TUBB"),
#                                                       gene_set_name=c("cycle_vanGalen"),vertex.color1="grey70")
# plot_forceDirectedGraph_label_by_a_signature_gene_set(AP.HTMPNAML,gene_list=c("HMGB2","NUSAP1","UBE2C","CDK1","BIRC5","TPX2","TOP2A","NDC80","CKS2","NUF2"),
#                                         gene_set_name=c("G2M"),vertex.color1="grey70")

######################################
#library(diffusionMap)
#runDiffusionMap(AP.HTMPNAML,dim_reduction_method=c("pca"),useIntegrativeEmbeddings=T,
                #integrative_method = "harmony",n.dims.use=20,n.dims.embed=5,n.neighbors=5,distance="euclidean",n.seed = 1)

#DC1 separates the erythroid cluster
#dim=35 n.neigh=20 separates preleuk vs erythroid in DC1
#plot_diffusionmap_label_by_genes(AP.HTMPNAML,gene_list=c("AVP","CRHBP","HLF","MLLT4"),x_eigenVal = "DC1",y_eigenVal = "DC2")
#plot_diffusionmap_label_by_genes(AP.HTMPNAML,gene_list=c("GATA1","KLF1"),x_eigenVal = "DC1",y_eigenVal = "DC2")
#plot_diffusionmap_label_by_genes(AP.HTMPNAML,gene_list=c("IL2RG","SPINK2"),x_eigenVal = "DC1",y_eigenVal = "DC2")

######################################
# DiffMap<-get_dfm.result(AP.HTMPNAML)
# point.size<-2
# 
# DiffMap<-subset(DiffMap,genotype.collapsed=="leukemic"|genotype.collapsed=="preleukemic"|genotype.collapsed=="TP53HET")
# 
# library("gg3D")
# ## An empty plot with 3 axes
# qplot(x=0, y=0, z=0, geom="blank") + 
#   theme_void() +
#   axes_3D()
# 
# ggplot(DiffMap, aes(x=-DC1, y=DC2, z=DC4, color=genotype.collapsed)) + 
#   theme_void() +
#   axes_3D() +
#   stat_3D() +
#   scale_colour_manual(values=c("red3","deepskyblue","orange"))+
#   geom_point(size=point.size)

#ggsave(filename="output/DifMap_Harmony_integration.png",width = 10,height = 8)

####################
# plot_diffusionmap_label_by_gene_set_3D(AP.HTMPNAML,gmt.file="SingleCellaR.0.1.4/Data/genesets/MC.human.signature.genes.gmt",
#                                        show_gene_sets=c("Preleukemic_p53"))
# 
# plot_diffusionmap_label_by_gene_set_3D(AP.HTMPNAML,gmt.file="SingleCellaR.0.1.4/Data/genesets/MC.human.signature.genes.gmt",
#                                        show_gene_sets=c("Ery_AML"))
# 
# plot_diffusionmap_label_by_gene_set_3D(AP.HTMPNAML,gmt.file="SingleCellaR.0.1.4/Data/genesets/MC.human.signature.genes.gmt",
#                                        show_gene_sets=c("LSC_p53"))
####################

######################################
#Merge Louvain clusters

identifyClusters(AP.HTMPNAML,n.dims.use = 20,n.neighbors = 30,dim_reduction_method=c("pca"),useIntegrativeEmbeddings=TRUE,integrative_method=c("harmony"),knn.metric=c("euclidean")) #Louvain analysis

plot_umap_label_by_clusters(AP.HTMPNAML,show_method=c("louvain"))
plot_umap_label_by_genes(AP.HTMPNAML,gene_list=c("GATA1"))
plot_umap_label_by_a_signature_gene_set(AP.HTMPNAML,gene_list=c("AVP","HLF"),gene_set_name=c("preleukemic"))
plot_umap_label_by_a_signature_gene_set(AP.HTMPNAML,gene_list=c("HOXA9","IL2RG"),gene_set_name=c("LSC"))

plot_diffusionmap_label_by_clusters(AP.HTMPNAML,show_method=c("louvain"))

#cl6: preleukemic cluster
#cl3:cl4:cl5:cl11 : erythroid cluster
#cl12:cl8:cl9:cl10:cl1:cl7:cl2

##########################################################################

merge_clusters(AP.HTMPNAML,cluster.type = "louvain",merge_cluster_ids = c('cl3:cl4:cl5:cl11','cl12:cl8:cl9:cl10:cl1:cl7:cl2'))
plot_umap_label_by_clusters(AP.HTMPNAML,show_method = "merged_louvain",mark.clusters = T)
# plot_forceDirectedGraph_label_by_clusters(AP.HTMPNAML,show_method=c("merged_louvain"))

#cl1 - LSC
#cl2 - erythroid
#cl3 - preleukemic

table(AP.HTMPNAML@sc.clusters$merged_louvain)
merged_louvain<-AP.HTMPNAML@sc.clusters[,c("Cell","merged_louvain")]
write.table(merged_louvain,file="../classification/louvain/louvain.Harmony.APMPNAML.revised.txt",sep="\t",row.names = F)

################################################
save(AP.HTMPNAML,file = "Robjects/AP_HTMPNAML_Harmony.revised.rdata")
################################################
