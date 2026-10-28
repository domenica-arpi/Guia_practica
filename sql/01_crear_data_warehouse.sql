/*
    Práctica 3 - Inteligencia de Negocios
    Caso AulaStream: data warehouse en modelo estrella.

    Ejecutar UNA vez en SQL Server Management Studio, antes de abrir el paquete SSIS.
    El script borra y vuelve a crear la base DW_AulaStream.

    Si el laboratorio no permite CREATE DATABASE, no ejecutes este archivo completo.
    Pide al docente el nombre de la base, créala o selecciónala, y corre solo desde
    la marca "OBJETOS".
*/

IF DB_ID(N'DW_AulaStream') IS NOT NULL
BEGIN
    ALTER DATABASE DW_AulaStream SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DW_AulaStream;
END
GO

CREATE DATABASE DW_AulaStream;
GO

USE DW_AulaStream;
GO

/* ===================== OBJETOS ===================== */

CREATE SCHEMA stg;
GO
CREATE SCHEMA dw;
GO
CREATE SCHEMA aud;
GO

CREATE OR ALTER FUNCTION dw.fn_Colapsar (@texto NVARCHAR(200))
RETURNS NVARCHAR(200)
AS
BEGIN
    IF @texto IS NULL
        RETURN N'';

    DECLARE @limpio NVARCHAR(200) = LTRIM(RTRIM(
        REPLACE(REPLACE(REPLACE(@texto, CHAR(9), N' '), CHAR(13), N' '), CHAR(10), N' ')
    ));

    WHILE CHARINDEX(N'  ', @limpio) > 0
        SET @limpio = REPLACE(@limpio, N'  ', N' ');

    RETURN @limpio;
END
GO

CREATE OR ALTER FUNCTION dw.fn_TituloPropio (@texto NVARCHAR(200))
RETURNS NVARCHAR(200)
AS
BEGIN
    DECLARE @resto NVARCHAR(200) = dw.fn_Colapsar(@texto);
    DECLARE @resultado NVARCHAR(200) = N'';
    DECLARE @palabra NVARCHAR(200);

    WHILE LEN(@resto) > 0
    BEGIN
        IF CHARINDEX(N' ', @resto) > 0
        BEGIN
            SET @palabra = LEFT(@resto, CHARINDEX(N' ', @resto) - 1);
            SET @resto = LTRIM(SUBSTRING(@resto, CHARINDEX(N' ', @resto) + 1, 200));
        END
        ELSE
        BEGIN
            SET @palabra = @resto;
            SET @resto = N'';
        END

        SET @palabra = UPPER(LEFT(@palabra, 1)) + LOWER(SUBSTRING(@palabra, 2, 200));
        SET @resultado = @resultado + CASE WHEN @resultado = N'' THEN N'' ELSE N' ' END + @palabra;
    END

    RETURN @resultado;
END
GO

CREATE OR ALTER FUNCTION dw.fn_Pais (@texto NVARCHAR(80))
RETURNS NVARCHAR(80)
AS
BEGIN
    DECLARE @t NVARCHAR(80) = LOWER(dw.fn_Colapsar(@texto));

    IF @t IN (N'', N'null')
        RETURN N'No especificado';

    RETURN CASE @t
        WHEN N'ecuador' THEN N'Ecuador'
        WHEN N'colombia' THEN N'Colombia'
        WHEN N'peru' THEN N'Perú'
        WHEN N'perú' THEN N'Perú'
        WHEN N'mexico' THEN N'México'
        WHEN N'méxico' THEN N'México'
        WHEN N'chile' THEN N'Chile'
        WHEN N'argentina' THEN N'Argentina'
        WHEN N'espana' THEN N'España'
        WHEN N'españa' THEN N'España'
        WHEN N'no especificado' THEN N'No especificado'
        ELSE UPPER(LEFT(@t, 1)) + SUBSTRING(@t, 2, 80)
    END
END
GO

CREATE OR ALTER FUNCTION dw.fn_Dispositivo (@texto NVARCHAR(30))
RETURNS NVARCHAR(30)
AS
BEGIN
    DECLARE @t NVARCHAR(30) = LOWER(dw.fn_Colapsar(@texto));

    RETURN CASE
        WHEN @t IN (N'', N'null') THEN N'No especificado'
        WHEN @t = N'web' THEN N'Web'
        WHEN @t IN (N'movil', N'móvil') THEN N'Móvil'
        WHEN @t IN (N'smart tv', N'smarttv') THEN N'Smart TV'
        ELSE dw.fn_Colapsar(@texto)
    END
END
GO

CREATE TABLE stg.Usuario
(
    CargaId       INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    UsuarioBK     NVARCHAR(20)  NOT NULL,
    Nombre        NVARCHAR(120) NOT NULL,
    Correo        NVARCHAR(150) NOT NULL,
    Pais          NVARCHAR(80)  NOT NULL,
    FechaRegistro DATE          NOT NULL,
    Segmento      NVARCHAR(40)  NOT NULL
);

CREATE TABLE stg.UsuarioListo
(
    UsuarioBK     NVARCHAR(20)  NOT NULL PRIMARY KEY,
    Nombre        NVARCHAR(120) NOT NULL,
    Correo        NVARCHAR(150) NOT NULL,
    Pais          NVARCHAR(80)  NOT NULL,
    FechaRegistro DATE          NOT NULL,
    Segmento      NVARCHAR(40)  NOT NULL
);

CREATE TABLE stg.Contenido
(
    CargaId           INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    ContenidoBK       NVARCHAR(20)  NOT NULL,
    Titulo            NVARCHAR(200) NOT NULL,
    Categoria         NVARCHAR(80)  NOT NULL,
    DuracionSegundos  INT           NOT NULL,
    Tipo              NVARCHAR(40)  NOT NULL,
    FechaPublicacion  DATE          NOT NULL
);

CREATE TABLE stg.ContenidoListo
(
    ContenidoBK       NVARCHAR(20)  NOT NULL PRIMARY KEY,
    Titulo            NVARCHAR(200) NOT NULL,
    Categoria         NVARCHAR(80)  NOT NULL,
    DuracionSegundos  INT           NOT NULL,
    Tipo              NVARCHAR(40)  NOT NULL,
    FechaPublicacion  DATE          NOT NULL
);

CREATE TABLE stg.Reproduccion
(
    CargaId         INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    ReproduccionBK  NVARCHAR(20) NOT NULL,
    UsuarioBK       NVARCHAR(20) NOT NULL,
    ContenidoBK     NVARCHAR(20) NOT NULL,
    Fecha           DATE         NOT NULL,
    SegundosOrigen  INT          NOT NULL,
    Dispositivo     NVARCHAR(30) NOT NULL
);

CREATE TABLE stg.ReproduccionLista
(
    ReproduccionBK  NVARCHAR(20) NOT NULL PRIMARY KEY,
    UsuarioBK       NVARCHAR(20) NOT NULL,
    ContenidoBK     NVARCHAR(20) NOT NULL,
    Fecha           DATE         NOT NULL,
    SegundosOrigen  INT          NOT NULL,
    Dispositivo     NVARCHAR(30) NOT NULL
);
GO

CREATE TABLE dw.Dim_Usuario
(
    UsuarioSK     INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    UsuarioBK     NVARCHAR(20)  NOT NULL UNIQUE,
    Nombre        NVARCHAR(120) NOT NULL,
    Correo        NVARCHAR(150) NOT NULL,
    Pais          NVARCHAR(80)  NOT NULL,
    Segmento      NVARCHAR(40)  NOT NULL,
    FechaRegistro DATE          NOT NULL
);

CREATE TABLE dw.Dim_Contenido
(
    ContenidoSK       INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    ContenidoBK       NVARCHAR(20)  NOT NULL UNIQUE,
    Titulo            NVARCHAR(200) NOT NULL,
    Categoria         NVARCHAR(80)  NOT NULL,
    DuracionSegundos  INT           NOT NULL,
    Tipo              NVARCHAR(40)  NOT NULL,
    FechaPublicacion  DATE          NOT NULL
);

CREATE TABLE dw.Dim_Tiempo
(
    TiempoSK    INT           NOT NULL PRIMARY KEY,
    Fecha       DATE          NOT NULL UNIQUE,
    Anio        SMALLINT      NOT NULL,
    Mes         TINYINT       NOT NULL,
    NombreMes   NVARCHAR(20)  NOT NULL,
    Trimestre   TINYINT       NOT NULL,
    DiaSemana   NVARCHAR(20)  NOT NULL
);

CREATE TABLE dw.Hechos_Reproduccion
(
    ReproduccionSK           BIGINT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    ReproduccionBK           NVARCHAR(20)   NOT NULL UNIQUE,
    UsuarioSK                INT            NOT NULL,
    ContenidoSK              INT            NOT NULL,
    TiempoSK                 INT            NOT NULL,
    SegundosVistos           INT            NOT NULL,
    SegundosOrigen           INT            NOT NULL,
    DuracionSegundos         INT            NOT NULL,
    PorcentajeVisualizacion  DECIMAL(5, 2)  NOT NULL,
    Completo                 BIT            NOT NULL,
    SuperaDuracion           BIT            NOT NULL,
    Dispositivo              NVARCHAR(30)   NOT NULL,
    CONSTRAINT FK_Hechos_Usuario
        FOREIGN KEY (UsuarioSK) REFERENCES dw.Dim_Usuario (UsuarioSK),
    CONSTRAINT FK_Hechos_Contenido
        FOREIGN KEY (ContenidoSK) REFERENCES dw.Dim_Contenido (ContenidoSK),
    CONSTRAINT FK_Hechos_Tiempo
        FOREIGN KEY (TiempoSK) REFERENCES dw.Dim_Tiempo (TiempoSK)
);
GO

CREATE TABLE aud.Rechazo
(
    RechazoId   INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    Flujo       NVARCHAR(40)  NOT NULL,
    Clave       NVARCHAR(50)  NOT NULL,
    Motivo      NVARCHAR(200) NOT NULL,
    FilaOrigen  INT           NULL,
    FechaCarga  DATETIME2     NOT NULL CONSTRAINT DF_Rechazo_Fecha DEFAULT SYSDATETIME()
);

CREATE TABLE aud.Ejecucion
(
    EjecucionId      INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    Paquete          NVARCHAR(100) NOT NULL,
    Inicio           DATETIME2     NOT NULL,
    Fin              DATETIME2     NULL,
    FilasUsuarios    INT           NULL,
    FilasContenidos  INT           NULL,
    FilasTiempo      INT           NULL,
    FilasHechos      INT           NULL,
    FilasRechazadas  INT           NULL,
    Estado           NVARCHAR(20)  NOT NULL
);

CREATE TABLE aud.Notificacion
(
    NotificacionId  INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    Destinatario    NVARCHAR(150) NOT NULL,
    Asunto          NVARCHAR(200) NOT NULL,
    Mensaje         NVARCHAR(500) NOT NULL,
    Estado          NVARCHAR(20)  NOT NULL,
    Fecha           DATETIME2     NOT NULL CONSTRAINT DF_Notificacion_Fecha DEFAULT SYSDATETIME()
);
GO
