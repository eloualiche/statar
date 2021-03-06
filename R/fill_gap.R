#'  Add rows corresponding to gaps in some variable
#'
#' @param x A data frame
#' @param time Numeric variable along which gaps should be filled. Default to last key. See the \link[dplyr]{select} documentation.
#' @param full  A boolean. When full = FALSE (default) rows are filled with respect to min and max of \code{...} within each group. When full = TRUE, rows are filled with respect to min and max of \code{...} in the whole datasets. 
#' @param roll When roll is a positive number, this limits how far values are carried forward. roll=TRUE is equivalent to roll=+Inf. When roll is a negative number, values are rolled backwards; i.e., next observation carried backwards (NOCB). Use -Inf for unlimited roll back. When roll is "nearest", the nearest value is used.
#' @param rollends  A logical vector length 2 (a single logical is recycled). When rolling forward (e.g. roll=TRUE) if a value is past the last observation within each group defined by the join columns, rollends[2]=TRUE will roll the last value forwards. rollends[1]=TRUE will roll the first value backwards if the value is before it. If rollends=FALSE the value of i must fall in a gap in x but not after the end or before the beginning of the data, for that group defined by all but the last join column. When roll is a finite number, that limit is also applied when rolling the end
#' @param vars Used to work around non-standard evaluation.
#' @examples
#' library(lubridate)
#' df <- data_frame(
#'     id    = c(1, 1, 1, 2),
#'     datem  = as.monthly(mdy(c("04/03/1992", "01/04/1992", "03/15/1992", "05/11/1992"))),
#'     value = c(4.1, 4.5, 3.3, 3.2)
#' )
#' df %>% group_by(id) %>% fill_gap(datem)
#' df %>% group_by(id) %>% fill_gap(datem, full = TRUE)
#' df %>% group_by(id) %>% fill_gap(datem, roll = "nearest")
#' df %>% group_by(id) %>% fill_gap(datem, roll = "nearest", full = TRUE)
#' @export
fill_gap <- function(x, ..., full = FALSE, roll = FALSE, rollends = if (roll=="nearest") c(TRUE,TRUE)
             else if (roll>=0) c(FALSE,TRUE)
             else c(TRUE,FALSE)) {
  fill_gap_(x, .dots = lazy_dots(...), full = full, roll = roll, rollends = rollends)
}

#' @export
#' @rdname fill_gap
fill_gap_ <- function(x, ..., .dots, full = FALSE, roll = FALSE, rollends = if (roll=="nearest") c(TRUE,TRUE)
             else if (roll>=0) c(FALSE,TRUE)
             else c(TRUE,FALSE)) {
	byvars <- as.character(groups(x))
	dots <- all_dots(.dots, ..., all_named = TRUE)
	timevar <- select_vars_(names(x), dots, exclude = byvars)
	originalattributes <- attributes(x)$class

	# check byvars, timevar form a panel
	stopifnot(is.panel_(x, timevar))

	# create id x time 
	if (!full){
		ans <- do(x, setNames(data_frame(datem = seq(min(.[[timevar]]), max(.[[timevar]]), by = 1)), timevar))
	}
	else{
		ans <- do(x, setNames(data_frame(datem = seq(min(x[[timevar]]), max(x[[timevar]]), by = 1)), timevar))
	}
	setDT(ans)
	setDT(x)
	for (name in names(attributes(get(timevar, x)))){
		setattr(ans[[timevar]], name, attributes(get(timevar, x))[[name]]) 
	}

	# data.table merge with roll
	setkeyv(ans, c(byvars, timevar))
	setkeyv(x, c(byvars, timevar))
	out <- x[ans, allow.cartesian = TRUE, roll = roll, rollends = rollends]

	# re assign group and class attributes
	out <- group_by_(out, .dots = byvars)
	setattr(out, "class", originalattributes)
	out
}