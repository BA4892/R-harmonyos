#!/bin/sh
# Batch fix concat files for packages that need Collate ordering
# Usage: cd /storage/Users/currentUser/R-harmonyos && sh build-fix-concat.sh

BUILD_LIB="/storage/Users/currentUser/R-harmonyos/build/library"

# Read Collate from DESCRIPTION and rebuild concat file
rebuild_concat() {
    PKG="$1"
    RDIR="$BUILD_LIB/$PKG/R"
    DESC="$BUILD_LIB/$PKG/DESCRIPTION"
    CONCAT="$RDIR/$PKG"

    if [ ! -f "$DESC" ]; then
        echo "SKIP $PKG: no DESCRIPTION"
        return 1
    fi

    # Extract Collate line and subsequent continuation lines
    # Collate format: 'Collate: ' followed by file list with continuations
    FILES=$(sed -n '/^Collate:/,/^[^ ]/{ s/^Collate: //; /^[A-Za-z]/q; p; }' "$DESC" | \
            sed 's/^Collate: //' | \
            tr -d "\n" | \
            sed "s/'//g" | \
            tr "'" " " | \
            sed 's/  */ /g')

    # Alternative: use awk to extract
    FILES=$(awk '/^Collate:/ { in_coll=1; sub(/^Collate:[ \t]*/, ""); line=$0; if (line ~ /^.$/) exit; }
             in_coll {
                gsub(/^[ \t]+/, "");
                gsub(/'/, "");
                printf "%s", $0;
                if (!/\\\\$/) exit;
             }' "$DESC")

    echo "Processing $PKG with Collate order..."

    # Build file list - split quoted strings
    # Actually, let me use R to parse the Collate field properly
}

# Use R to parse Collate and rebuild concat files
/usr/bin/env R --vanilla << 'REOF' 2>/dev/null || /storage/Users/currentUser/R-harmonyos/build/bin/R --vanilla << 'REOF'
build_lib <- "/storage/Users/currentUser/R-harmonyos/build/library"

# Packages that need concat rebuilding due to Collate ordering
pkgs <- c(
  "sp", "paws.common", "nanotime", "proxy", "checkmate", "xml2",
  "fontquiver", "openxlsx", "assertthat", "knitr", "robustlmm", "rugarch"
)

# Packages that have sysdata.rda and may need explicit loading
sysdata_pkgs <- c()

for (pkg in pkgs) {
  rdir <- file.path(build_lib, pkg, "R")
  desc <- file.path(build_lib, pkg, "DESCRIPTION")
  concat <- file.path(rdir, pkg)

  if (!file.exists(desc)) {
    cat(sprintf("SKIP %s: no DESCRIPTION\n", pkg))
    next
  }

  # Read DESCRIPTION and get Collate field
  dcf <- read.dcf(desc, all = TRUE)
  collate <- dcf[, "Collate"]

  if (is.na(collate)) {
    cat(sprintf("SKIP %s: no Collate field\n", pkg))
    next
  }

  # Parse Collate: split by whitespace, remove quotes
  files <- strsplit(gsub("'", "", collate), "[[:space:]]+")[[1]]
  files <- files[nchar(files) > 0]

  cat(sprintf("\n%s: %d files in Collate\n", pkg, length(files)))
  cat(sprintf("  Files: %s\n", paste(files, collapse=", ")))

  # Check that all files exist
  missing <- files[!file.exists(file.path(rdir, files))]
  if (length(missing) > 0) {
    cat(sprintf("  MISSING: %s\n", paste(missing, collapse=", ")))
    # Try to find them
    for (f in missing) {
      found <- list.files(rdir, pattern = paste0("^", f, "$"), recursive = TRUE)
      if (length(found) > 0) {
        cat(sprintf("  Found %s at %s\n", f, found[1]))
      }
    }
    next
  }

  # Build concat file content
  content <- ""
  for (f in files) {
    fpath <- file.path(rdir, f)
    code <- readLines(fpath, warn = FALSE)
    content <- paste0(content, paste(code, collapse = "\n"), "\n")
  }

  # Write concat file
  writeLines(content, concat)
  cat(sprintf("  Written %d lines to %s\n", length(strsplit(content, "\n")[[1]]), concat))

  # Check for sysdata.rda
  if (file.exists(file.path(rdir, "sysdata.rda"))) {
    cat(sprintf("  Has sysdata.rda - need to add load()\n"))
    sysdata_pkgs <- c(sysdata_pkgs, pkg)
  }
}

if (length(sysdata_pkgs) > 0) {
  cat(sprintf("\nPackages with sysdata.rda that may need loading: %s\n",
      paste(sysdata_pkgs, collapse=", ")))
}
REOF
