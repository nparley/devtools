#' @export
#' @param log_dir Directory in which to save logs
#' @rdname revdep_check
revdep_check_save_logs <- function(check_dir, log_dir = "revdep") {
  stopifnot(file.exists(log_dir))

  save_one <- function(pkg, path) {
    out <- file.path(log_dir, pkg)
    dir.create(out, showWarnings = FALSE)

    logs <- check_logs(path)
    new_dirs <- setdiff(unique(dirname(logs)), ".")
    if (length(new_dirs) > 0) {
      dir.create(file.path(out, new_dirs), recursive = TRUE, showWarnings = FALSE)
    }

    file.copy(file.path(path, logs), file.path(out, logs))

    desc <- check_description(path)
    write_dcf(file.path(out, "DESCRIPTION"), desc[c("Package", "Version", "Maintainer")])
  }

  pkgs <- check_dirs(check_dir)
  Map(save_one, names(pkgs), pkgs)
  invisible()
}

#' @rdname revdep_check
#' @export
revdep_check_summary <- function(check_dir) {
  pkgs <- check_dirs(check_dir)

  summaries <- vapply(pkgs, check_summary_package, character(1))
  paste(summaries, collapse = "\n")
}

check_summary_package <- function(path) {
  pkg <- check_description(path)

  header <- paste0("## ", pkg$Package, " (", pkg$Version, ")\n")

  failures <- check_failures(path)
  if (length(failures) == 0) {
    status <- "__OK__\n"
  } else {
    status <- paste0(
      "* \n",
      "    ```\n",
      indent(failures), "\n",
      "    ```\n", collapse = "")
  }

  time <- paste0("Completed in ", check_time(path), "s\n")

  paste0(header, "\n", status)
}

indent <- function(x, spaces = 4) {
  ind <- paste(rep(" ", spaces), collapse = "")
  paste0(ind, gsub("\n", paste0("\n", ind), x, fixed = TRUE))
}

check_dirs <- function(path) {
  checkdirs <- list.dirs(path, recursive = FALSE, full.names = TRUE)
  checkdirs <- checkdirs[grepl("\\.Rcheck$", checkdirs)]
  names(checkdirs) <- sub("\\.Rcheck$", "", basename(checkdirs))

  checkdirs
}

check_description <- function(path) {
  pkgname <- gsub("\\.Rcheck$", "", basename(path))
  read_dcf(file.path(path, "00_pkg_src", pkgname, "DESCRIPTION"))
}

check_time <- function(path) {
  checktimes <- file.path(path, "check-time.txt")
  scan(checktimes, list(1L, "", 1), quiet = TRUE)[[3]]
}

check_logs <- function(path) {
  paths <- dir(path, recursive = TRUE)
  paths[grepl("(fail|out|log)$", paths)]
}

check_failures <- function(path, error = TRUE, warning = TRUE, note = FALSE) {
  check_dir <- file.path(path, "00check.log")
  check_log <- paste(readLines(check_dir), collapse = "\n")

  # Strip off trailing NOTE and WARNING messages
  check_log <- gsub("^NOTE: There was .*\n$", "", check_log)
  check_log <- gsub("^WARNING: There was .*\n$", "", check_log)

  pieces <- strsplit(check_log, "\n\\* ")[[1]]

  is_error <- grepl("... ERROR", pieces)
  is_warn  <- grepl("... WARN", pieces)
  is_note  <- grepl("... NOTE", pieces)
  is_problem <- (error & is_error) | (warning & is_warn) | (note & is_note)

  problems <- grepl("... (WARN|ERROR|NOTE)", pieces)
  cran_version <- grepl("CRAN incoming feasibility", pieces)

  pieces[is_problem & !cran_version]
}