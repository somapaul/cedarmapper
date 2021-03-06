#' mapper.data.R
#' functions to extract information about a mapper object
#' 

has.groups <- function(gm){
  if(is.null(gm$groups)) return(FALSE)
  if(length(gm$groups) < 2) return(FALSE)
  return(TRUE)
}

# return a table of the variance for each variable for each group
#' @export
varTable <- function(m, group_ids = c(1,2)){
  if(! has.groups(m)) {return(NULL)}
  varFun <- function(varname){
    d1 = groupdata(m,group_ids[1],varname)
    d2 = groupdata(m,group_ids[2],varname)
    return(data.frame("var"=varname, "mean group 1"=mean(d1),  "variance group 1" = var(d1), "mean group 2"=mean(d2), "variance group 2" = var(d2)))
  }
  vtable = ldply(mapper.numeric_cols(m), varFun)
}

# returns a table of ks results for each variable in gm$d
#' @export
kstable <- function(m, group_ids = c(1,2)){
  # requires the 'groups' of the gm object be set ahead of time
  # could have more than 2 , allow to select 2 groups 
  # if(!has.groups(gm)) stop("requires groups to run test") # raise exception need some groups!
  
  # inner function for apply
  # calculates k-s statistic for given column and groups (row sets)
  ksfun <- function(varname) {
    # TODO this is inefficiently duplicating the data in memory
    d1 = groupdata(m,group_ids[1],varname)
    d2 = groupdata(m,group_ids[2],varname)
    # suppress the ks test warnings because we know there will be ties
    kt = suppressWarnings(
      ks.test(d1,d2, alternatives = "two.sided", exact = FALSE) 
    )
    return(data.frame("var"=varname, "pvalue" = kt$p.value, "kstatistic" = kt$statistic))
  }
  
  ktable = ldply(mapper.numeric_cols(m), ksfun)
  # order the table with lowest p-val first
  return(ktable[order(ktable$pvalue),])
}


# returns the data rows for a given group id
groupdata <- function(gm, group_id, varname = NULL){
  # TODO : add error testing
  nodedata(gm, gm$nodes[gm$groups[[group_id]]], varname)
}


####### helpers

is.mapper <- function(o){
  return((class(o)=="mapper"))
}

is.varname <- function(gm, varname){
  if(!is.mapper(gm)) {return(NULL)}
  return( Reduce("&", (varname %in% names(gm$d))))
}

# alias for is.factor, future flexibility
is.categorical <- function(gm,varname=NULL){
  if(is.null(varname))         {return(NULL)}
  if(!is.mapper(gm))           {return(NULL)}
  if(!is.varname(gm, varname)) {return(FALSE)}
     return(is.factor(gm$d[,varname]))
}

# use levels as categories, which assumes using factors for character data
colCategories <- function(gm,varname){
  if (is.categorical(gm,varname)){
    return( levels(gm$d[,varname]))
  } else { 
    return( list() )
  }
}

# this is dangerous practice
# but returns a variable name in the data set no matter what is sent
guaranteedVarname <- function(gm,  varname=NULL){
  if(!is.mapper(gm)) return(NULL)
  
  if (is.null(varname))   return(colnames(gm$d)[1])
  
  if( Reduce("&", (varname %in% colnames(gm$d)))) return(varname)
  
  return(names(gm$d)[1])
}

# return data rows by variable for given node
# a node is a list of data row IDs from gm$d, note a node ID (node 3)
#' @export
nodedata <- function(gm, nodes, varname=NULL){
  # DEBUG
  # print("node data")
  # print(nodes)
  # print(varname)
  
  if(!is.mapper(gm)) return (NULL)
  
  # unlisting potentially overlapping nodes, this works on single node, too
  # TODO this could be expensive for many rows
  rowids = unique(unlist(nodes))
  
  # if no variable name sent, return all columns
  if(is.null(varname)){
    return(gm$d[rowids,])
  } else {
    # return only column(s) requested in varname
    # use reduce here to combine TRUES if varname is vector of names c("X", "Y")
    if( Reduce("&", (varname %in% colnames(gm$d)))){
      return(gm$d[rowids,varname])
    } else if( (varname %in% lenseChoices)){
    return(gm$lensevals[rowids,])
    }
  }
  return()
}

# returns one or more columns of data as listed in one or more partitions
#' @export
partitiondata <- function(gm, p, varname = NULL){
  if(!is.mapper(gm)) return (NULL)
  
  # convert list of partitions into single vector of row ids
  p = unique(unlist(p))
  
  # if no varname param, return all columns
  if(is.null(varname)){
    return(gm$d[gm$partitions[[p]], gm$selected_cols])
  } 
  else {
    # use reduce() here to allow a vector of column names
    if (Reduce("&", (varname %in% names(gm$d))))
      return(gm$d[gm$partitions[[p]],varname])
  }
  # bad variable name sent - error condition?
  return(NULL)
}


#' returns bar plot
#' @export 
#' 
factorBarPlot <- function(gm, varname, nodes){
  x_label = varname
  y_label = "Frequency"
  d = nodedata(gm, gm$nodes[nodes], varname)
  return(barplot(table(d), xlab = x_label, ylab = y_label))
}

#' convert categorical column to binary columns
#' @export
column2binary<-function(df, colname){
  # TODO test if column is atually numeric
  # TODO test for max number of values; e.g. can't add 100 columns
  max_categories= 20
  if(length(levels(factor(df[,colname])))> max_categories){
    print("too many categories")
    return(NULL)
  }
  
  binary_columns <- model.matrix(~ factor(df[,colname]) - 1)
  colnames(binary_columns) <- paste(colname, "-",levels(factor(df[,colname])),sep="")
  return(as.data.frame(binary_columns))
}

#' equalize histogram for cut_function
#' 

equalize_hist <- function(d,nbreaks){
  orig_breaks <- seq(from = min(d), to = max(d), by = (max(d) - min(d))/nbreaks)
  h <- hist(d, breaks = orig_breaks, plot = FALSE)
  cdf <- cumsum(h$counts)
  cdf_len <- length(cdf)
  slope <- cdf[cdf_len] / (max(d) - min(d))
  cdfn <- (cdf / slope) + min(d)
  
  breaks <- c(orig_breaks[1], cdfn[-cdf_len], orig_breaks[nbreaks+1])
  
  breaks_df <- data.frame(orig_breaks,breaks)
  
  # map old data to new values
  d_eq <- d
  i = 1
  m = (breaks_df[i,2] - breaks_df[i+1,2]) / (breaks_df[i,1] - breaks_df[i+1,1])
  b = breaks_df[i,2] - (m * breaks_df[i,1])
  d_eq[d >= breaks_df[i,1] & d <= breaks_df[i+1,1]] <- d[d >= breaks_df[i,1] & d <= breaks_df[i+1,1]]*m + b
  
  for (i in 2:(nrow(breaks_df)-1)){
    m = (breaks_df[i,2] - breaks_df[i+1,2]) / (breaks_df[i,1] - breaks_df[i+1,1])
    b = breaks_df[i,2] - (m * breaks_df[i,1])
    d_eq[d > breaks_df[i,1] & d <= breaks_df[i+1,1]] <- d[d > breaks_df[i,1] & d <= breaks_df[i+1,1]]*m + b
  }
  return(d_eq)
}

# returns vector of the sizes of the nodes in node order
node_sizes <- function(gm){
  unlist(lapply(gm$nodes,length))
}