# No se abre un navegador real: se registra que via de apertura se invocaria.
windows_browser_fixture <- function(native_error = FALSE, fallback_error = FALSE) {
  calls <- new.env(parent = emptyenv())
  calls$native <- character(); calls$fallback <- character()
  opener <- bibliolab:::app_open_url
  scope <- new.env(parent = environment(opener))
  scope$Sys.info <- function() c(sysname = "Windows")
  scope$get0 <- function(x, envir, inherits) {
    native <- base::get0(x, envir = envir, inherits = inherits)
    if (!is.function(native)) return(NULL)
    function(url) {
      calls$native <- c(calls$native, url)
      if (native_error) stop("La apertura de Windows ha fallado")
      invisible(NULL)
    }
  }
  environment(opener) <- scope
  list(open = opener, calls = calls, fallback = function(url) {
    calls$fallback <- c(calls$fallback, url)
    if (fallback_error) stop("La apertura alternativa ha fallado")
    invisible(NULL)
  })
}

test_that("Windows usa shell.exec de base antes de la opcion browser", {
  skip_if_not(identical(Sys.info()[["sysname"]], "Windows"))
  f <- windows_browser_fixture()
  testthat::local_mocked_bindings(browseURL = f$fallback, .package = "utils")
  url <- "http://127.0.0.1:3388"
  expect_true(suppressMessages(f$open(url)))
  expect_identical(f$calls$native, url)
  expect_length(f$calls$fallback, 0L)
})

test_that("si Windows no puede abrir la URL se intenta browseURL", {
  skip_if_not(identical(Sys.info()[["sysname"]], "Windows"))
  f <- windows_browser_fixture(native_error = TRUE)
  testthat::local_mocked_bindings(browseURL = f$fallback, .package = "utils")
  url <- "http://127.0.0.1:3388"
  expect_true(suppressMessages(f$open(url)))
  expect_identical(f$calls$native, url)
  expect_identical(f$calls$fallback, url)
})

test_that("el fallo de ambas vias de apertura se informa sin detener Shiny", {
  skip_if_not(identical(Sys.info()[["sysname"]], "Windows"))
  f <- windows_browser_fixture(native_error = TRUE, fallback_error = TRUE)
  testthat::local_mocked_bindings(browseURL = f$fallback, .package = "utils")
  expect_message(opened <- f$open("http://127.0.0.1:3388"), "No se pudo abrir")
  expect_false(opened)
})
