/*
    Ejecutar en SSMS después de correr el paquete.
    La primera consulta debe mostrar OK en todas las filas.
    Resultado esperado del caso AulaStream:

        Dim_Usuario            15
        Dim_Contenido          12
        Dim_Tiempo             22
        Hechos                 24
        Rechazos de calidad    11
        Versiones reemplazadas  3
        Completos (>= 90 %)    12
        Superan duración        1
        Suma de porcentajes  1727.40
*/

USE DW_AulaStream;
GO

SELECT
    indicador,
    obtenido,
    esperado,
    CASE WHEN obtenido = esperado THEN N'OK' ELSE N'REVISAR' END AS estado
FROM
(
    SELECT N'Dim_Usuario' AS indicador,
           CAST((SELECT COUNT(*) FROM dw.Dim_Usuario) AS DECIMAL(12, 2)) AS obtenido,
           CAST(15 AS DECIMAL(12, 2)) AS esperado
    UNION ALL
    SELECT N'Dim_Contenido',
           (SELECT COUNT(*) FROM dw.Dim_Contenido), 12
    UNION ALL
    SELECT N'Dim_Tiempo',
           (SELECT COUNT(*) FROM dw.Dim_Tiempo), 22
    UNION ALL
    SELECT N'Hechos_Reproduccion',
           (SELECT COUNT(*) FROM dw.Hechos_Reproduccion), 24
    UNION ALL
    SELECT N'Rechazos_calidad',
           (SELECT COUNT(*) FROM aud.Rechazo WHERE Motivo NOT LIKE N'%reemplazada%'), 11
    UNION ALL
    SELECT N'Versiones_reemplazadas',
           (SELECT COUNT(*) FROM aud.Rechazo WHERE Motivo LIKE N'%reemplazada%'), 3
    UNION ALL
    SELECT N'Completos',
           (SELECT SUM(CASE WHEN Completo = 1 THEN 1 ELSE 0 END) FROM dw.Hechos_Reproduccion), 12
    UNION ALL
    SELECT N'Superan_duracion',
           (SELECT SUM(CASE WHEN SuperaDuracion = 1 THEN 1 ELSE 0 END) FROM dw.Hechos_Reproduccion), 1
    UNION ALL
    SELECT N'Suma_porcentaje',
           (SELECT SUM(PorcentajeVisualizacion) FROM dw.Hechos_Reproduccion), 1727.40
) AS control
ORDER BY indicador;
GO

SELECT Flujo, Motivo, COUNT(*) AS Filas
FROM aud.Rechazo
GROUP BY Flujo, Motivo
ORDER BY Flujo, Motivo;
GO

SELECT ReproduccionBK, SegundosOrigen, SegundosVistos, DuracionSegundos,
       PorcentajeVisualizacion, Completo, SuperaDuracion
FROM dw.Hechos_Reproduccion
WHERE ReproduccionBK IN (N'REP002', N'REP014', N'REP015', N'REP016')
ORDER BY ReproduccionBK;
GO

SELECT UsuarioBK, Nombre, Pais, Segmento, FechaRegistro
FROM dw.Dim_Usuario
WHERE UsuarioBK IN (N'USR002', N'USR003', N'USR004', N'USR005', N'USR010', N'USR015')
ORDER BY UsuarioBK;
GO

SELECT ContenidoBK, Titulo, Categoria, DuracionSegundos
FROM dw.Dim_Contenido
WHERE ContenidoBK IN (N'CNT002', N'CNT003', N'CNT006')
ORDER BY ContenidoBK;
GO

SELECT
    contenido.Categoria,
    COUNT(*) AS Reproducciones,
    CAST(ROUND(AVG(hechos.PorcentajeVisualizacion), 2) AS DECIMAL(5, 2)) AS PorcentajePromedio,
    SUM(CASE WHEN hechos.Completo = 1 THEN 1 ELSE 0 END) AS Completas,
    CAST(ROUND(100.0 * SUM(CASE WHEN hechos.Completo = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS DECIMAL(5, 2)) AS TasaFinalizacion
FROM dw.Hechos_Reproduccion AS hechos
INNER JOIN dw.Dim_Contenido AS contenido
    ON contenido.ContenidoSK = hechos.ContenidoSK
GROUP BY contenido.Categoria
ORDER BY TasaFinalizacion DESC, contenido.Categoria;
GO

SELECT
    usuario.Segmento,
    COUNT(*) AS Reproducciones,
    CAST(ROUND(AVG(hechos.PorcentajeVisualizacion), 2) AS DECIMAL(5, 2)) AS PorcentajePromedio
FROM dw.Hechos_Reproduccion AS hechos
INNER JOIN dw.Dim_Usuario AS usuario
    ON usuario.UsuarioSK = hechos.UsuarioSK
GROUP BY usuario.Segmento
ORDER BY usuario.Segmento;
GO

SELECT tiempo.Anio, tiempo.NombreMes, COUNT(*) AS Reproducciones,
       SUM(CASE WHEN hechos.Completo = 1 THEN 1 ELSE 0 END) AS Completas
FROM dw.Hechos_Reproduccion AS hechos
INNER JOIN dw.Dim_Tiempo AS tiempo
    ON tiempo.TiempoSK = hechos.TiempoSK
GROUP BY tiempo.Anio, tiempo.Mes, tiempo.NombreMes
ORDER BY tiempo.Anio, tiempo.Mes;
GO

SELECT Paquete, Inicio, Fin, FilasUsuarios, FilasContenidos, FilasTiempo,
       FilasHechos, FilasRechazadas, Estado
FROM aud.Ejecucion
ORDER BY EjecucionId DESC;
GO

SELECT Destinatario, Asunto, Estado, Fecha
FROM aud.Notificacion
ORDER BY NotificacionId DESC;
GO
