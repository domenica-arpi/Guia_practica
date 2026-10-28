# Guía de laboratorio — SSIS y SQL Server Agent

Sigue esta página en el computador del laboratorio. Los CSV, la base y las expresiones ya están resueltos. Tú armas el paquete y tomas las capturas.

Herramientas: SQL Server Management Studio y Visual Studio con Integration Services (SSDT en Visual Studio 2019, o la extensión **SQL Server Integration Services Projects** en Visual Studio 2022).

## 1. Preparar archivos

1. Crea la carpeta `C:\PracticaBI\datos`.
2. Copia ahí `Usuarios.csv`, `Contenidos.csv` y `Reproducciones.csv`.
3. Ábrelos con el Bloc de notas, solo para ver que `José`, `Perú` y `categoría` se leen bien. Ciérralos sin guardar.
4. No los abras con Excel. Si Excel los reescribe, las fechas dejan de coincidir con las expresiones.

## 2. Crear la base

1. Abre SSMS y conéctate a la instancia del laboratorio.
2. Abre `sql/01_crear_data_warehouse.sql` y ejecútalo completo (F5).
3. Actualiza el explorador de objetos. Debe existir `DW_AulaStream`, con los esquemas `stg`, `dw` y `aud`.

Si `CREATE DATABASE` falla por permisos, avisa al docente y trabaja en la base que te asigne. En ese caso cambia el nombre en los scripts y en la conexión del paquete. El script usa `CREATE OR ALTER`, que SQL Server trae desde la versión 2016.

## 3. Crear el proyecto SSIS

1. Visual Studio → **Create a new project** → **Integration Services Project**.
2. Nombre: `ETL_AulaStream`. Ubicación: `C:\PracticaBI`.
3. Renombra `Package.dtsx` a `ETL_AulaStream.dtsx`.
4. Clic derecho en el paquete → **Properties** → `ProtectionLevel` = **DontSaveSensitive**. Así el Agent puede abrirlo.
5. En el panel de abajo, **Connection Managers**, crea cuatro conexiones.

### CM_DW

- Tipo: **OLE DB**.
- Proveedor: Microsoft OLE DB Driver for SQL Server, o SQL Server Native Client si el laboratorio no tiene el driver nuevo.
- Servidor: el de la instancia local. Autenticación de Windows.
- Base: `DW_AulaStream`.
- Pulsa **Test Connection**.

### CM_Usuarios, CM_Contenidos y CM_Reproducciones

Para cada CSV, nueva conexión **Flat File**:

| Propiedad | Valor |
| --- | --- |
| Nombre de archivo | el CSV correspondiente en `C:\PracticaBI\datos` |
| Locale | Spanish (Ecuador) o Spanish (Spain), el que exista |
| Code page | 65001 (UTF-8) |
| Format | Delimited |
| Text qualifier | ninguno, déjalo vacío |
| Header row delimiter | `{CR}{LF}` |
| Column names in the first data row | marcado |

En **Advanced**, cambia **todas** las columnas a `Unicode string [DT_WSTR]`, longitud 255. La conversión de verdad se hace después, en el Data Conversion. Si dejas que el origen adivine el tipo, la fecha `32/13/2024` o el texto `abc` rompen el componente antes de poder rechazar la fila.

## 4. Control flow

Arrastra estas tareas, en este orden, y une cada una con la flecha verde de éxito:

```text
SQL_Iniciar
    -> DFT_Limpiar_Usuarios
    -> DFT_Limpiar_Contenidos
    -> DFT_Limpiar_Reproducciones
    -> SQL_Publicar_Listas_Y_Tiempo
    -> DFT_Cargar_Dim_Usuario
    -> DFT_Cargar_Dim_Contenido
    -> DFT_Cargar_Hechos
    -> SQL_Cerrar
```

Las tres tareas SQL son **Execute SQL Task**. Conexión: `CM_DW`. En `SQLStatement` pega solo el bloque que le corresponde de `sql/02_tareas_del_paquete.sql`. No pegues la palabra `GO` ni los tres bloques en la misma tarea.

| Tarea | Bloque del archivo |
| --- | --- |
| `SQL_Iniciar` | desde `INSERT INTO aud.Ejecucion` hasta el `DELETE FROM aud.Rechazo` |
| `SQL_Publicar_Listas_Y_Tiempo` | desde el primer `INSERT INTO aud.Rechazo` de usuarios hasta el `INSERT INTO dw.Dim_Tiempo` |
| `SQL_Cerrar` | desde `DELETE tiempo` hasta el `INSERT INTO aud.Notificacion` |

`SQL_Iniciar` vacía la carga anterior, así puedes ejecutar el paquete varias veces. `SQL_Publicar` se queda con la versión más reciente de cada código y arma `Dim_Tiempo`. `SQL_Cerrar` quita las fechas que no llegaron a los hechos, cierra la auditoría y deja la simulación del correo.

## 5. Flujo de usuarios

Dentro de `DFT_Limpiar_Usuarios`:

```text
Origen CSV -> Limpieza (Derived Column) -> Reglas (Conditional Split)
                                              |-- ClaveVacia -> motivo -> Union All -> aud.Rechazo
                                              |-- Validos -> Data Conversion
                                                              |-- error de fecha -> motivo -> Union All
                                                              |-- correcto -> stg.Usuario
```

### Columnas derivadas de Limpieza

Agrega columnas nuevas. No reemplaces las del origen. Copia cada expresión tal como está en el bloque.

```text
UsuarioBK_L   DT_WSTR 20
TRIM([usuario_id])

Nombre_L   DT_WSTR 120
ISNULL([nombre]) || TRIM([nombre]) == "" || UPPER(TRIM([nombre])) == "NULL" ? "Sin nombre" : TRIM([nombre])

Correo_L   DT_WSTR 150
ISNULL([correo]) || TRIM([correo]) == "" || FINDSTRING([correo], "@", 1) == 0 ? "No registrado" : LOWER(TRIM([correo]))

Pais_L   DT_WSTR 80
ISNULL([pais]) || TRIM([pais]) == "" ? "No especificado" : TRIM([pais])

Segmento_L   DT_WSTR 40
ISNULL([segmento]) || TRIM([segmento]) == "" ? "No definido" : TRIM([segmento])

FechaISO   DT_WSTR 10
FINDSTRING(TRIM([fecha_registro]), "/", 1) > 0 ? SUBSTRING(TRIM([fecha_registro]), 7, 4) + "-" + SUBSTRING(TRIM([fecha_registro]), 4, 2) + "-" + SUBSTRING(TRIM([fecha_registro]), 1, 2) : TRIM([fecha_registro])
```

`FechaISO` pasa `15/01/2024` a `2024-01-15`. Si la fecha ya viene como `2024-07-01`, la deja igual. `32/13/2024` se vuelve `2024-13-32` y falla en la conversión: esa es la fila que se rechaza.

### Conditional Split Reglas

- Salida `ClaveVacia`: `TRIM([UsuarioBK_L]) == ""`
- La salida predeterminada se llama `Validos`.

En la ruta `ClaveVacia`, otra columna derivada, tipo DT_WSTR:

```text
Flujo   = "Usuarios"
Motivo  = "Clave de negocio vacía"
Clave   = "(sin clave)"
```

### Data Conversion

Sobre `Validos`, convierte `FechaISO` a `FechaRegistro`, tipo **database date [DT_DBDATE]**.

Abre **Configure Error Output** y pon **Redirect row** en Error y en Truncation. En esa ruta roja, columnas DT_WSTR:

```text
Flujo   = "Usuarios"
Motivo  = "Fecha inválida"
Clave   = [UsuarioBK_L]
```

### Destinos

- Filas buenas → **OLE DB Destination** `stg.Usuario`, modo *Table or view* (sin fast load). Mapea `UsuarioBK_L`, `Nombre_L`, `Correo_L`, `Pais_L`, `FechaRegistro` y `Segmento_L`. Deja `CargaId` sin mapear: es identity.
- Las dos rutas de rechazo entran a un **Union All** y de ahí a `aud.Rechazo`. Mapea solo `Flujo`, `Clave` y `Motivo`.

Al terminar este flujo tienen que quedar **16** filas en `stg.Usuario` y **2** rechazos de usuarios. `USR002` sigue dos veces: la versión vieja se descarta en la tarea SQL, no aquí.

## 6. Flujo de contenidos

Misma forma. Columnas derivadas:

```text
ContenidoBK_L   DT_WSTR 20
TRIM([contenido_id])

Titulo_L   DT_WSTR 200
ISNULL([titulo]) || TRIM([titulo]) == "" ? "Sin título" : TRIM([titulo])

Categoria_L   DT_WSTR 80
ISNULL([categoria]) || TRIM([categoria]) == "" ? "Sin categoría" : TRIM([categoria])

Tipo_L   DT_WSTR 40
ISNULL([tipo]) || TRIM([tipo]) == "" ? "No definido" : TRIM([tipo])

FechaISO   DT_WSTR 10
FINDSTRING(TRIM([fecha_publicacion]), "/", 1) > 0 ? SUBSTRING(TRIM([fecha_publicacion]), 7, 4) + "-" + SUBSTRING(TRIM([fecha_publicacion]), 4, 2) + "-" + SUBSTRING(TRIM([fecha_publicacion]), 1, 2) : TRIM([fecha_publicacion])
```

`DuracionSegundos`, tipo DT_I4:

Expresión de `DuracionSegundos`, en una sola línea:

```text
ISNULL([duracion]) || TRIM([duracion]) == "" ? NULL(DT_I4) : (FINDSTRING(LOWER(TRIM([duracion])), "min", 1) > 0 ? ((DT_I4)REPLACE(REPLACE(LOWER(TRIM([duracion])), "min", ""), " ", "")) * 60 : (TOKENCOUNT(TRIM([duracion]), ":") == 3 ? ((DT_I4)TOKEN(TRIM([duracion]), ":", 1) * 3600) + ((DT_I4)TOKEN(TRIM([duracion]), ":", 2) * 60) + ((DT_I4)TOKEN(TRIM([duracion]), ":", 3)) : (TOKENCOUNT(TRIM([duracion]), ":") == 2 ? ((DT_I4)TOKEN(TRIM([duracion]), ":", 1) * 60) + ((DT_I4)TOKEN(TRIM([duracion]), ":", 2)) : (DT_I4)TRIM([duracion]))))
```

Así `45 min` pasa a 2700 segundos, `1:30:00` a 5400, `25:00` a 1500 y `1800` se queda en 1800. La celda vacía de CNT007 queda NULL.

En el Derived Column abre **Configure Error Output** y redirige la fila. Esa ruta usa el motivo `Duración vacía o no interpretable`, por si un texto no se puede convertir.

Conditional Split, en este orden:

1. `ClaveVacia`: `TRIM([ContenidoBK_L]) == ""` → motivo `Clave de negocio vacía`, clave `(sin clave)`, flujo `Contenidos`.
2. `DuracionVacia`: `ISNULL([DuracionSegundos]) || [DuracionSegundos] <= 0` → motivo `Duración vacía o no interpretable`, clave `[ContenidoBK_L]`, flujo `Contenidos`.
3. Predeterminado: `Validos`.

En `Validos`, convierte `FechaISO` a `FechaPublicacion` (DT_DBDATE), con error redirigido y motivo `Fecha de publicación inválida`.

Destino de las filas buenas: `stg.Contenido`. Mapea `ContenidoBK_L`, `Titulo_L`, `Categoria_L`, `DuracionSegundos`, `Tipo_L` y `FechaPublicacion`.

Resultado de este flujo: **13** filas en `stg.Contenido` y **2** rechazos de contenidos.

## 7. Flujo de reproducciones

```text
ReproduccionBK_L   DT_WSTR 20
TRIM([reproduccion_id])

UsuarioBK_L   DT_WSTR 20
TRIM([usuario_id])

ContenidoBK_L   DT_WSTR 20
TRIM([contenido_id])

FechaISO   DT_WSTR 10
FINDSTRING(TRIM([fecha]), "/", 1) > 0 ? SUBSTRING(TRIM([fecha]), 7, 4) + "-" + SUBSTRING(TRIM([fecha]), 4, 2) + "-" + SUBSTRING(TRIM([fecha]), 1, 2) : TRIM([fecha])

SegundosOrigen   DT_I4
ISNULL([segundos_vistos]) || TRIM([segundos_vistos]) == "" ? NULL(DT_I4) : (DT_I4)TRIM([segundos_vistos])
```

`Dispositivo_L`, tipo DT_WSTR 30:

`Dispositivo_L`:

```text
ISNULL([dispositivo]) || TRIM([dispositivo]) == "" ? "No especificado" : (LOWER(TRIM([dispositivo])) == "web" ? "Web" : (LOWER(TRIM([dispositivo])) == "movil" || LOWER(TRIM([dispositivo])) == "móvil" ? "Móvil" : (LOWER(TRIM([dispositivo])) == "smart tv" ? "Smart TV" : TRIM([dispositivo]))))
```

Redirige el error del Derived Column. El texto `abc` cae por ahí. Motivo, en los dos casos (error de conversión y número negativo): `Segundos vistos no numéricos o negativos`. Flujo: `Reproducciones`. Clave: `[ReproduccionBK_L]`.

Conditional Split:

1. `ClaveVacia`: `TRIM([ReproduccionBK_L]) == ""` → motivo `Clave de negocio vacía`, clave `(sin clave)`.
2. `SegundosInvalidos`: `ISNULL([SegundosOrigen]) || [SegundosOrigen] < 0` → el motivo de segundos.
3. `Validos`.

Conversión de `FechaISO` a `Fecha` (DT_DBDATE). Error: motivo `Fecha inválida`.

Destino: `stg.Reproduccion`, columnas `ReproduccionBK_L`, `UsuarioBK_L`, `ContenidoBK_L`, `Fecha`, `SegundosOrigen`, `Dispositivo_L`.

Resultado: **28** filas en `stg.Reproduccion`. Los usuarios o contenidos que no existen todavía no se rechazan: eso lo hace el Lookup del flujo de hechos.

## 8. Publicar dimensiones

`SQL_Publicar_Listas_Y_Tiempo` ya está en el control flow. Después de ella:

### DFT_Cargar_Dim_Usuario

- Origen OLE DB: tabla `stg.UsuarioListo`.
- Destino OLE DB: `dw.Dim_Usuario`.
- Mapea `UsuarioBK`, `Nombre`, `Correo`, `Pais`, `Segmento` y `FechaRegistro`. No mapees `UsuarioSK`.

### DFT_Cargar_Dim_Contenido

- Origen: `stg.ContenidoListo`.
- Destino: `dw.Dim_Contenido`.
- Mapea todas las columnas menos `ContenidoSK`.

Estas dos tareas pueden ir en secuencia. Las dos tienen que terminar antes del flujo de hechos, porque el Lookup las necesita.

Después de esta parte: **15** usuarios listos, **12** contenidos listos y **27** reproducciones listas. `aud.Rechazo` lleva **11** filas (8 de calidad y 3 versiones viejas).

## 9. Flujo de hechos y porcentaje

Dentro de `DFT_Cargar_Hechos`:

```text
stg.ReproduccionLista
    -> Lookup Usuario
         |-- sin coincidencia -> rechazo "Usuario no existe en la dimensión"
         -> Lookup Contenido
              |-- sin coincidencia -> rechazo "Contenido no existe en la dimensión"
              -> Columna derivada Medidas
                   -> Columna derivada Completo
                        -> dw.Hechos_Reproduccion
```

### Lookup Usuario

- Conexión `CM_DW`, modo Full cache.
- Consulta: `SELECT UsuarioSK, UsuarioBK FROM dw.Dim_Usuario`
- Une `UsuarioBK` del flujo con `UsuarioBK` de la dimensión.
- Marca `UsuarioSK` como columna de salida.
- En **General**, *Specify how to handle rows with no matching entries*: **Redirect rows to no match output**.

En la salida sin coincidencia crea `Flujo = "Reproducciones"`, `Motivo = "Usuario no existe en la dimensión"` y `Clave = [ReproduccionBK]`. Únela al destino `aud.Rechazo`.

### Lookup Contenido

- Consulta: `SELECT ContenidoSK, ContenidoBK, DuracionSegundos FROM dw.Dim_Contenido`
- Une por `ContenidoBK`.
- Saca `ContenidoSK`. A `DuracionSegundos` ponle alias de salida **`DuracionContenido`**, para no confundirla con la medida.
- También redirige las filas sin coincidencia. Motivo: `Contenido no existe en la dimensión`.

### Columna derivada Medidas

Esta es la transformación que pide la guía.

```text
TiempoSK   DT_I4
DATEPART("yyyy",[Fecha]) * 10000 + DATEPART("mm",[Fecha]) * 100 + DATEPART("dd",[Fecha])

SegundosVistos   DT_I4
[SegundosOrigen] > [DuracionContenido] ? [DuracionContenido] : [SegundosOrigen]

SuperaDuracion   DT_I4
[SegundosOrigen] > [DuracionContenido] ? 1 : 0
```

`PorcentajeVisualizacion`, tipo numeric con precisión 5 y escala 2. SSIS no deja usar una columna nueva dentro de la misma transformación, así que el indicador `Completo` va en un segundo Derived Column, justo después:

```text
[DuracionContenido] <= 0 || [SegundosOrigen] <= 0 ? (DT_NUMERIC,5,2)0 : ([SegundosOrigen] >= [DuracionContenido] ? (DT_NUMERIC,5,2)100 : (DT_NUMERIC,5,2)ROUND(((DT_NUMERIC,12,4)[SegundosOrigen] * 100) / (DT_NUMERIC,12,4)[DuracionContenido], 2))
```

En el segundo Derived Column, `Completo`, tipo DT_I4:

```text
[PorcentajeVisualizacion] >= 90 ? 1 : 0
```

La regla de negocio queda así: si no hubo segundos, el porcentaje es 0. Si los segundos alcanzan o superan la duración, el porcentaje es 100 y la medida de segundos se recorta a la duración. En el resto, `ROUND(segundos * 100 / duración, 2)`. `Completo` vale 1 desde el 90 %.

Destino: `dw.Hechos_Reproduccion`. Mapea la clave de negocio, las tres surrogate keys, `SegundosVistos`, `SegundosOrigen`, `DuracionContenido` hacia `DuracionSegundos`, el porcentaje, `Completo`, `SuperaDuracion` y `Dispositivo`. No mapees `ReproduccionSK`.

`SQL_Cerrar` borra de `Dim_Tiempo` las fechas que se quedaron sin hechos (el 2 de junio y el 17 de enero, que solo estaban en filas rechazadas).

## 10. Ejecutar y validar

1. Guarda el paquete.
2. Pulsa **Start**. Los nueve componentes deben ponerse en verde. Toma la captura.
3. Si un componente se pone en rojo, abre la pestaña **Progress**. El mensaje dice la columna y el destino. Los fallos típicos están al final de esta guía.
4. En SSMS ejecuta `sql/03_consultas_validacion.sql`.
5. La primera cuadrícula tiene que mostrar **OK** nueve veces. Captúrala completa, con los valores 15, 12, 22, 24, 11, 3, 12, 1 y 1727.40.

Comprobaciones que el docente puede pedirte en voz alta:

| Fila | Qué debe decir |
| --- | --- |
| REP002 | 74.07 % el 21/06/2024. La fila del 20/06 quedó reemplazada |
| REP014 | 33.33 % (600 / 1800) |
| REP015 | origen 6000, medida 5400, 100 %, `SuperaDuracion` = 1 |
| REP016 | 0 % |
| USR002 | Luis A. Mendoza, segmento Recurrente, país Ecuador |
| USR004 | Sin nombre, y no tiene hechos |
| CNT002 | título «Modelo estrella actualizado», 5400 segundos |
| CNT003 | categoría «Sin categoría» |

## 11. Job diario

Cuando el paquete ya da OK a mano:

1. En Visual Studio, **Build**. El archivo queda en `bin\Development\ETL_AulaStream.dtsx`.
2. Cópialo a `C:\PracticaBI\ETL_AulaStream.dtsx`.
3. En SSMS, confirma que el servicio **SQL Server Agent** está en ejecución. Si está detenido, clic derecho → Start. Si Windows no te deja, pide al docente que lo inicie.
4. Ejecuta `sql/04_job_sql_server_agent.sql`. Si la ruta del paquete es otra, cambia la variable `@RutaPaquete` de la primera línea útil.
5. En el explorador: SQL Server Agent → Jobs → `JOB_ETL_AulaStream_Diario`.
6. Abre **Properties → Schedules**. Tiene que decir diario a las 01:00:00. Captura esa ventana.
7. Clic derecho sobre el job → **Start Job at step**. Espera a que termine.
8. Abre **View History** y captura el resultado.
9. Ejecuta de nuevo la consulta de `aud.Notificacion`. Tiene que haber una fila `SIMULADO` del paquete y otra del job.

La programación real es todos los días a la 1:00. La prueba de la guía es la ejecución manual más la pantalla de la programación. No hace falta volver al laboratorio al día siguiente.

Si el paso SSIS del script no arranca en esa versión del Agent, crea el job por el asistente y deja los otros dos pasos como están:

1. New Job → nombre `JOB_ETL_AulaStream_Diario`.
2. Step 1 → tipo **SQL Server Integration Services Package** → Package source **File system** → elige el `.dtsx`.
3. En Advanced del paso 1: On success = Go to the next step. On failure = Go to step 3.
4. Step 2 y step 3: tipo Transact-SQL, base `DW_AulaStream`, con los `INSERT` de éxito y de fallo que ya están en el script.
5. Schedule → Recurring, Daily, 1:00:00 a. m.

En **Notifications** puedes elegir el operador `Operador_BI_AulaStream` cuando el job falle. Si el laboratorio no tiene Database Mail, esa opción no envía nada: la evidencia sigue siendo `aud.Notificacion`.

## 12. Fallos que suelen aparecer

| Qué ves | Qué hacer |
| --- | --- |
| El CSV se lee con caracteres raros | Code page 65001 en el Flat File |
| El origen del CSV falla en la fila de `abc` o de la fecha 32/13 | Todas las columnas del origen tienen que ser DT_WSTR. La conversión va después |
| El destino dice que la columna no permite NULL | Una expresión de limpieza no cubrió el vacío. Revisa el mapeo y el nombre de la columna nueva |
| El Lookup pone rojo el flujo completo | Falta *Redirect rows to no match output* |
| `Dim_Usuario` queda en 16 | No corrió `SQL_Publicar` antes del destino, y entraron las dos versiones de USR002 |
| `Dim_Tiempo` queda en 24 | No corrió `SQL_Cerrar`, que borra las fechas sin hechos |
| El job no encuentra el paquete | La ruta de `@RutaPaquete` no es la del `.dtsx` copiado. El Agent no lee la carpeta de Visual Studio si no se la indicas |
| El job falla con permiso | La cuenta del Agent tiene que poder leer `C:\PracticaBI` y entrar a `DW_AulaStream` |
| Vuelve a salir 1727.40 después de un segundo run | Es correcto. `SQL_Iniciar` vacía las tablas antes de cargar |

Cuando los nueve OK estén en pantalla, pasa al informe.
