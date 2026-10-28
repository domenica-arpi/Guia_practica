# Práctica 3 — ETL de AulaStream

Trabajo de **Inteligencia de Negocios** (Universidad Estatal de Milagro, carrera de Software). La guía pide un proceso ETL en SQL Server Integration Services y un job de SQL Server Agent.

El caso es **AulaStream**: una plataforma de contenidos. El data warehouse responde cuánto se ve cada material y quiénes llegan a terminarlo.

## Empieza por aquí

1. [Lo que tienes que hacer tú](docs/00_lo_que_debes_hacer.md)
2. [Guía de clics en SSIS y en el Agent](docs/01_guia_laboratorio_ssis.md)
3. [Informe para entregar](docs/02_informe_practica.md)
4. [Preguntas para la defensa](docs/03_preguntas_defensa.md)

## Qué hay en el repositorio

| Ruta | Para qué sirve |
| --- | --- |
| `datos/` | `Usuarios.csv`, `Contenidos.csv` y `Reproducciones.csv`, con nulos, tipos mezclados y duplicados a propósito |
| `sql/01_crear_data_warehouse.sql` | Crea la base `DW_AulaStream` |
| `sql/02_tareas_del_paquete.sql` | SQL que se pega dentro del paquete SSIS |
| `sql/03_consultas_validacion.sql` | Comprueba que la carga coincida con el resultado esperado |
| `sql/04_job_sql_server_agent.sql` | Crea el job diario y la notificación simulada |
| `etl/pipeline.py` | Misma lógica de negocio, para ensayar en cualquier computador con Python 3 |
| `salida/validacion.md` | Conteos y consultas que debe reproducir SQL Server |

## Ensayo local

No hace falta instalar nada aparte de Python 3.

```bash
python3 etl/pipeline.py
```

Eso regenera `salida/validacion.md` y una base SQLite en `salida/dw_aula_stream.sqlite`. Sirve para estudiar las reglas. La nota del laboratorio sale del paquete SSIS, de las capturas y de la defensa, no de este script.

## Resultado que debe cuadrar

| Objeto | Filas |
| --- | ---: |
| `dw.Dim_Usuario` | 15 |
| `dw.Dim_Contenido` | 12 |
| `dw.Dim_Tiempo` | 22 |
| `dw.Hechos_Reproduccion` | 24 |
| Rechazos de calidad | 11 |
| Versiones reemplazadas | 3 |
| Suma de porcentajes | 1727.40 |

## Modelo

Una reproducción vigente es el grano de `Hechos_Reproduccion`. Alrededor están `Dim_Usuario`, `Dim_Contenido` y `Dim_Tiempo`. El porcentaje de visualización se calcula en el flujo de hechos y queda topado en 100. Una reproducción se considera completa desde el 90 %.
