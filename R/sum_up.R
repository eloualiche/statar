#' Gives summary statistics (Stata command summarize)
#' 
#' @param DT A tbl_dt or tbl_grouped_dt.
#' @param ... Variables to include/exclude in s You can use same specifications as in select. If missing, defaults to all non-grouping variables.
#' @param d Detail is true or not
#' @examples
#' library(data.table)
#' library(dplyr)
#' N <- 100; K <- 10
#' DT <- data.table(
#'   id = 1:N,
#'   v1 =  sample(5, N, TRUE),                          
#'   v2 =  sample(1e6, N, TRUE),                       
#'   v3 =  sample(round(runif(100, max = 100), 4), N, TRUE) 
#' )
#' DT  %>% sum_up
#' DT  %>% sum_up(v3, d=T)
#' DT  %>% filter(v1==1) %>% sum_up(starts_with("v"))
#' @export
sum_up <- function(.data, ..., d = FALSE) {
  s_(.data, vars = lazyeval::lazy_dots(...) , d = d)
}
#' @export
sum_up_ <- function(.data, vars , d = FALSE) {
  if (length(vars) == 0) {
     vars <- lazyeval::lazy_dots(everything())
   }
  vars <- select_vars_(tbl_vars(.data), vars, exclude = as.character(groups(.data)))
  byvars <- as.character(groups(.data))
  .data2 <- select_(.data, .dots = vars)
  invisible(.data2[, describe_matrix(.SD,d = d) , by = byvars, .SDcols = names(.data2)])
}


describe_matrix <- function(M, details = FALSE, na.rm = TRUE, mc.cores=getOption("mc.cores", 2L)){
  # import from stargazer
  .iround <- function(x, decimal.places = 0, round.up.positive = FALSE, 
      simply.output = FALSE,  .format.digit.separator = ",") {
    .format.initial.zero <- TRUE
    .format.until.nonzero.digit <- TRUE
    .format.max.extra.digits <- 2
    .format.digit.separator.where <- c(3)
    .format.ci.separator <- ", "
    .format.round.digits <- 3
    .format.decimal.character <- "."
    .format.dec.mark.align <- FALSE
    .format.dec.mark.align <- TRUE
      x.original <- x
      first.part <- ""
      if (is.na(x) | is.null(x)) {
          return("")
      }
      if (simply.output == TRUE) {
          if (!is.numeric(x)) {
              return(.remove.special.chars(x))
          }
      }
      if (x.original < 0) {
          x <- abs(x)
      }
      if (!is.na(decimal.places)) {
          if ((.format.until.nonzero.digit == FALSE) | (decimal.places <= 
              0)) {
              round.result <- round(x, digits = decimal.places)
          }
          else {
              temp.places <- decimal.places
              if (!.is.all.integers(x)) {
                while ((round(x, digits = temp.places) == 0) & 
                  (temp.places < (decimal.places + .format.max.extra.digits))) {
                  temp.places <- temp.places + 1
                }
              }
              round.result <- round(x, digits = temp.places)
              decimal.places <- temp.places
          }
          if ((round.up.positive == TRUE) & (round.result < 
              x)) {
              if (x > (10^((-1) * (decimal.places + 1)))) {
                round.result <- round.result + 10^((-1) * decimal.places)
              }
              else {
                round.result <- 0
              }
          }
      }
      else {
          round.result <- x
      }
      round.result.char <- as.character(format(round.result, 
          scientific = FALSE))
      split.round.result <- unlist(strsplit(round.result.char, 
          "\\."))
      for (i in seq(from = 1, to = length(.format.digit.separator.where))) {
          if (.format.digit.separator.where[i] <= 0) {
              .format.digit.separator.where[i] <<- -1
          }
      }
      separator.count <- 1
      length.integer.part <- nchar(split.round.result[1])
      digits.in.separated.unit <- 0
      for (i in seq(from = length.integer.part, to = 1)) {
          if ((digits.in.separated.unit == .format.digit.separator.where[separator.count]) & 
              (substr(split.round.result[1], i, i) != "-")) {
              first.part <- paste(.format.digit.separator, 
                first.part, sep = "")
              if (separator.count < length(.format.digit.separator.where)) {
                separator.count <- separator.count + 1
              }
              digits.in.separated.unit <- 0
          }
          first.part <- paste(substr(split.round.result[1], 
              i, i), first.part, sep = "")
          digits.in.separated.unit <- digits.in.separated.unit + 
              1
      }
      if (x.original < 0) {
          if (.format.dec.mark.align == TRUE) {
              first.part <- paste("-", first.part, sep = "")
          }
          else {
              first.part <- paste("$-$", first.part, sep = "")
          }
      }
      if (!is.na(decimal.places)) {
          if (decimal.places <= 0) {
              return(first.part)
          }
      }
      if (.format.initial.zero == FALSE) {
          if ((round.result >= 0) & (round.result < 1)) {
              first.part <- ""
          }
      }
      if (length(split.round.result) == 2) {
          if (is.na(decimal.places)) {
              return(paste(first.part, .format.decimal.character, 
                split.round.result[2], sep = ""))
          }
          if (nchar(split.round.result[2]) < decimal.places) {
              decimal.part <- split.round.result[2]
              for (i in seq(from = 1, to = (decimal.places - 
                nchar(split.round.result[2])))) {
                decimal.part <- paste(decimal.part, "0", sep = "")
              }
              return(paste(first.part, .format.decimal.character, 
                decimal.part, sep = ""))
          }
          else {
              return(paste(first.part, .format.decimal.character, 
                split.round.result[2], sep = ""))
          }
      }
      else if (length(split.round.result) == 1) {
          if (is.na(decimal.places)) {
              return(paste(first.part, .format.decimal.character, 
                decimal.part, sep = ""))
          }
          decimal.part <- ""
          for (i in seq(from = 1, to = decimal.places)) {
              decimal.part <- paste(decimal.part, "0", sep = "")
          }
          return(paste(first.part, .format.decimal.character, 
              decimal.part, sep = ""))
      }
      else {
          return(NULL)
      }
  }
  is.wholenumber <- function(x, tol = .Machine$double.eps^0.5) abs(x - 
      round(x)) < tol
  .is.all.integers <- function(x) {
      if (!is.numeric(x)) {
          return(FALSE)
      }
      if (length(x[!is.na(x)]) == length(is.wholenumber(x)[(!is.na(x)) & 
          (is.wholenumber(x) == TRUE)])) {
          return(TRUE)
      }
      else {
          return(FALSE)
      }
  }


  # Now starts the code 

  if (details==FALSE) {
   sum_mean <-as.data.frame(parallel::mclapply(M ,function(x){a <- sum(is.na(x)) ; c(length(x)-a,a, mean(x,na.rm=na.rm), sd(x,na.rm= na.rm), quantile(x, c(0,1), type = 1, na.rm = na.rm))}))
    sum <- as.matrix(sum_mean)
    rownames(sum) <-  c("N","NA","Mean","Sd","Min","Max")

  } else {
    N <- nrow(M)
    sum_mean <- colMeans(M ,na.rm=na.rm)
    f=function(x,m){
      sum_higher <- colMeans(DT[,list((x-m)^2,(x-m)^3,(x-m)^4)],na.rm=na.rm)
      sum_higher[1] <- sqrt(sum_higher[1])
      sum_higher[2] <- sum_higher[2]/sum_higher[1]^3
      sum_higher[3] <- sum_higher[3]/sum_higher[1]^4
      sum_quantile=quantile(x,c(0,0.01,0.05,0.1,0.25,0.50,0.75,0.9,0.95,0.99,1),type=1,na.rm=na.rm,names=FALSE)
      n_NA <- sum(is.na(x))
      sum <- c(N-n_NA,n_NA,m,sum_higher,sum_quantile)
    }
    sum <- do.call(cbind,parallel::mcMap(f,M,sum_mean))
    rownames(sum) <-  c("N","NA","Mean","Sd","Skewness","Kurtosis","Min","1%","5%","10%","25%","50%","75%","90%","95%","99%","Max")
   # rownames(sum) <- c("Rows","N","Mean","Sd","Skewness","Kurtosis","Min","1%","5%","10%","25%","50%","75%","90%","95%","99%","Max")
  }
  print <- apply(sum,c(1,2),
    function(x){
    if (is.numeric(x)){
      y <- .iround(x,decimal.places=3)
      y <- stringr::str_replace(y,"0+$","")
      if (y==""){
        y <- "0"
      }
      y <- stringr::str_replace(y,"\\.$","")
      y <- stringr::str_replace(y,"-0","0")
    } else{
      y <- x
    }
    y
  })
  print(noquote(format(print,justify="right")),right=TRUE)
}

