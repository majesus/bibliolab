## Validation of bibliolab 5.0.8

Unlike 5.0.7, this version changes R code: it applies the corrections of the
22 October 2026 audit (see NEWS.md and dev/HOJA_DE_RUTA_AUDITORIA.md). It adds
regression tests in tests/testthat/test-auditoria-506.R.

Checks run before submission preparation:

* Linux, R 4.4.3: the full testthat suite passed (213 test blocks, 0 failures)
  with sources loaded and, for the process-based reproduction tests, with the
  package installed in a temporary library. R CMD check of the tarball
  (--no-manual, vignettes not built) reported no WARNINGs or ERRORs; its one NOTE
  was the optional package cld2 not being installed in that environment.
* The GitHub Actions workflows (R-CMD-check on Linux, macOS and Windows with R
  release, oldrel, devel and 4.1.0, and the source tarball) passed on the
  integration branch before merging.

Pending before submission: the local R CMD check --as-cran --run-donttest on
Windows with the final tarball, and the Win-builder report. Neither is claimed here.

## Validation of bibliolab 5.0.7 (previous)

This version adds methodological references to DESCRIPTION and a reproducible
source-package workflow. The only change to R code is the version constant.
The numerical implementations and regression tests audited in 5.0.6 are unchanged.

The full local suite also passed on 5.0.7: 190 tests, 1,263 expectations,
with no failures, warnings or skips, using the isolated installed 5.0.7 package.

The CRAN candidate workflow builds with the current R release, checks that
exact tarball with --as-cran --run-donttest (including the PDF manual), and
retains the checked archive, SHA256 checksum, build environment and check logs.
Results are available at:
https://github.com/majesus/bibliolab/actions/workflows/cran-candidate.yaml

Win-builder results are not claimed until the returned report is available.

## Previous local validation (bibliolab 5.0.6)

* Windows 11, R 4.4.1 (UCRT), UTF-8 locale, 21 October 2026.
* The source tarball was built with R CMD build and checked with
  R CMD check --as-cran --run-donttest, including examples, tests,
  the vignette, and the PDF and HTML manuals.
* Result: 0 ERRORs, 0 WARNINGs, 2 NOTEs:
  - New submission (expected for a first submission).
  - unable to verify current time (external clock verification was
    unavailable in this environment; the check was not disabled).
* The complete testthat::test_local() suite passed: 190 tests and
  1,263 expectations, with no failures, warnings or skips. A real Spanish
  UDPipe model was supplied through BIBLIOLAB_TEST_MODEL for the optional
  model-integrity test. No model was added to the package.
* The tarball inventory was checked explicitly: no tmp directory,
  debug.log, Git metadata or audit/development artifacts are included.

## Continuous integration

The R-CMD-check workflow covers Linux with R release, oldrel-1 and devel,
macOS release, Windows release, and hard-dependency checks with R 4.1.0
and R release. Results for the exact commit are available at:
https://github.com/majesus/bibliolab/actions/workflows/R-CMD-check.yaml

## Notes for CRAN reviewers

* This is a first submission. The Shiny application is not launched by
  examples or CRAN tests. Server modules are exercised with
  shiny::testServer() outside CRAN.
* UDPipe models are not bundled or downloaded by installation, examples
  or tests. download_language_model() acts only after an explicit user
  request and explains the external model license. Model provenance,
  MD5 and license are recorded when used.
* Optional packages are guarded by requireNamespace(). The application
  computes locally and does not require an Internet connection to start.
* Version 5.0.6 adds regression tests for empty CSV headers and integer
  validation in LDA selection, and excludes local temporary files and
  Git worktree metadata from source packages.
