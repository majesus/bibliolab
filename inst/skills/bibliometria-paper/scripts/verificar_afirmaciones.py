#!/usr/bin/env python3
"""Recalcula afirmaciones numericas contra los CSV completos de una entrega.

Uso: python verificar_afirmaciones.py CARPETA afirmaciones.csv [--tol 0.005]

afirmaciones.csv (UTF-8, separador ';') admite estas columnas:
  id;archivo;columna;regla;filtro_columna;filtro_valor;valor_declarado
Reglas: n_filas, suma, media, mediana, max, min, n_unicos, celda, proporcion
  - celda: exige que el filtro seleccione una sola fila y devuelve su columna.
  - proporcion: filas que cumplen el filtro / filas totales (0-1).
  - inspeccion: la cifra o lectura se tomo directamente de un archivo o es una
    interpretacion; no se recalcula. Se informa como INSPECCIONADA, sin contarse
    como fallo. Pon el detalle en una columna `nota` (sin punto y coma).
Estado resultante: OK, DISCREPANCIA, INSPECCIONADA o NO VERIFICABLE (con el motivo).
Una fila con distinto numero de columnas que la cabecera (tipicamente por un punto y
coma dentro de un texto sin comillas) se informa como FILA MAL FORMADA y no se calcula.
Solo lee; biblioteca estandar unicamente. La tolerancia es relativa.
"""
import csv, statistics, sys
from pathlib import Path


def numero(x):
    x = str(x).strip().lstrip("'").replace("%", "")
    if not x or x.upper() in {"NA", "NAN", "NULL"}:
        return None
    if "," in x and "." not in x:
        x = x.replace(",", ".")
    try:
        return float(x)
    except ValueError:
        return None


def leer(carpeta, archivo, cache={}):
    clave = (str(carpeta), archivo)
    if clave not in cache:
        p = Path(carpeta) / archivo
        if not p.exists():
            cache[clave] = None
        else:
            with open(p, encoding="utf-8-sig", newline="") as fh:
                cache[clave] = list(csv.DictReader(fh, delimiter=";"))
    return cache[clave]


def calcular(filas, r):
    col, regla = r.get("columna", ""), r.get("regla", "").strip()
    fc, fv = r.get("filtro_columna", ""), r.get("filtro_valor", "")
    if fc:
        if fc not in filas[0]:
            raise KeyError(f"columna de filtro inexistente: {fc}")
        sel = [x for x in filas if str(x[fc]).lstrip("'") == fv]
    else:
        sel = filas
    if regla == "n_filas":
        return float(len(sel))
    if regla == "proporcion":
        return len(sel) / len(filas) if filas else None
    if col not in filas[0]:
        raise KeyError(f"columna inexistente: {col}")
    if regla == "celda":
        if len(sel) != 1:
            raise ValueError(f"el filtro selecciona {len(sel)} filas, se esperaba 1")
        v = numero(sel[0][col])
        return v if v is not None else sel[0][col]
    if regla == "n_unicos":
        return float(len({str(x[col]) for x in sel if str(x[col]).strip()}))
    vals = [numero(x[col]) for x in sel]
    vals = [v for v in vals if v is not None]
    if not vals:
        raise ValueError("sin valores numericos validos")
    return {"suma": sum, "media": statistics.fmean, "mediana": statistics.median, "max": max, "min": min}[regla](vals)


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    carpeta, af = sys.argv[1], sys.argv[2]
    tol = float(sys.argv[sys.argv.index("--tol") + 1]) if "--tol" in sys.argv else 0.005
    with open(af, encoding="utf-8-sig", newline="") as fh:
        reclamos = list(csv.DictReader(fh, delimiter=";", restkey="_exceso"))
    malos = 0
    print("id;estado;declarado;recalculado;detalle")
    for r in reclamos:
        rid, decl = r.get("id", "?"), r.get("valor_declarado") or ""
        if "_exceso" in r or any(v is None for v in r.values()):
            malos += 1
            print(f"{rid};FILA MAL FORMADA;;;columnas distintas de la cabecera: entrecomilla o elimina los ';' internos")
            continue
        if (r.get("regla") or "").strip() == "inspeccion":
            print(f"{rid};INSPECCIONADA;{decl};;no recalculada")
            continue
        filas = leer(carpeta, r.get("archivo", ""))
        if filas is None:
            estado, rec, det = "NO VERIFICABLE", "", f"archivo ausente: {r.get('archivo')}"
        elif not filas:
            estado, rec, det = "NO VERIFICABLE", "", "archivo sin filas"
        else:
            try:
                rec = calcular(filas, r)
                d = numero(decl)
                if isinstance(rec, str) or d is None:
                    estado, det = ("OK", "") if str(rec).strip() == decl.strip() else ("DISCREPANCIA", "texto distinto")
                else:
                    ok = abs(rec - d) <= tol * max(abs(d), abs(rec), 1e-12) or abs(rec - d) < 1e-9
                    estado, det = ("OK", "") if ok else ("DISCREPANCIA", f"diferencia {rec - d:+.6g}")
            except Exception as e:  # el motivo se informa, no se oculta
                estado, rec, det = "NO VERIFICABLE", "", f"{type(e).__name__}: {e}"
        if estado != "OK":
            malos += 1
        rec_txt = f"{rec:.6g}" if isinstance(rec, float) else rec
        print(f"{rid};{estado};{decl};{rec_txt};{det}")
    n_insp = sum(1 for r in reclamos if (r.get("regla") or "").strip() == "inspeccion")
    print(f"\n{len(reclamos) - malos - n_insp}/{len(reclamos)} recalculadas sin discrepancia; {n_insp} inspeccionadas; {malos} con problema", file=sys.stderr)
    sys.exit(1 if malos else 0)


if __name__ == "__main__":
    main()
