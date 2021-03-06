#'  Add rows corresponding to gaps in some variable
#'
#' @param x A data.table
#' @param ... Variables to keep (beyond the by and along_with variable). Default to all variables. See the \link[dplyr]{select} documentation.
#' @param along_with Numeric variable along which gaps should be filled. Default to last key. ee the \link[dplyr]{select} documentation.
#' @param by Variables by which to group. Default to keys (or to keys minus last if along_with is unspecified). ee the \link[dplyr]{select} documentation.
#' @param units Deprecated. Use elapsed dates.
#' @param full  A boolean. When full = FALSE (default) rows are filled with respect to min and max of \code{...} within each group. When full = TRUE, rows are filled with respect to min and max of \code{...} in the whole datasets. 
#' @param roll When roll is a positive number, this limits how far values are carried forward. roll=TRUE is equivalent to roll=+Inf. When roll is a negative number, values are rolled backwards; i.e., next observation carried backwards (NOCB). Use -Inf for unlimited roll back. When roll is "nearest", the nearest value is used.
#' @param rollends  A logical vector length 2 (a single logical is recycled). When rolling forward (e.g. roll=TRUE) if a value is past the last observation within each group defined by the join columns, rollends[2]=TRUE will roll the last value forwards. rollends[1]=TRUE will roll the first value backwards if the value is before it. If rollends=FALSE the value of i must fall in a gap in x but not after the end or before the beginning of the data, for that group defined by all but the last join column. When roll is a finite number, that limit is also applied when rolling the end
#' @param vars Used to work around non-standard evaluation.
#' @examples
#' library(data.table)
#' DT <- data.table(
#'     id    = c(1, 1, 1, 2),
#'     year  = c(1992, 1989, 1991, 1992),
#'     value = c(4.1, 4.5, 3.3, 3.2)
#' )
#' fill_time(DT, value, along_with = year, by = id)
#' library(lubridate)
#' DT[, date:= mdy(c("03/01/1992", "04/03/1992", "07/15/1992", "08/21/1992"))]
#' DT[, datem :=  as.monthly(date)]
#' fill_time(DT, value, along_with = datem , by = id)
#' fill_time(DT, value, along_with = datem , by = id, roll = "nearest")


#' @export
fill_time <- function(x, ..., along_with, by = NULL, full = FALSE, roll = FALSE, rollends = if (roll=="nearest") c(TRUE,TRUE)
                     else if (roll>=0) c(FALSE,TRUE)
                     else c(TRUE,FALSE),  units = NULL) {
  fill_time_(x, vars = lazy_dots(...), along_with = substitute(along_with), units = units, by = substitute(by), full = full, roll = roll, rollends = rollends)
}

#' @export
#' @rdname fill_time
fill_time_ <- function(x, vars, along_with, by = NULL, full = FALSE, roll = FALSE, rollends = if (roll=="nearest") c(TRUE,TRUE)
                      else if (roll>=0) c(FALSE,TRUE)
                      else c(TRUE,FALSE), units = NULL) {
  stopifnot(is.data.table(x))
  along_with  <- names(select_vars_(names(x), along_with ))
  byvars <- names(select_vars_(names(x), by, exclude = along_with))
  if (!length(byvars) & (!length(along_with))){
    byvars <- head(key(x),-1)
    along_with <- tail(key(x),1)
    if (!length(along_with)) stop("along_with is not specified but x is not keyed")
    
  } else if (!length(byvars)){
    byvars <- key(x)
  } else if (!length(along_with)){
    stop("When by is specified, along_with must also be specified")
  }
  dots <- lazyeval::all_dots(vars, all_named = TRUE)
  vars <- names(select_vars_(names(x), dots, exclude = c(byvars, along_with)))
  if (length(vars) == 0) {
    vars <- setdiff(names(x),c(byvars, along_with))
  }
  isna <- eval(substitute(x[,sum(is.na(t))], list(t = as.name(along_with))))
  if (isna>0) stop("Variable along_with has missing values" ,call. = FALSE)
  if (anyDuplicated(x, by = c(byvars,along_with))) stop(paste0(paste(byvars, collapse = ","),", ",along_with," do not uniquely identify observations"), call. = FALSE)
  if (is.null(units)){
    units <-1L
  } else{
    warning(paste0("units is deprecated. In the future, convert to elapsed date with as(",units,")"))
    units <- match.arg(units, c("second", "minute", "hour", "day", "week", "month", "quarter", "year"))
  }
  if (!full){
    if (length(byvars)){
      call <- substitute(x[, list(seq(min(t, na.rm = TRUE), max(t, na.rm = TRUE), by = units)), by = c(byvars)], list(t = as.name(along_with)))
    } else{
      call <- substitute(x[, list(seq(min(t, na.rm = TRUE), max(t, na.rm = TRUE), by = units))], list(t = as.name(along_with)))
    }
  } else{
    a <- eval(substitute(x[,min(t, na.rm = TRUE)], list(t = as.name(along_with))))
    b <- eval(substitute(x[,max(t, na.rm = TRUE)], list(t = as.name(along_with))))
    if (length(byvars)){
      call <- substitute(x[, list(seq(a, b, by = units)), by = c(byvars)], list(a = a, b = b))
    } else{
      call <- substitute(x[, list(seq(a, b, by = units))], list(a = a, b = b))
    }
  }
  ans  <- eval(call)
  setnames(ans, c(byvars, along_with))
  for (name in names(attributes(get(along_with,x)))){
    setattr(ans[[along_with]], name, attributes(get(along_with, x))[[name]]) 
  }
  setkeyv(ans, c(byvars, along_with))
  x <- x[, c(byvars, along_with, vars), with = FALSE]
  setkeyv(x, c(byvars, along_with))
  x <- x[ans, allow.cartesian = TRUE, roll = roll, rollends = rollends]
  x
}

