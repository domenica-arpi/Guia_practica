#!/usr/bin/env python3
"""ETL de referencia de AulaStream.

Replica, con las mismas reglas, lo que el paquete de SSIS debe hacer en el
laboratorio: limpieza de nulos, conversión de tipos, columna derivada de
porcentaje de visualización y carga del modelo estrella.

No reemplaza SQL Server Integration Services. Sirve para comprobar los
conteos antes y después de ejecutar el paquete en el laboratorio.
"""

from __future__ import annotations

import csv
import sqlite3
from collections import Counter
from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
DATOS = RAIZ / "datos"
SALIDA = RAIZ / "salida"
SQLITE = SALIDA / "dw_aula_stream.sqlite"
REPORTE = SALIDA / "validacion.md"

PAISES = {
    "ecuador": "Ecuador",
    "colombia": "Colombia",
    "peru": "Perú",
    "perú": "Perú",
    "mexico": "México",
    "méxico": "México",
    "chile": "Chile",
    "argentina": "Argentina",
    "espana": "España",
    "españa": "España",
    "no especificado": "No especificado",
}

SEGMENTOS = {
    "recurrente": "Recurrente",
    "nuevo": "Nuevo",
    "inactivo": "Inactivo",
}

DISPOSITIVOS = {
    "web": "Web",
    "movil": "Móvil",
    "móvil": "Móvil",
    "smart tv": "Smart TV",
    "smarttv": "Smart TV",
}

MESES = (
    "enero",
    "febrero",
    "marzo",
    "abril",
    "mayo",
    "junio",
    "julio",
    "agosto",
    "septiembre",
    "octubre",
    "noviembre",
    "diciembre",
)

DIAS = (
    "lunes",
    "martes",
    "miércoles",
    "jueves",
    "viernes",
    "sábado",
    "domingo",
)


def colapsar(valor: str | None) -> str:
    if valor is None:
        return ""
    return " ".join(valor.replace("\ufeff", "").split())


def en_blanco(valor: str | None) -> bool:
    texto = colapsar(valor)
    return texto == "" or texto.casefold() == "null"


def titulo_propio(valor: str) -> str:
    return " ".join(parte.capitalize() for parte in colapsar(valor).split(" "))


def pais(valor: str | None) -> str:
    if en_blanco(valor):
        return "No especificado"
    clave = colapsar(valor).casefold()
    return PAISES.get(clave, titulo_propio(valor))


def segmento(valor: str | None) -> str:
    if en_blanco(valor):
        return "No definido"
    return SEGMENTOS.get(colapsar(valor).casefold(), "No definido")


def correo(valor: str | None) -> str:
    if en_blanco(valor) or "@" not in colapsar(valor):
        return "No registrado"
    return colapsar(valor).casefold()


def nombre_persona(valor: str | None) -> str:
    if en_blanco(valor):
        return "Sin nombre"
    return titulo_propio(valor)


def dispositivo(valor: str | None) -> str:
    if en_blanco(valor):
        return "No especificado"
    clave = colapsar(valor).casefold()
    return DISPOSITIVOS.get(clave, colapsar(valor))


def fecha(valor: str | None) -> datetime | None:
    texto = colapsar(valor)
    if texto == "" or texto.casefold() == "null":
        return None
    if "/" in texto:
        partes = texto.split("/")
        if len(partes) != 3 or any(len(parte) == 0 for parte in partes):
            return None
        dia, mes, anio = partes
        texto = f"{anio}-{mes}-{dia}"
    try:
        return datetime.strptime(texto, "%Y-%m-%d")
    except ValueError:
        return None


def duracion_segundos(valor: str | None) -> int | None:
    texto = colapsar(valor)
    if texto == "" or texto.casefold() == "null":
        return None
    minuscula = texto.casefold()
    if "min" in minuscula:
        numero = "".join(caracter if caracter.isdigit() else " " for caracter in minuscula)
        pedazos = [pedazo for pedazo in numero.split() if pedazo]
        if len(pedazos) != 1:
            return None
        return int(pedazos[0]) * 60
    if ":" in texto:
        partes = texto.split(":")
        if not all(parte.isdigit() for parte in partes):
            return None
        numeros = [int(parte) for parte in partes]
        if len(numeros) == 3:
            horas, minutos, segundos = numeros
            return horas * 3600 + minutos * 60 + segundos
        if len(numeros) == 2:
            minutos, segundos = numeros
            return minutos * 60 + segundos
        return None
    if texto.isdigit():
        return int(texto)
    return None


def segundos(valor: str | None) -> int | None:
    texto = colapsar(valor)
    if texto == "" or texto.casefold() == "null":
        return None
    if texto.startswith("-"):
        resto = texto[1:]
        if resto.isdigit():
            return -int(resto)
        return None
    if texto.isdigit():
        return int(texto)
    return None


def porcentaje(vistos: int, duracion: int) -> Decimal:
    if duracion <= 0 or vistos <= 0:
        return Decimal("0.00")
    if vistos >= duracion:
        return Decimal("100.00")
    valor = (Decimal(vistos) * Decimal(100)) / Decimal(duracion)
    return valor.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def leer_csv(nombre: str) -> list[dict[str, str]]:
    ruta = DATOS / nombre
    with ruta.open(encoding="utf-8-sig", newline="") as archivo:
        return list(csv.DictReader(archivo))


def tiempo_de(fecha_valor: datetime) -> dict[str, object]:
    return {
        "tiempo_sk": int(fecha_valor.strftime("%Y%m%d")),
        "fecha": fecha_valor.strftime("%Y-%m-%d"),
        "anio": fecha_valor.year,
        "mes": fecha_valor.month,
        "nombre_mes": MESES[fecha_valor.month - 1],
        "trimestre": (fecha_valor.month - 1) // 3 + 1,
        "dia_semana": DIAS[fecha_valor.weekday()],
    }


def conservar_reciente(
    filas: list[dict[str, object]],
    clave: str,
    campo_fecha: str,
) -> tuple[list[dict[str, object]], list[dict[str, object]]]:
    """Conserva la versión con fecha más reciente y, si empatan, la última del archivo."""
    grupos: dict[object, list[dict[str, object]]] = {}
    for fila in filas:
        grupos.setdefault(fila[clave], []).append(fila)
    vigentes: list[dict[str, object]] = []
    reemplazadas: list[dict[str, object]] = []
    for grupo in grupos.values():
        ordenadas = sorted(
            grupo,
            key=lambda fila: (fila[campo_fecha], fila["fila_origen"]),
        )
        vigentes.append(ordenadas[-1])
        reemplazadas.extend(ordenadas[:-1])
    return vigentes, reemplazadas


def procesar() -> dict[str, object]:
    rechazos: list[dict[str, str]] = []

    usuarios_validos: list[dict[str, object]] = []
    for indice, fila in enumerate(leer_csv("Usuarios.csv"), start=1):
        clave = colapsar(fila["usuario_id"])
        if en_blanco(clave):
            rechazos.append(_rechazo("Usuarios", "(sin clave)", "Clave de negocio vacía", indice))
            continue
        fecha_registro = fecha(fila["fecha_registro"])
        if fecha_registro is None:
            rechazos.append(_rechazo("Usuarios", clave, "Fecha inválida", indice))
            continue
        usuarios_validos.append(
            {
                "usuario_bk": clave,
                "nombre": nombre_persona(fila["nombre"]),
                "correo": correo(fila["correo"]),
                "pais": pais(fila["pais"]),
                "fecha_registro": fecha_registro,
                "segmento": segmento(fila["segmento"]),
                "fila_origen": indice,
            }
        )
    usuarios, usuarios_viejos = conservar_reciente(
        usuarios_validos, "usuario_bk", "fecha_registro"
    )
    for viejo in usuarios_viejos:
        rechazos.append(
            _rechazo(
                "Usuarios",
                str(viejo["usuario_bk"]),
                "Versión anterior reemplazada por un registro más reciente",
                int(viejo["fila_origen"]),
            )
        )

    contenidos_validos: list[dict[str, object]] = []
    for indice, fila in enumerate(leer_csv("Contenidos.csv"), start=1):
        clave = colapsar(fila["contenido_id"])
        if en_blanco(clave):
            rechazos.append(_rechazo("Contenidos", "(sin clave)", "Clave de negocio vacía", indice))
            continue
        duracion = duracion_segundos(fila["duracion"])
        if duracion is None or duracion <= 0:
            rechazos.append(
                _rechazo("Contenidos", clave, "Duración vacía o no interpretable", indice)
            )
            continue
        fecha_publicacion = fecha(fila["fecha_publicacion"])
        if fecha_publicacion is None:
            rechazos.append(
                _rechazo("Contenidos", clave, "Fecha de publicación inválida", indice)
            )
            continue
        categoria = colapsar(fila["categoria"])
        tipo = colapsar(fila["tipo"])
        contenidos_validos.append(
            {
                "contenido_bk": clave,
                "titulo": colapsar(fila["titulo"]) or "Sin título",
                "categoria": categoria or "Sin categoría",
                "duracion_segundos": duracion,
                "tipo": titulo_propio(tipo) if tipo else "No definido",
                "fecha_publicacion": fecha_publicacion,
                "fila_origen": indice,
            }
        )
    contenidos, contenidos_viejos = conservar_reciente(
        contenidos_validos, "contenido_bk", "fecha_publicacion"
    )
    for viejo in contenidos_viejos:
        rechazos.append(
            _rechazo(
                "Contenidos",
                str(viejo["contenido_bk"]),
                "Versión anterior reemplazada por un registro más reciente",
                int(viejo["fila_origen"]),
            )
        )

    usuarios_por_bk = {str(fila["usuario_bk"]): fila for fila in usuarios}
    contenidos_por_bk = {str(fila["contenido_bk"]): fila for fila in contenidos}

    hechos_validos: list[dict[str, object]] = []
    for indice, fila in enumerate(leer_csv("Reproducciones.csv"), start=1):
        clave = colapsar(fila["reproduccion_id"])
        if en_blanco(clave):
            rechazos.append(
                _rechazo("Reproducciones", "(sin clave)", "Clave de negocio vacía", indice)
            )
            continue
        fecha_reproduccion = fecha(fila["fecha"])
        if fecha_reproduccion is None:
            rechazos.append(_rechazo("Reproducciones", clave, "Fecha inválida", indice))
            continue
        vistos = segundos(fila["segundos_vistos"])
        if vistos is None or vistos < 0:
            rechazos.append(
                _rechazo(
                    "Reproducciones",
                    clave,
                    "Segundos vistos no numéricos o negativos",
                    indice,
                )
            )
            continue
        usuario_bk = colapsar(fila["usuario_id"])
        contenido_bk = colapsar(fila["contenido_id"])
        if usuario_bk not in usuarios_por_bk:
            rechazos.append(
                _rechazo(
                    "Reproducciones",
                    clave,
                    "Usuario no existe en la dimensión",
                    indice,
                )
            )
            continue
        if contenido_bk not in contenidos_por_bk:
            rechazos.append(
                _rechazo(
                    "Reproducciones",
                    clave,
                    "Contenido no existe en la dimensión",
                    indice,
                )
            )
            continue
        contenido = contenidos_por_bk[contenido_bk]
        duracion = int(contenido["duracion_segundos"])
        hechos_validos.append(
            {
                "reproduccion_bk": clave,
                "usuario_bk": usuario_bk,
                "contenido_bk": contenido_bk,
                "fecha": fecha_reproduccion,
                "segundos_origen": vistos,
                "segundos_vistos": min(vistos, duracion),
                "duracion_segundos": duracion,
                "porcentaje": porcentaje(vistos, duracion),
                "completo": 1 if porcentaje(vistos, duracion) >= Decimal("90.00") else 0,
                "supera_duracion": 1 if vistos > duracion else 0,
                "dispositivo": dispositivo(fila["dispositivo"]),
                "fila_origen": indice,
            }
        )
    hechos, hechos_viejos = conservar_reciente(hechos_validos, "reproduccion_bk", "fecha")
    for viejo in hechos_viejos:
        rechazos.append(
            _rechazo(
                "Reproducciones",
                str(viejo["reproduccion_bk"]),
                "Versión anterior reemplazada por un registro más reciente",
                int(viejo["fila_origen"]),
            )
        )

    fechas = sorted({fila["fecha"] for fila in hechos})
    tiempos = [tiempo_de(valor) for valor in fechas]

    usuarios.sort(key=lambda fila: str(fila["usuario_bk"]))
    contenidos.sort(key=lambda fila: str(fila["contenido_bk"]))
    hechos.sort(key=lambda fila: str(fila["reproduccion_bk"]))

    return {
        "usuarios": usuarios,
        "contenidos": contenidos,
        "tiempos": tiempos,
        "hechos": hechos,
        "rechazos": rechazos,
        "leidos": {
            "Usuarios": sum(1 for _ in leer_csv("Usuarios.csv")),
            "Contenidos": sum(1 for _ in leer_csv("Contenidos.csv")),
            "Reproducciones": sum(1 for _ in leer_csv("Reproducciones.csv")),
        },
    }


def _rechazo(flujo: str, clave: str, motivo: str, fila_origen: int) -> dict[str, str]:
    return {
        "flujo": flujo,
        "clave": clave,
        "motivo": motivo,
        "fila_origen": str(fila_origen),
    }


def crear_base(resultado: dict[str, object]) -> None:
    SALIDA.mkdir(exist_ok=True)
    if SQLITE.exists():
        SQLITE.unlink()
    with sqlite3.connect(SQLITE) as conexion:
        conexion.execute("PRAGMA foreign_keys = ON")
        conexion.executescript(
            """
            CREATE TABLE dim_usuario (
                usuario_sk INTEGER PRIMARY KEY,
                usuario_bk TEXT NOT NULL UNIQUE,
                nombre TEXT NOT NULL,
                correo TEXT NOT NULL,
                pais TEXT NOT NULL,
                segmento TEXT NOT NULL,
                fecha_registro TEXT NOT NULL
            );
            CREATE TABLE dim_contenido (
                contenido_sk INTEGER PRIMARY KEY,
                contenido_bk TEXT NOT NULL UNIQUE,
                titulo TEXT NOT NULL,
                categoria TEXT NOT NULL,
                duracion_segundos INTEGER NOT NULL,
                tipo TEXT NOT NULL,
                fecha_publicacion TEXT NOT NULL
            );
            CREATE TABLE dim_tiempo (
                tiempo_sk INTEGER PRIMARY KEY,
                fecha TEXT NOT NULL UNIQUE,
                anio INTEGER NOT NULL,
                mes INTEGER NOT NULL,
                nombre_mes TEXT NOT NULL,
                trimestre INTEGER NOT NULL,
                dia_semana TEXT NOT NULL
            );
            CREATE TABLE hechos_reproduccion (
                reproduccion_sk INTEGER PRIMARY KEY,
                reproduccion_bk TEXT NOT NULL UNIQUE,
                usuario_sk INTEGER NOT NULL REFERENCES dim_usuario(usuario_sk),
                contenido_sk INTEGER NOT NULL REFERENCES dim_contenido(contenido_sk),
                tiempo_sk INTEGER NOT NULL REFERENCES dim_tiempo(tiempo_sk),
                segundos_vistos INTEGER NOT NULL,
                segundos_origen INTEGER NOT NULL,
                duracion_segundos INTEGER NOT NULL,
                porcentaje_visualizacion TEXT NOT NULL,
                completo INTEGER NOT NULL,
                supera_duracion INTEGER NOT NULL,
                dispositivo TEXT NOT NULL
            );
            CREATE TABLE auditoria_rechazo (
                id INTEGER PRIMARY KEY,
                flujo TEXT NOT NULL,
                clave TEXT NOT NULL,
                motivo TEXT NOT NULL,
                fila_origen INTEGER NOT NULL
            );
            """
        )
        usuarios_sk: dict[str, int] = {}
        for fila in resultado["usuarios"]:
            cursor = conexion.execute(
                """
                INSERT INTO dim_usuario
                    (usuario_bk, nombre, correo, pais, segmento, fecha_registro)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    fila["usuario_bk"],
                    fila["nombre"],
                    fila["correo"],
                    fila["pais"],
                    fila["segmento"],
                    fila["fecha_registro"].strftime("%Y-%m-%d"),
                ),
            )
            usuarios_sk[str(fila["usuario_bk"])] = int(cursor.lastrowid)
        contenidos_sk: dict[str, int] = {}
        for fila in resultado["contenidos"]:
            cursor = conexion.execute(
                """
                INSERT INTO dim_contenido
                    (contenido_bk, titulo, categoria, duracion_segundos, tipo, fecha_publicacion)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    fila["contenido_bk"],
                    fila["titulo"],
                    fila["categoria"],
                    fila["duracion_segundos"],
                    fila["tipo"],
                    fila["fecha_publicacion"].strftime("%Y-%m-%d"),
                ),
            )
            contenidos_sk[str(fila["contenido_bk"])] = int(cursor.lastrowid)
        for fila in resultado["tiempos"]:
            conexion.execute(
                """
                INSERT INTO dim_tiempo
                    (tiempo_sk, fecha, anio, mes, nombre_mes, trimestre, dia_semana)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    fila["tiempo_sk"],
                    fila["fecha"],
                    fila["anio"],
                    fila["mes"],
                    fila["nombre_mes"],
                    fila["trimestre"],
                    fila["dia_semana"],
                ),
            )
        for fila in resultado["hechos"]:
            conexion.execute(
                """
                INSERT INTO hechos_reproduccion (
                    reproduccion_bk, usuario_sk, contenido_sk, tiempo_sk,
                    segundos_vistos, segundos_origen, duracion_segundos,
                    porcentaje_visualizacion, completo, supera_duracion, dispositivo
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    fila["reproduccion_bk"],
                    usuarios_sk[str(fila["usuario_bk"])],
                    contenidos_sk[str(fila["contenido_bk"])],
                    int(fila["fecha"].strftime("%Y%m%d")),
                    fila["segundos_vistos"],
                    fila["segundos_origen"],
                    fila["duracion_segundos"],
                    f"{fila['porcentaje']:.2f}",
                    fila["completo"],
                    fila["supera_duracion"],
                    fila["dispositivo"],
                ),
            )
        for fila in resultado["rechazos"]:
            conexion.execute(
                """
                INSERT INTO auditoria_rechazo (flujo, clave, motivo, fila_origen)
                VALUES (?, ?, ?, ?)
                """,
                (fila["flujo"], fila["clave"], fila["motivo"], int(fila["fila_origen"])),
            )
        conexion.commit()


def _tabla(encabezados: list[str], filas: list[list[object]]) -> str:
    linea_encabezado = "| " + " | ".join(encabezados) + " |"
    separador = "| " + " | ".join("---" for _ in encabezados) + " |"
    cuerpo = ["| " + " | ".join(str(valor) for valor in fila) + " |" for fila in filas]
    return "\n".join([linea_encabezado, separador, *cuerpo])


def _promedio(valores: list[Decimal]) -> Decimal:
    if not valores:
        return Decimal("0.00")
    return (sum(valores, Decimal("0.00")) / Decimal(len(valores))).quantize(
        Decimal("0.01"), rounding=ROUND_HALF_UP
    )


def _tasa(completas: int, total: int) -> Decimal:
    if total == 0:
        return Decimal("0.00")
    return (Decimal(completas) * Decimal(100) / Decimal(total)).quantize(
        Decimal("0.01"), rounding=ROUND_HALF_UP
    )


def escribir_reporte(resultado: dict[str, object]) -> None:
    calidad = [
        fila
        for fila in resultado["rechazos"]
        if "reemplazada" not in fila["motivo"]
    ]
    reemplazos = [
        fila for fila in resultado["rechazos"] if "reemplazada" in fila["motivo"]
    ]
    conteo_motivos = Counter(
        f"{fila['flujo']}: {fila['motivo']}" for fila in resultado["rechazos"]
    )
    usuarios = {str(fila["usuario_bk"]): fila for fila in resultado["usuarios"]}
    contenidos = {str(fila["contenido_bk"]): fila for fila in resultado["contenidos"]}
    hechos = list(resultado["hechos"])
    suma_porcentaje = sum((fila["porcentaje"] for fila in hechos), Decimal("0.00"))
    completos = sum(int(fila["completo"]) for fila in hechos)
    superan = sum(int(fila["supera_duracion"]) for fila in hechos)

    por_categoria: dict[str, list[dict[str, object]]] = {}
    por_contenido: dict[str, list[dict[str, object]]] = {}
    por_mes: dict[tuple[int, int, str], list[dict[str, object]]] = {}
    por_segmento: dict[str, list[dict[str, object]]] = {}
    for hecho in hechos:
        contenido = contenidos[str(hecho["contenido_bk"])]
        usuario = usuarios[str(hecho["usuario_bk"])]
        por_categoria.setdefault(str(contenido["categoria"]), []).append(hecho)
        por_contenido.setdefault(str(hecho["contenido_bk"]), []).append(hecho)
        marca = tiempo_de(hecho["fecha"])
        por_mes.setdefault(
            (int(marca["anio"]), int(marca["mes"]), str(marca["nombre_mes"])), []
        ).append(hecho)
        por_segmento.setdefault(str(usuario["segmento"]), []).append(hecho)

    filas_categoria = []
    for categoria, grupo in por_categoria.items():
        completas = sum(int(fila["completo"]) for fila in grupo)
        filas_categoria.append(
            [
                categoria,
                len(grupo),
                f"{_promedio([fila['porcentaje'] for fila in grupo]):.2f}",
                completas,
                f"{_tasa(completas, len(grupo)):.2f}",
            ]
        )
    filas_categoria.sort(key=lambda fila: (-Decimal(fila[4]), fila[0]))

    filas_contenido = []
    for clave, grupo in por_contenido.items():
        contenido = contenidos[clave]
        filas_contenido.append(
            [
                clave,
                contenido["titulo"],
                contenido["categoria"],
                len(grupo),
                f"{_promedio([fila['porcentaje'] for fila in grupo]):.2f}",
            ]
        )
    filas_contenido.sort(
        key=lambda fila: (-int(fila[3]), -Decimal(fila[4]), str(fila[0]))
    )

    filas_mes = []
    for (anio, _mes, nombre), grupo in sorted(por_mes.items()):
        filas_mes.append(
            [
                anio,
                nombre,
                len(grupo),
                sum(int(fila["completo"]) for fila in grupo),
            ]
        )

    filas_segmento = []
    for nombre, grupo in sorted(por_segmento.items()):
        filas_segmento.append(
            [
                nombre,
                len(grupo),
                f"{_promedio([fila['porcentaje'] for fila in grupo]):.2f}",
            ]
        )

    usuarios_con_hechos = {str(fila["usuario_bk"]) for fila in hechos}
    usuarios_sin_hechos = [
        [fila["usuario_bk"], fila["nombre"]]
        for fila in resultado["usuarios"]
        if str(fila["usuario_bk"]) not in usuarios_con_hechos
    ]

    muestra_hechos = [
        [
            fila["reproduccion_bk"],
            fila["usuario_bk"],
            fila["contenido_bk"],
            fila["fecha"].strftime("%Y-%m-%d"),
            fila["segundos_origen"],
            fila["segundos_vistos"],
            fila["duracion_segundos"],
            f"{fila['porcentaje']:.2f}",
            fila["completo"],
            fila["supera_duracion"],
            fila["dispositivo"],
        ]
        for fila in hechos
    ]

    leidos = resultado["leidos"]
    lineas = [
        "# Validación esperada del ETL AulaStream",
        "",
        "Estos números salen de `etl/pipeline.py`, con las mismas reglas que el paquete SSIS.",
        "Después de ejecutar el paquete en SQL Server, las consultas de `sql/03_consultas_validacion.sql` deben coincidir.",
        "",
        "## Conteos",
        "",
        _tabla(
            ["Objeto", "Leídos", "Cargados"],
            [
                ["Usuarios.csv / dw.Dim_Usuario", leidos["Usuarios"], len(resultado["usuarios"])],
                ["Contenidos.csv / dw.Dim_Contenido", leidos["Contenidos"], len(resultado["contenidos"])],
                ["Reproducciones.csv / dw.Hechos_Reproduccion", leidos["Reproducciones"], len(resultado["hechos"])],
                ["dw.Dim_Tiempo", "—", len(resultado["tiempos"])],
            ],
        ),
        "",
        f"- Rechazos de calidad: **{len(calidad)}**",
        f"- Versiones anteriores reemplazadas: **{len(reemplazos)}**",
        f"- Hechos con visualización completa (>= 90 %): **{completos}**",
        f"- Hechos que superan la duración y se topan al 100 %: **{superan}**",
        f"- Suma de porcentajes de visualización: **{suma_porcentaje:.2f}**",
        "",
        "## Auditoría por motivo",
        "",
        _tabla(
            ["Motivo", "Filas"],
            [[motivo, conteo] for motivo, conteo in sorted(conteo_motivos.items())],
        ),
        "",
        "## Usuarios en la dimensión sin reproducciones cargadas",
        "",
        _tabla(["UsuarioBK", "Nombre"], usuarios_sin_hechos),
        "",
        "## Finalización por categoría",
        "",
        _tabla(
            ["Categoría", "Reproducciones", "% promedio", "Completas", "Tasa de finalización"],
            filas_categoria,
        ),
        "",
        "## Contenidos",
        "",
        _tabla(
            ["Contenido", "Título", "Categoría", "Reproducciones", "% promedio"],
            filas_contenido,
        ),
        "",
        "## Reproducciones por mes",
        "",
        _tabla(["Año", "Mes", "Reproducciones", "Completas"], filas_mes),
        "",
        "## Porcentaje promedio por segmento",
        "",
        _tabla(["Segmento", "Reproducciones", "% promedio"], filas_segmento),
        "",
        "## Hechos cargados",
        "",
        _tabla(
            [
                "Hecho",
                "Usuario",
                "Contenido",
                "Fecha",
                "Origen",
                "Medida",
                "Duración",
                "%",
                "Completo",
                "Supera",
                "Dispositivo",
            ],
            muestra_hechos,
        ),
        "",
    ]
    REPORTE.write_text("\n".join(lineas), encoding="utf-8")


def verificar(resultado: dict[str, object]) -> None:
    assert len(resultado["usuarios"]) == 15, len(resultado["usuarios"])
    assert len(resultado["contenidos"]) == 12, len(resultado["contenidos"])
    assert len(resultado["hechos"]) == 24, len(resultado["hechos"])
    assert len(resultado["tiempos"]) == 22, len(resultado["tiempos"])
    calidad = [fila for fila in resultado["rechazos"] if "reemplazada" not in fila["motivo"]]
    reemplazos = [fila for fila in resultado["rechazos"] if "reemplazada" in fila["motivo"]]
    assert len(calidad) == 11, len(calidad)
    assert len(reemplazos) == 3, len(reemplazos)
    por_bk = {fila["reproduccion_bk"]: fila for fila in resultado["hechos"]}
    assert por_bk["REP002"]["porcentaje"] == Decimal("74.07")
    assert por_bk["REP014"]["porcentaje"] == Decimal("33.33")
    assert por_bk["REP015"]["porcentaje"] == Decimal("100.00")
    assert por_bk["REP015"]["supera_duracion"] == 1
    assert por_bk["REP015"]["segundos_vistos"] == 5400
    assert por_bk["REP015"]["segundos_origen"] == 6000
    assert por_bk["REP016"]["porcentaje"] == Decimal("0.00")
    assert por_bk["REP016"]["completo"] == 0
    assert por_bk["REP011"]["completo"] == 1
    usuario_002 = next(fila for fila in resultado["usuarios"] if fila["usuario_bk"] == "USR002")
    assert usuario_002["nombre"] == "Luis A. Mendoza"
    assert usuario_002["segmento"] == "Recurrente"
    usuario_003 = next(fila for fila in resultado["usuarios"] if fila["usuario_bk"] == "USR003")
    assert usuario_003["nombre"] == "Maria Lopez"
    usuario_004 = next(fila for fila in resultado["usuarios"] if fila["usuario_bk"] == "USR004")
    assert usuario_004["nombre"] == "Sin nombre"
    usuario_010 = next(fila for fila in resultado["usuarios"] if fila["usuario_bk"] == "USR010")
    assert usuario_010["pais"] == "Ecuador"
    assert usuario_010["segmento"] == "No definido"
    contenido_002 = next(
        fila for fila in resultado["contenidos"] if fila["contenido_bk"] == "CNT002"
    )
    assert contenido_002["titulo"] == "Modelo estrella actualizado"
    assert contenido_002["duracion_segundos"] == 5400
    contenido_003 = next(
        fila for fila in resultado["contenidos"] if fila["contenido_bk"] == "CNT003"
    )
    assert contenido_003["categoria"] == "Sin categoría"
    assert por_bk["REP003"]["dispositivo"] == "Web"
    assert por_bk["REP022"]["dispositivo"] == "No especificado"
    suma = sum((fila["porcentaje"] for fila in resultado["hechos"]), Decimal("0.00"))
    assert suma == Decimal("1727.40"), suma
    print("Validación de reglas: correcta.")
    print(
        "Dim_Usuario={0} Dim_Contenido={1} Dim_Tiempo={2} Hechos={3} "
        "RechazosCalidad={4} Reemplazos={5}".format(
            len(resultado["usuarios"]),
            len(resultado["contenidos"]),
            len(resultado["tiempos"]),
            len(resultado["hechos"]),
            len(calidad),
            len(reemplazos),
        )
    )


def main() -> None:
    resultado = procesar()
    crear_base(resultado)
    escribir_reporte(resultado)
    verificar(resultado)
    print(f"Base local: {SQLITE}")
    print(f"Reporte: {REPORTE}")


if __name__ == "__main__":
    main()
