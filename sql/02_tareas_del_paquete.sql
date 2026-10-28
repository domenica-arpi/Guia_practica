/*
    Tareas Execute SQL del paquete ETL_AulaStream.
    Cada bloque se pega en una tarea distinta. No incluyas la palabra GO:
    el Execute SQL Task no la acepta.

    Orden del control flow:
        1. SQL_Iniciar
        2. DFT_Limpiar_Usuarios
        3. DFT_Limpiar_Contenidos
        4. DFT_Limpiar_Reproducciones
        5. SQL_Publicar_Listas_Y_Tiempo
        6. DFT_Cargar_Dim_Usuario
        7. DFT_Cargar_Dim_Contenido
        8. DFT_Cargar_Hechos
        9. SQL_Cerrar
*/

/* ==================== TAREA: SQL_Iniciar ==================== */

INSERT INTO aud.Ejecucion (Paquete, Inicio, Estado)
VALUES (N'ETL_AulaStream', SYSDATETIME(), N'En ejecución');

DELETE FROM dw.Hechos_Reproduccion;
DELETE FROM dw.Dim_Usuario;
DELETE FROM dw.Dim_Contenido;
DELETE FROM dw.Dim_Tiempo;

DELETE FROM stg.UsuarioListo;
DELETE FROM stg.ContenidoListo;
DELETE FROM stg.ReproduccionLista;
DELETE FROM stg.Usuario;
DELETE FROM stg.Contenido;
DELETE FROM stg.Reproduccion;

DELETE FROM aud.Rechazo;

/* ==================== TAREA: SQL_Publicar_Listas_Y_Tiempo ==================== */

INSERT INTO aud.Rechazo (Flujo, Clave, Motivo)
SELECT N'Usuarios', UsuarioBK, N'Versión anterior reemplazada por un registro más reciente'
FROM
(
    SELECT UsuarioBK,
           ROW_NUMBER() OVER (PARTITION BY UsuarioBK ORDER BY FechaRegistro DESC, CargaId DESC) AS rn
    FROM stg.Usuario
) AS versiones
WHERE rn > 1;

INSERT INTO stg.UsuarioListo (UsuarioBK, Nombre, Correo, Pais, FechaRegistro, Segmento)
SELECT
    UsuarioBK,
    CASE
        WHEN UPPER(dw.fn_Colapsar(Nombre)) IN (N'', N'NULL', N'SIN NOMBRE') THEN N'Sin nombre'
        ELSE dw.fn_TituloPropio(Nombre)
    END,
    CASE
        WHEN dw.fn_Colapsar(Correo) = N'' OR CHARINDEX(N'@', Correo) = 0 THEN N'No registrado'
        ELSE LOWER(dw.fn_Colapsar(Correo))
    END,
    dw.fn_Pais(Pais),
    FechaRegistro,
    CASE LOWER(dw.fn_Colapsar(Segmento))
        WHEN N'recurrente' THEN N'Recurrente'
        WHEN N'nuevo' THEN N'Nuevo'
        WHEN N'inactivo' THEN N'Inactivo'
        ELSE N'No definido'
    END
FROM
(
    SELECT UsuarioBK, Nombre, Correo, Pais, FechaRegistro, Segmento,
           ROW_NUMBER() OVER (PARTITION BY UsuarioBK ORDER BY FechaRegistro DESC, CargaId DESC) AS rn
    FROM stg.Usuario
) AS vigente
WHERE rn = 1;

INSERT INTO aud.Rechazo (Flujo, Clave, Motivo)
SELECT N'Contenidos', ContenidoBK, N'Versión anterior reemplazada por un registro más reciente'
FROM
(
    SELECT ContenidoBK,
           ROW_NUMBER() OVER (PARTITION BY ContenidoBK ORDER BY FechaPublicacion DESC, CargaId DESC) AS rn
    FROM stg.Contenido
) AS versiones
WHERE rn > 1;

INSERT INTO stg.ContenidoListo
    (ContenidoBK, Titulo, Categoria, DuracionSegundos, Tipo, FechaPublicacion)
SELECT
    ContenidoBK,
    CASE WHEN dw.fn_Colapsar(Titulo) = N'' THEN N'Sin título' ELSE dw.fn_Colapsar(Titulo) END,
    CASE WHEN dw.fn_Colapsar(Categoria) = N'' THEN N'Sin categoría' ELSE dw.fn_Colapsar(Categoria) END,
    DuracionSegundos,
    CASE LOWER(dw.fn_Colapsar(Tipo))
        WHEN N'video' THEN N'Video'
        WHEN N'audio' THEN N'Audio'
        WHEN N'' THEN N'No definido'
        ELSE dw.fn_TituloPropio(Tipo)
    END,
    FechaPublicacion
FROM
(
    SELECT ContenidoBK, Titulo, Categoria, DuracionSegundos, Tipo, FechaPublicacion,
           ROW_NUMBER() OVER (PARTITION BY ContenidoBK ORDER BY FechaPublicacion DESC, CargaId DESC) AS rn
    FROM stg.Contenido
) AS vigente
WHERE rn = 1;

INSERT INTO aud.Rechazo (Flujo, Clave, Motivo)
SELECT N'Reproducciones', ReproduccionBK, N'Versión anterior reemplazada por un registro más reciente'
FROM
(
    SELECT ReproduccionBK,
           ROW_NUMBER() OVER (PARTITION BY ReproduccionBK ORDER BY Fecha DESC, CargaId DESC) AS rn
    FROM stg.Reproduccion
) AS versiones
WHERE rn > 1;

INSERT INTO stg.ReproduccionLista
    (ReproduccionBK, UsuarioBK, ContenidoBK, Fecha, SegundosOrigen, Dispositivo)
SELECT ReproduccionBK, UsuarioBK, ContenidoBK, Fecha, SegundosOrigen, dw.fn_Dispositivo(Dispositivo)
FROM
(
    SELECT ReproduccionBK, UsuarioBK, ContenidoBK, Fecha, SegundosOrigen, Dispositivo,
           ROW_NUMBER() OVER (PARTITION BY ReproduccionBK ORDER BY Fecha DESC, CargaId DESC) AS rn
    FROM stg.Reproduccion
) AS vigente
WHERE rn = 1;

SET DATEFIRST 1;

INSERT INTO dw.Dim_Tiempo (TiempoSK, Fecha, Anio, Mes, NombreMes, Trimestre, DiaSemana)
SELECT DISTINCT
    YEAR(Fecha) * 10000 + MONTH(Fecha) * 100 + DAY(Fecha),
    Fecha,
    YEAR(Fecha),
    MONTH(Fecha),
    CASE MONTH(Fecha)
        WHEN 1 THEN N'enero' WHEN 2 THEN N'febrero' WHEN 3 THEN N'marzo'
        WHEN 4 THEN N'abril' WHEN 5 THEN N'mayo' WHEN 6 THEN N'junio'
        WHEN 7 THEN N'julio' WHEN 8 THEN N'agosto' WHEN 9 THEN N'septiembre'
        WHEN 10 THEN N'octubre' WHEN 11 THEN N'noviembre' ELSE N'diciembre'
    END,
    DATEPART(QUARTER, Fecha),
    CASE DATEPART(WEEKDAY, Fecha)
        WHEN 1 THEN N'lunes' WHEN 2 THEN N'martes' WHEN 3 THEN N'miércoles'
        WHEN 4 THEN N'jueves' WHEN 5 THEN N'viernes' WHEN 6 THEN N'sábado'
        ELSE N'domingo'
    END
FROM stg.ReproduccionLista;

/* ==================== TAREA: SQL_Cerrar ==================== */

DELETE tiempo
FROM dw.Dim_Tiempo AS tiempo
WHERE NOT EXISTS
(
    SELECT 1
    FROM dw.Hechos_Reproduccion AS hechos
    WHERE hechos.TiempoSK = tiempo.TiempoSK
);

UPDATE aud.Ejecucion
SET
    Fin = SYSDATETIME(),
    FilasUsuarios = (SELECT COUNT(*) FROM dw.Dim_Usuario),
    FilasContenidos = (SELECT COUNT(*) FROM dw.Dim_Contenido),
    FilasTiempo = (SELECT COUNT(*) FROM dw.Dim_Tiempo),
    FilasHechos = (SELECT COUNT(*) FROM dw.Hechos_Reproduccion),
    FilasRechazadas = (SELECT COUNT(*) FROM aud.Rechazo),
    Estado = N'Correcto'
WHERE EjecucionId = (SELECT MAX(EjecucionId) FROM aud.Ejecucion)
  AND Fin IS NULL;

INSERT INTO aud.Notificacion (Destinatario, Asunto, Mensaje, Estado)
VALUES
(
    N'bi.aulastream@unemi.edu.ec',
    N'ETL AulaStream finalizado',
    N'Simulación de correo: el paquete terminó. Revise aud.Ejecucion y aud.Rechazo antes de usar los tableros.',
    N'SIMULADO'
);
