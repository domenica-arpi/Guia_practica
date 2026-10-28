# Validación esperada del ETL AulaStream

Estos números salen de `etl/pipeline.py`, con las mismas reglas que el paquete SSIS.
Después de ejecutar el paquete en SQL Server, las consultas de `sql/03_consultas_validacion.sql` deben coincidir.

## Conteos

| Objeto | Leídos | Cargados |
| --- | --- | --- |
| Usuarios.csv / dw.Dim_Usuario | 18 | 15 |
| Contenidos.csv / dw.Dim_Contenido | 15 | 12 |
| Reproducciones.csv / dw.Hechos_Reproduccion | 32 | 24 |
| dw.Dim_Tiempo | — | 22 |

- Rechazos de calidad: **11**
- Versiones anteriores reemplazadas: **3**
- Hechos con visualización completa (>= 90 %): **12**
- Hechos que superan la duración y se topan al 100 %: **1**
- Suma de porcentajes de visualización: **1727.40**

## Auditoría por motivo

| Motivo | Filas |
| --- | --- |
| Contenidos: Clave de negocio vacía | 1 |
| Contenidos: Duración vacía o no interpretable | 1 |
| Contenidos: Versión anterior reemplazada por un registro más reciente | 1 |
| Reproducciones: Clave de negocio vacía | 1 |
| Reproducciones: Contenido no existe en la dimensión | 1 |
| Reproducciones: Fecha inválida | 1 |
| Reproducciones: Segundos vistos no numéricos o negativos | 2 |
| Reproducciones: Usuario no existe en la dimensión | 2 |
| Reproducciones: Versión anterior reemplazada por un registro más reciente | 1 |
| Usuarios: Clave de negocio vacía | 1 |
| Usuarios: Fecha inválida | 1 |
| Usuarios: Versión anterior reemplazada por un registro más reciente | 1 |

## Usuarios en la dimensión sin reproducciones cargadas

| UsuarioBK | Nombre |
| --- | --- |
| USR004 | Sin nombre |

## Finalización por categoría

| Categoría | Reproducciones | % promedio | Completas | Tasa de finalización |
| --- | --- | --- | --- | --- |
| Comercial | 3 | 80.00 | 2 | 66.67 |
| Analítica | 2 | 75.00 | 1 | 50.00 |
| Bases de datos | 2 | 75.00 | 1 | 50.00 |
| Finanzas | 2 | 75.00 | 1 | 50.00 |
| Gobierno de datos | 2 | 70.00 | 1 | 50.00 |
| Inteligencia de negocios | 4 | 76.85 | 2 | 50.00 |
| Servicio | 2 | 75.00 | 1 | 50.00 |
| Talento humano | 2 | 75.00 | 1 | 50.00 |
| Visualización | 2 | 45.00 | 1 | 50.00 |
| Sin categoría | 3 | 66.67 | 1 | 33.33 |

## Contenidos

| Contenido | Título | Categoría | Reproducciones | % promedio |
| --- | --- | --- | --- | --- |
| CNT012 | Indicadores de ventas | Comercial | 3 | 80.00 |
| CNT002 | Modelo estrella actualizado | Inteligencia de negocios | 2 | 87.04 |
| CNT001 | Introducción a SQL | Bases de datos | 2 | 75.00 |
| CNT006 | Podcast de KPI | Sin categoría | 2 | 75.00 |
| CNT008 | Python para analítica | Analítica | 2 | 75.00 |
| CNT009 | Costos ABC | Finanzas | 2 | 75.00 |
| CNT010 | Atención al cliente | Servicio | 2 | 75.00 |
| CNT011 | Clima laboral | Talento humano | 2 | 75.00 |
| CNT013 | Ética de datos | Gobierno de datos | 2 | 70.00 |
| CNT004 | ETL con SSIS | Inteligencia de negocios | 2 | 66.67 |
| CNT005 | Dashboard gerencial | Visualización | 2 | 45.00 |
| CNT003 | Limpieza de datos | Sin categoría | 1 | 50.00 |

## Reproducciones por mes

| Año | Mes | Reproducciones | Completas |
| --- | --- | --- | --- |
| 2024 | enero | 1 | 1 |
| 2024 | marzo | 2 | 0 |
| 2024 | abril | 2 | 2 |
| 2024 | mayo | 3 | 1 |
| 2024 | junio | 3 | 2 |
| 2024 | julio | 4 | 2 |
| 2024 | agosto | 3 | 2 |
| 2024 | septiembre | 3 | 1 |
| 2024 | octubre | 3 | 1 |

## Porcentaje promedio por segmento

| Segmento | Reproducciones | % promedio |
| --- | --- | --- |
| No definido | 2 | 95.00 |
| Nuevo | 5 | 46.67 |
| Recurrente | 17 | 76.71 |

## Hechos cargados

| Hecho | Usuario | Contenido | Fecha | Origen | Medida | Duración | % | Completo | Supera | Dispositivo |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| REP001 | USR001 | CNT001 | 2024-01-16 | 2700 | 2700 | 2700 | 100.00 | 1 | 0 | Móvil |
| REP002 | USR001 | CNT002 | 2024-06-21 | 4000 | 4000 | 5400 | 74.07 | 0 | 0 | Web |
| REP003 | USR002 | CNT004 | 2024-06-19 | 1800 | 1800 | 1800 | 100.00 | 1 | 0 | Web |
| REP004 | USR003 | CNT003 | 2024-03-04 | 900 | 900 | 1800 | 50.00 | 0 | 0 | Móvil |
| REP006 | USR005 | CNT008 | 2024-04-12 | 3300 | 3300 | 3300 | 100.00 | 1 | 0 | Smart TV |
| REP007 | USR006 | CNT009 | 2024-05-13 | 1200 | 1200 | 2400 | 50.00 | 0 | 0 | Web |
| REP008 | USR007 | CNT010 | 2024-05-21 | 1200 | 1200 | 1200 | 100.00 | 1 | 0 | Móvil |
| REP009 | USR009 | CNT011 | 2024-07-02 | 450 | 450 | 900 | 50.00 | 0 | 0 | Web |
| REP010 | USR010 | CNT012 | 2024-07-23 | 3600 | 3600 | 3600 | 100.00 | 1 | 0 | Smart TV |
| REP011 | USR011 | CNT013 | 2024-08-06 | 1890 | 1890 | 2100 | 90.00 | 1 | 0 | Web |
| REP012 | USR012 | CNT001 | 2024-08-20 | 1350 | 1350 | 2700 | 50.00 | 0 | 0 | Móvil |
| REP013 | USR013 | CNT006 | 2024-09-03 | 1500 | 1500 | 1500 | 100.00 | 1 | 0 | Web |
| REP014 | USR014 | CNT004 | 2024-09-16 | 600 | 600 | 1800 | 33.33 | 0 | 0 | Móvil |
| REP015 | USR015 | CNT002 | 2024-10-02 | 6000 | 5400 | 5400 | 100.00 | 1 | 1 | Web |
| REP016 | USR016 | CNT005 | 2024-10-29 | 0 | 0 | 2700 | 0.00 | 0 | 0 | Web |
| REP022 | USR003 | CNT012 | 2024-03-05 | 1800 | 1800 | 3600 | 50.00 | 0 | 0 | No especificado |
| REP023 | USR005 | CNT009 | 2024-04-15 | 2400 | 2400 | 2400 | 100.00 | 1 | 0 | Móvil |
| REP024 | USR007 | CNT008 | 2024-05-22 | 1650 | 1650 | 3300 | 50.00 | 0 | 0 | Web |
| REP025 | USR009 | CNT010 | 2024-07-03 | 600 | 600 | 1200 | 50.00 | 0 | 0 | Móvil |
| REP026 | USR011 | CNT011 | 2024-08-07 | 900 | 900 | 900 | 100.00 | 1 | 0 | Smart TV |
| REP027 | USR013 | CNT013 | 2024-09-04 | 1050 | 1050 | 2100 | 50.00 | 0 | 0 | Web |
| REP028 | USR001 | CNT012 | 2024-06-21 | 3240 | 3240 | 3600 | 90.00 | 1 | 0 | Web |
| REP029 | USR016 | CNT006 | 2024-10-29 | 750 | 750 | 1500 | 50.00 | 0 | 0 | Móvil |
| REP030 | USR010 | CNT005 | 2024-07-24 | 2430 | 2430 | 2700 | 90.00 | 1 | 0 | Web |
