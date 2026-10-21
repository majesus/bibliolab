## Test environment for bibliolab 5.0.5

* Windows 11, R 4.6.1: source tarball built with `R CMD build`; checked with
  `R CMD check --as-cran`, including the PDF and HTML manuals, examples,
  `--run-donttest`, tests and vignette.
* Result: 0 ERRORs, 0 WARNINGs, 1 NOTE. The NOTE is the expected
  "New submission" incoming check.
* The complete local `testthat::test_local()` suite also passed with 5.0.5
  installed in a temporary library. One test requiring an externally
  downloaded UDPipe model was skipped because `BIBLIOLAB_TEST_MODEL` was not
  configured.
* A supplementary Windows R 4.2.3 check installed the package and passed
  its examples, tests and vignette. It reported one warning from that older
  Windows R syntax check while translating escaped Unicode UI strings to
  native encoding, and one note because three suggested packages were not
  installed in that R library. No source syntax or test failure was reported.

## Notes for CRAN reviewers

* This is a first submission. The Shiny application is not launched in
  examples or CRAN tests; server modules are covered by `shiny::testServer()`
  tests outside CRAN.
* UDPipe models are not bundled or downloaded by installation, examples or
  tests. `download_language_model()` acts only after an explicit user request
  and explains the external model license. The model source, MD5 and license
  are recorded when used.
* Optional packages are guarded by `requireNamespace()`. The application
  computes locally and does not require an Internet connection to start.
