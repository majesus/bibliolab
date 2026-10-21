## Test environment for bibliolab 5.0.6

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
