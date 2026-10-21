#!/usr/bin/env python3
"""Inventario de una entrega de bibliolab (carpeta o .zip).

Uso: python inventario_entrega.py RUTA [--json]

Solo lee. No ejecuta nada de lo que contiene la entrega. Resume version,
procedencia, modelos vigentes, advertencias y pendientes declarados por la
propia herramienta, para que el redactor o revisor parta de hechos y no de
suposiciones. Biblioteca estandar unicamente.
"""
import csv, io, json, re, sys, zipfile
from pathlib import Path

NUCLEO = ["parametros.json", "documentos.csv", "auditoria.csv", "terminos.csv", "indicadores.csv",
          "informe_metodologico.md", "registro_reproducibilidad.json", "entorno_R.txt"]
MODELOS = {  # prefijo de archivo -> nombre del analisis
    "lda_": "LDA", "ca_": "Correspondencias", "acp_": "ACP", "jsd_": "JSD",
    "umap_": "UMAP + HDBSCAN", "hdbscan_": "UMAP + HDBSCAN", "red_": "Red", "spline_": "Spline temporal",
    "subgrafo_": "Subgrafo", "cuaderno_": "Cuaderno de lectura",
}


class Fuente:
    """Acceso uniforme a carpeta o zip."""
    def __init__(self, ruta):
        p = Path(ruta)
        self.zip = zipfile.ZipFile(p) if p.is_file() and p.suffix == ".zip" else None
        if self.zip:
            nombres = [n for n in self.zip.namelist() if not n.endswith("/")]
            raiz = ""
            if nombres and all(n.startswith(nombres[0].split("/")[0] + "/") for n in nombres) and "/" in nombres[0]:
                raiz = nombres[0].split("/")[0] + "/"
            self.raiz = raiz
            self.todos = [n[len(raiz):] for n in nombres]
            self.archivos = sorted(n[len(raiz):] for n in nombres if "/" not in n[len(raiz):])
        else:
            self.dir = p
            self.todos = [f.relative_to(p).as_posix() for f in p.rglob("*") if f.is_file()]
            self.archivos = sorted(f.name for f in p.iterdir() if f.is_file())

    def texto(self, nombre):
        if nombre not in self.archivos:
            return None
        datos = self.zip.read(self.raiz + nombre) if self.zip else (self.dir / nombre).read_bytes()
        return datos.decode("utf-8-sig", errors="replace")


def csv_filas(fuente, nombre):
    t = fuente.texto(nombre)
    if t is None:
        return None
    return list(csv.DictReader(io.StringIO(t), delimiter=";"))


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    f = Fuente(sys.argv[1])
    salida = {"archivos": len(f.archivos)}
    par = json.loads(f.texto("parametros.json") or "{}")
    reg = json.loads(f.texto("registro_reproducibilidad.json") or "{}")
    salida["version_bibliolab"] = par.get("version") or reg.get("software", {}).get("bibliolab")
    salida["practica_sintetica"] = par.get("practica_sintetica", reg.get("datos", {}).get("practica_sintetica"))
    salida["fuente"] = par.get("fuente") or reg.get("datos", {}).get("fuente") or "(no registrada)"
    salida["md5_entrada"] = reg.get("datos", {}).get("md5_archivo")
    salida["pregunta_registrada"] = par.get("pregunta") or "(no registrada)"
    salida["procedencia_documentada"] = par.get("procedencia") or None
    aud = csv_filas(f, "auditoria.csv") or []
    salida["flujo_seleccion"] = [(r.get("etapa"), r.get("documentos")) for r in aud]
    vigentes = {}
    for nombre in f.archivos:
        for pref, modelo in MODELOS.items():
            if nombre.startswith(pref) and nombre.endswith(".csv"):
                vigentes.setdefault(modelo, []).append(nombre)
    salida["analisis_con_tablas"] = {k: len(v) for k, v in sorted(vigentes.items())}
    rm = csv_filas(f, "resumen_modelos.csv") or []
    salida["resumen_modelos"] = [(r.get("metodo"), r.get("estado")) for r in rm]
    salida["nucleo_ausente"] = [n for n in NUCLEO if n not in f.archivos]
    salida["advertencias_herramienta"] = par.get("advertencias") or []
    md = f.texto("informe_metodologico.md") or ""
    pend = []
    for linea in md.splitlines():
        if re.search(r"\|\s*(Pendiente|No ejecutada)\s*\|", linea):
            pend.append(re.sub(r"\s+", " ", linea.strip(" |")))
        if linea.strip().startswith("- [ ]"):
            pend.append(linea.strip()[2:])
    salida["pendientes_declarados"] = pend
    sospechosas = 0
    for nombre in ("documentos.csv", "unidades_textuales.csv"):
        t = f.texto(nombre)
        if t:
            sospechosas += len(re.findall(r'(^|;)"?\'[=+@\-]', t, flags=re.M))
    salida["celdas_neutralizadas_con_apostrofo"] = sospechosas
    salida["carpeta_skills_incluida"] = any(n.startswith("skills/") for n in f.todos)
    if f.zip:
        f.zip.close()
    if "--json" in sys.argv:
        print(json.dumps(salida, ensure_ascii=False, indent=2, default=str))
        return
    print(f"# Inventario de la entrega ({salida['archivos']} archivos en la raiz)\n")
    print(f"- bibliolab: {salida['version_bibliolab']}  |  datos de practica ficticios: {salida['practica_sintetica']}")
    print(f"- fuente: {salida['fuente']}  |  MD5 de entrada: {salida['md5_entrada']}")
    print(f"- pregunta registrada: {salida['pregunta_registrada']!r}")
    print(f"- flujo de seleccion: {salida['flujo_seleccion']}")
    print(f"- analisis con tablas: {salida['analisis_con_tablas']}")
    print(f"- resumen_modelos: {salida['resumen_modelos']}")
    print(f"- nucleo ausente: {salida['nucleo_ausente'] or 'ninguno'}")
    print(f"- celdas neutralizadas (apostrofo): {salida['celdas_neutralizadas_con_apostrofo']}")
    print("\n## Advertencias de la herramienta")
    for a in salida["advertencias_herramienta"] or ["(ninguna registrada)"]:
        print(f"- {a}")
    print("\n## Pendientes declarados (los debe resolver el investigador)")
    for p in salida["pendientes_declarados"] or ["(ninguno detectado: comprobar informe_metodologico.md)"]:
        print(f"- {p}")


if __name__ == "__main__":
    main()
