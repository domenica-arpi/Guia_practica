/*
    Job diario del ETL. Ejecutar en SSMS después de que el paquete
    ya corrió bien a mano.

    Antes de ejecutarlo:
    1. Copia el .dtsx compilado a C:\PracticaBI\ETL_AulaStream.dtsx
       (sale de la carpeta bin\Development del proyecto SSIS).
    2. Confirma que el servicio SQL Server Agent está iniciado.
    3. Si el laboratorio usa otra ruta, cambia @RutaPaquete.

    La guía pide notificación por correo en modo simulación.
    El job igual intenta avisar a un operador. La evidencia que se entrega
    es la fila de aud.Notificacion con estado SIMULADO, porque el laboratorio
    normalmente no tiene SMTP.
*/

USE msdb;
GO

DECLARE @RutaPaquete NVARCHAR(400) = N'C:\PracticaBI\ETL_AulaStream.dtsx';
DECLARE @Comando NVARCHAR(500) = N'/FILE "' + @RutaPaquete + N'" /CHECKPOINTING OFF /REPORTING E';

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'JOB_ETL_AulaStream_Diario')
    EXEC msdb.dbo.sp_delete_job
        @job_name = N'JOB_ETL_AulaStream_Diario',
        @delete_unused_schedule = 1;

IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysoperators WHERE name = N'Operador_BI_AulaStream')
    EXEC msdb.dbo.sp_add_operator
        @name = N'Operador_BI_AulaStream',
        @enabled = 1,
        @email_address = N'bi.aulastream@unemi.edu.ec';

EXEC msdb.dbo.sp_add_job
    @job_name = N'JOB_ETL_AulaStream_Diario',
    @enabled = 1,
    @description = N'Carga diaria del data warehouse AulaStream. La notificación de correo queda simulada en aud.Notificacion.',
    @notify_level_eventlog = 2,
    @notify_level_email = 2,
    @notify_email_operator_name = N'Operador_BI_AulaStream';

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'JOB_ETL_AulaStream_Diario',
    @step_name = N'Ejecutar paquete ETL',
    @step_id = 1,
    @subsystem = N'SSIS',
    @command = @Comando,
    @on_success_action = 3,
    @on_fail_action = 4,
    @on_fail_step_id = 3;

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'JOB_ETL_AulaStream_Diario',
    @step_name = N'Simular correo de exito',
    @step_id = 2,
    @subsystem = N'TSQL',
    @database_name = N'DW_AulaStream',
    @command = N'INSERT INTO aud.Notificacion (Destinatario, Asunto, Mensaje, Estado)
VALUES (N''bi.aulastream@unemi.edu.ec'', N''ETL AulaStream finalizado por SQL Server Agent'', N''Simulación de correo: el job diario terminó bien.'', N''SIMULADO'');',
    @on_success_action = 1,
    @on_fail_action = 2;

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'JOB_ETL_AulaStream_Diario',
    @step_name = N'Simular correo de error',
    @step_id = 3,
    @subsystem = N'TSQL',
    @database_name = N'DW_AulaStream',
    @command = N'INSERT INTO aud.Notificacion (Destinatario, Asunto, Mensaje, Estado)
VALUES (N''bi.aulastream@unemi.edu.ec'', N''ETL AulaStream falló'', N''Simulación de correo: el job diario falló. Revise el historial del Agent.'', N''SIMULADO'');',
    @on_success_action = 2,
    @on_fail_action = 2;

EXEC msdb.dbo.sp_update_job
    @job_name = N'JOB_ETL_AulaStream_Diario',
    @start_step_id = 1;

IF EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name = N'SCH_ETL_AulaStream_Diario')
    EXEC msdb.dbo.sp_delete_schedule
        @schedule_name = N'SCH_ETL_AulaStream_Diario',
        @force_delete = 1;

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'SCH_ETL_AulaStream_Diario',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 1,
    @freq_subday_interval = 0,
    @active_start_time = 010000;

EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'JOB_ETL_AulaStream_Diario',
    @schedule_name = N'SCH_ETL_AulaStream_Diario';

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'JOB_ETL_AulaStream_Diario',
    @server_name = N'(LOCAL)';
GO

/* Comprobar programación. No hace falta esperar al día siguiente. */
SELECT
    job.name AS Job,
    schedule.name AS Programacion,
    schedule.active_start_time AS HoraHHMMSS,
    CASE schedule.freq_type WHEN 4 THEN N'Diario' ELSE CAST(schedule.freq_type AS NVARCHAR(10)) END AS Frecuencia
FROM msdb.dbo.sysjobs AS job
INNER JOIN msdb.dbo.sysjobschedules AS vinculo
    ON vinculo.job_id = job.job_id
INNER JOIN msdb.dbo.sysschedules AS schedule
    ON schedule.schedule_id = vinculo.schedule_id
WHERE job.name = N'JOB_ETL_AulaStream_Diario';
GO
