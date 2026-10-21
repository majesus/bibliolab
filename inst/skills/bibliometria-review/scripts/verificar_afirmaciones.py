#!/usr/bin/env python3
"""Verifica cifras contra CSV UTF-8 con separador ';', sin modificar archivos.
Uso: python verificar_afirmaciones.py CARPETA registro.csv [--tol 0.005]
El conteo de filas y únicos es exacto; las demás cifras usan tolerancia relativa.
'inspeccion' requiere revisión humana y nunca se cuenta como cálculo verificado.
"""
import argparse
import csv
import math
import re
import statistics
import sys
from pathlib import Path

AUSENTES = {"", "NA", "NAN", "NULL", "N/A"}
REGLAS = {"n_filas", "suma", "media", "mediana", "max", "min", "n_unicos", "celda", "proporcion", "inspeccion"}

def numero(valor):
    texto = str(valor).strip()
    if texto.startswith("'"):
        texto = texto[1:]
    if texto.upper() in AUSENTES:
        return None
    porcentaje = texto.endswith("%")
    if porcentaje:
        texto = texto[:-1].strip()
    if "," in texto and "." in texto:
        raise ValueError("numero ambiguo: no se infieren separadores de miles")
    try:
        n = float(texto.replace(",", "."))
    except ValueError:
        raise ValueError("valor no numerico")
    if not math.isfinite(n):
        raise ValueError("numero no finito")
    return n / 100 if porcentaje else n

def leer_csv(ruta):
    with open(ruta, encoding="utf-8-sig", newline="") as fh:
        lector = csv.DictReader(fh, delimiter=";", restkey="_exceso")
        campos = lector.fieldnames
        if not campos or len(campos) != len(set(campos)) or any(not c for c in campos):
            raise ValueError("cabecera vacia o duplicada")
        filas = list(lector)
    if any("_exceso" in f or any(v is None for v in f.values()) for f in filas):
        raise ValueError("columnas distintas de la cabecera; entrecomille los ';' del texto")
    return campos, filas

def archivo_seguro(carpeta, archivo):
    if not archivo or Path(archivo).is_absolute():
        raise ValueError("archivo debe ser una ruta relativa dentro de la entrega")
    raiz = Path(carpeta).resolve()
    ruta = (raiz / archivo).resolve()
    try:
        ruta.relative_to(raiz)
    except ValueError:
        raise ValueError("archivo fuera de la entrega")
    if ruta.suffix.lower() != ".csv":
        raise ValueError("el recalculo requiere un archivo CSV")
    return ruta

def calcular(campos, filas, r):
    regla = r.get("regla", "").strip()
    if regla not in REGLAS - {"inspeccion"}:
        raise ValueError("regla desconocida")
    col = r.get("columna", "")
    fc, fv = r.get("filtro_columna", ""), r.get("filtro_valor", "")
    if fc and fc not in campos:
        raise ValueError("columna de filtro inexistente: " + fc)
    seleccion = [f for f in filas if str(f[fc]).removeprefix("'") == fv] if fc else filas
    if regla == "n_filas":
        return len(seleccion)
    if regla == "proporcion":
        if not fc:
            raise ValueError("proporcion requiere filtro y denominador de todas las filas")
        if not filas:
            raise ValueError("proporcion con denominador cero")
        return len(seleccion) / len(filas)
    if col not in campos:
        raise ValueError("columna inexistente: " + col)
    if regla == "n_unicos":
        return len({f[col].removeprefix("'") for f in seleccion if f[col].strip().upper() not in AUSENTES})
    if regla == "celda":
        if len(seleccion) != 1:
            raise ValueError("celda requiere exactamente una fila")
        valor = seleccion[0][col]
        if valor.strip().upper() in AUSENTES:
            raise ValueError("celda con dato ausente")
        try:
            return numero(valor)
        except ValueError:
            # Non-finite numbers are not accepted as ordinary text.
            if re.match(r"^[+-]?(?:\d|\.\d)", valor.strip()) or valor.strip().lower() in {"inf", "+inf", "-inf", "infinity", "+infinity", "-infinity"}:
                raise
            return valor.removeprefix("'")
    valores = [numero(f[col]) for f in seleccion]
    validos = [v for v in valores if v is not None]
    if not validos:
        raise ValueError("sin valores numericos validos; los ausentes no son ceros")
    return {"suma": sum, "media": statistics.fmean, "mediana": statistics.median,
            "max": max, "min": min}[regla](validos)

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("carpeta")
    parser.add_argument("registro")
    parser.add_argument("--tol", type=float, default=0.005)
    args = parser.parse_args(argv)
    if not math.isfinite(args.tol) or args.tol < 0:
        parser.error("--tol debe ser finita y no negativa")
    try:
        campos, reclamos = leer_csv(args.registro)
        requeridos = {"id", "archivo", "columna", "regla", "valor_declarado"}
        if not requeridos.issubset(campos):
            raise ValueError("faltan columnas: " + ", ".join(sorted(requeridos-set(campos))))
        if not reclamos:
            raise ValueError("registro sin afirmaciones")
    except (OSError, ValueError, csv.Error) as exc:
        print("Registro no valido: " + str(exc), file=sys.stderr)
        return 2
    salida = csv.writer(sys.stdout, delimiter=";", lineterminator="\n")
    salida.writerow(["id", "estado", "declarado", "recalculado", "detalle"])
    cache, problemas, manuales, correctas = {}, 0, 0, 0
    for r in reclamos:
        declarado, regla = r["valor_declarado"], r["regla"].strip()
        if regla == "inspeccion":
            manuales += 1
            salida.writerow([r["id"], "REVISION MANUAL", declarado, "", "no recalculada ni inspeccionada por este script"])
            continue
        rec = ""
        try:
            ruta = archivo_seguro(args.carpeta, r["archivo"])
            if ruta not in cache:
                cache[ruta] = leer_csv(ruta)
            rec = calcular(*cache[ruta], r)
            if isinstance(rec, str):
                ok = rec.strip() == declarado.strip()
            else:
                d = numero(declarado)
                if d is None:
                    raise ValueError("valor declarado ausente")
                ok = (rec == d) if regla in {"n_filas", "n_unicos"} else math.isclose(rec, d, rel_tol=args.tol, abs_tol=1e-9)
            estado = "OK" if ok else "DISCREPANCIA"
            detalle = "" if ok else "no coincide con la cifra declarada"
        except (OSError, ValueError, csv.Error, KeyError) as exc:
            estado, detalle = "NO VERIFICABLE", str(exc)
        correctas += estado == "OK"
        problemas += estado != "OK"
        salida.writerow([r["id"], estado, declarado, rec, detalle])
    print(f"{correctas}/{len(reclamos)} recalculadas sin discrepancia; {manuales} requieren revision manual; {problemas} con problema. Tolerancia relativa: {args.tol}; conteos exactos.", file=sys.stderr)
    return 1 if problemas else 0

if __name__ == "__main__":
    sys.exit(main())
