test_that("jsd_shift vale 0 para distribuciones identicas y 1 para disjuntas", {
  a <- c(x = 3, y = 1, z = 1)
  expect_equal(jsd_shift(a, a)$jsd, 0)
  expect_equal(jsd_shift(c(a = 5), c(b = 5))$jsd, 1)
})

test_that("jsd_shift es simetrica y su distancia es la raiz cuadrada", {
  a <- c(x = 5, y = 2, z = 1)
  b <- c(x = 1, y = 4, w = 3)
  r1 <- jsd_shift(a, b)
  r2 <- jsd_shift(b, a)
  expect_equal(r1$jsd, r2$jsd)
  expect_equal(r1$distancia, sqrt(r1$jsd))
  expect_gt(r1$jsd, 0)
  expect_lt(r1$jsd, 1)
})

test_that("las contribuciones suman la JSD y los porcentajes suman 100", {
  r <- jsd_shift(c(x = 5, y = 2, z = 1), c(x = 1, y = 4, w = 3))
  expect_equal(sum(r$terms$aporte_bits), r$jsd)
  expect_equal(sum(r$terms$aporte_pct), 100)
  expect_true(all(r$terms$direccion %in% c("Mayor en A", "Mayor en B", "Igual")))
})

test_that("jsd_shift rechaza entradas invalidas", {
  expect_error(jsd_shift(c(a = 1), c(1, 2)), "JSD necesita")
  expect_error(jsd_shift(c(a = -1), c(a = 1)), "JSD necesita")
  expect_error(jsd_shift(c(a = 0), c(a = 1)), "JSD necesita")
  expect_error(jsd_shift(c(a = 1, a = 2), c(a = 1)), "JSD necesita")
})

test_that("jsd_uncertainty es reproducible y devuelve la referencia nula", {
  set.seed(1)
  W <- matrix(rpois(60 * 8, 2), 60, 8)
  r1 <- jsd_uncertainty(W, 1:30, 31:60, B = 50, seed = 1)
  r2 <- jsd_uncertainty(W, 1:30, 31:60, B = 50, seed = 1)
  expect_identical(r1$observed, r2$observed)
  expect_identical(r1$p_value, r2$p_value)
  expect_true(all(c("observed", "null_mean", "null_p95", "excess", "p_value", "ci") %in% names(r1)))
  expect_equal(r1$excess, r1$observed - r1$null_mean)
  expect_gte(r1$p_value, 0); expect_lte(r1$p_value, 1)
})
