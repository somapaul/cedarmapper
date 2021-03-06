#' Example of using graph mapper with synthetic circular data
#' 
circle.graphmapper<- function(npoints=100, randomize=FALSE) {
  gm= graphmapper(circle_data(1, npoints,randomize=randomize), lensefun=lense.pca, lenseparam=1, 
                  partition_count=6, overlap = 0.5,bin_count=10, normalize_data = TRUE)
  gm$distance   <- distance.graphmapper(gm)
  gm$partitions <- partition.graphmapper(gm)
  print ( gm$partitions)
  gm$clusters   <- clusters.graphmapper(gm, cluster_method = "single", shinyProgressFunction=NULL ) 
  gm$nodes      <- nodes.graphmapper(gm)
  
  gm$adjmatrix  <- adjacency.graphmapper(gm) 
  return(gm)
}

plot.circle.mapper<- function(npoints=100, randomize=FALSE) {
  m <- circle_mapper(npoints,partition_count=4, overlap = 0.5)
  m <- mapper.run(m)
  plot(graph.mapper(m), main = paste0("Circle data"))
  return(m)
}


# example 1, 100 points
gm = circle.graphmapper()
plot(graph.graphmapper(gm), main = paste0("Circle data, ", nrow(gm$d), " points"))

#cat ("Press [enter] to run Mapper on 1000 points")
#line <- readline()
#gm = circle.graphmapper(1000,randomize=TRUE)
#plot(graph.graphmapper(gm), main = "Circle data, 1000 points")



# this is a previous attempt at visualizing the partitioning and clustering scheme
# it currently does not work, but left for posterity
# it requires a special library (factoextra) which requires a package that needs source compiliation and 
# is difficult to install
circle_cluster_gap_viz <- function(d,partitions){
  l = length(partitions)
  o_par = par()
  par(mfrow = c(2,2))
  
  for ( i in 1:l) {
    # print dendograms with colored clusters
    
    d.subset = partitions[[i]][,-3]  # remove the ID column,TODO remove hard coded col num
    eClusts = eclust(d.subset, FUNcluster="hclust", k.max = 5, stand =TRUE, B = 500, hc_metric="euclidean", hc_method="single")
    # don't keep the value, just plot
  }
  
  for ( i in 1:l) {
    cGaps <- clusGap(as.matrix(d.subset), FUN = hcut, K.max = 5, B = 200, hc_metric="euclidean", hc_method="single")
    print(fviz_gap_stat(cGaps ))
  }
  par(o_par)
  
}
