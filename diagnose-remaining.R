# Diagnose remaining packages that need .rdb files
library_dir <- "/storage/Users/currentUser/R-harmonyos/build/library"

# Count .rdb files
pkg_dirs <- list.files(library_dir)
total_with_r_code <- 0
total_with_rdb <- 0
missing_rdb <- character()
missing_so <- character()
cxx_errors <- character()

for (pkg in sort(pkg_dirs)) {
  pkg_path <- file.path(library_dir, pkg)
  r_dir <- file.path(pkg_path, "R")
  if (!dir.exists(r_dir)) next

  r_files <- list.files(r_dir, pattern = "\\.(R|r|q)$")
  if (length(r_files) == 0) next

  total_with_r_code <- total_with_r_code + 1
  rdb_files <- list.files(r_dir, pattern = "\\.rdb$")
  if (length(rdb_files) > 0) {
    total_with_rdb <- total_with_rdb + 1
    next
  }

  # Package missing .rdb — try loading and categorize
  result <- tryCatch({
    loadNamespace(pkg, lib.loc = library_dir)
    "ok"
  }, error = function(e) {
    conditionMessage(e)
  })

  if (result == "ok") {
    cat("OK-loaded:", pkg, "\n")
  } else {
    # Categorize
    if (grepl("unable to load shared object", result) &&
        grepl("_Znw|_Znam|__cxa|__gnu_cxx|basic_streambuf|__basic_file", result)) {
      cxx_errors <- c(cxx_errors, pkg)
      cat("CXX:", pkg, "-", substr(result, 1, 80), "\n")
    } else if (grepl("shared object.*not found", result)) {
      missing_so <- c(missing_so, pkg)
      cat("NO.SO:", pkg, "-", substr(result, 1, 80), "\n")
    } else if (grepl("unable to load R code", result)) {
      cat("R.CODE:", pkg, "-", substr(result, 1, 80), "\n")
      # Check if it's a dependency issue
      for (dep in pkg_dirs) {
        if (grepl(dep, result, fixed = TRUE) && dep != pkg) {
          cat("  -> depends on broken:", dep, "\n")
        }
      }
    } else if (grepl("there is no package called", result)) {
      cat("MISSING.DEP:", pkg, "-", substr(result, 1, 80), "\n")
    } else if (grepl(".onLoad failed", result)) {
      cat("ONLOAD:", pkg, "-", substr(result, 1, 80), "\n")
    } else if (grepl("unknown input format", result)) {
      cat("CORRUPT:", pkg, "-", substr(result, 1, 80), "\n")
    } else {
      cat("OTHER:", pkg, "-", substr(result, 1, 120), "\n")
    }
  }

  # Unload to avoid conflicts
  try(unloadNamespace(pkg), silent = TRUE)
}

cat("\n\n=== SUMMARY ===\n")
cat("Total packages with R code:", total_with_r_code, "\n")
cat("Have .rdb:", total_with_rdb, "\n")
cat("Missing .rdb:", total_with_r_code - total_with_rdb, "\n")
cat("C++ errors:", length(cxx_errors), "\n")
if (length(cxx_errors) > 0) cat("  ", paste(cxx_errors, collapse = " "), "\n")
