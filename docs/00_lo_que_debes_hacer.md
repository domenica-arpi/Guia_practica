# Lo que tienes que hacer tú

La práctica 3 no se puede cerrar solo con archivos. La rúbrica pide el paquete de Integration Services, la ejecución en SQL Server, el job del Agent y capturas tuyas. Este repositorio deja armado el caso, los datos, los scripts y el informe. El laboratorio lo tienes que recorrer tú, porque el docente va a preguntar y la nota depende de esa defensa.

Caso que vas a implementar: **AulaStream**, la plataforma de contenidos de una organización. La gerencia quiere saber qué materiales sí se terminan de ver.

## Antes del laboratorio (en tu casa, 20 minutos)

1. Lee esta página y después `docs/01_guia_laboratorio_ssis.md`.
2. Si tienes Python 3, en la carpeta del proyecto ejecuta:

   ```bash
   python3 etl/pipeline.py
   ```

   Revisa `salida/validacion.md`. Esos son los números que debe devolver tu paquete. Memoriza sobre todo: **15 usuarios, 12 contenidos, 22 fechas, 24 hechos, suma de porcentajes 1727.40**.
3. Copia la carpeta `datos` a una memoria o al escritorio. Son tres CSV. No los abras y guardes con Excel: Excel cambia las fechas y los acentos.
4. Anota los nombres de los cuatro integrantes. La guía es grupal.

## En el laboratorio (esto no lo puedo hacer desde aquí)

Hazlo en este orden. El detalle de cada clic está en la guía de SSIS.

1. Abre SQL Server Management Studio y ejecuta `sql/01_crear_data_warehouse.sql`. Tiene que aparecer la base `DW_AulaStream`.
2. Copia los tres CSV a `C:\PracticaBI\datos\`.
3. Crea el proyecto de Integration Services `ETL_AulaStream` y arma el paquete como está en la guía: limpieza, columnas derivadas, destinos `Dim_Usuario`, `Dim_Contenido` y `Hechos_Reproduccion`.
4. Ejecuta el paquete con el botón Inicio. Tiene que terminar en verde.
5. Ejecuta `sql/03_consultas_validacion.sql`. La primera tabla tiene que decir **OK** en las nueve filas. Si alguna dice REVISAR, no sigas al Agent: corrige el flujo.
6. Copia el `.dtsx` compilado a `C:\PracticaBI\ETL_AulaStream.dtsx`.
7. Crea el job `JOB_ETL_AulaStream_Diario` para todos los días a la 01:00. Puedes usar el asistente o `sql/04_job_sql_server_agent.sql`.
8. Ejecuta el job una vez, a mano, con **Start Job at step**. No esperes al día siguiente.
9. Abre `aud.Notificacion` y confirma la fila con estado `SIMULADO`. Esa fila es la notificación por correo que pide la guía. El laboratorio casi nunca tiene servidor de correo.
10. Toma las 13 capturas de la lista de abajo. Que se vea tu usuario de Windows o el nombre del servidor del laboratorio.

## Capturas que tienes que pegar

1. Proyecto SSIS con el control flow completo.
2. Data flow de usuarios, con la limpieza de nulos y la conversión de la fecha.
3. Expresión de la columna derivada que limpia nulos.
4. Data flow de contenidos, con la duración convertida a segundos.
5. Data flow de hechos, con los dos Lookup y la columna de porcentaje.
6. Expresión del porcentaje de visualización.
7. Ejecución del paquete en verde.
8. Consulta de control con los nueve OK.
9. Cuatro hechos de prueba: REP002 (74.07), REP014 (33.33), REP015 (100 y supera duración) y REP016 (0).
10. Job en el Agent, con la programación diaria a la 01:00.
11. Historial del job en Succeeded, o el error real si falló y cómo lo corregiste.
12. Fila de `aud.Notificacion` en estado SIMULADO.
13. Consulta de finalización por categoría.

## Informe

Abre `docs/02_informe_practica.md`.

- Pon los nombres, el paralelo y la fecha de entrega.
- Pega las capturas en el anexo, cada una con su número.
- Cada integrante escribe su conclusión **con sus propias palabras**. Hay cuatro borradores para que no se repitan el mismo ángulo. Cámbialos: mete un error que les haya pasado en el laboratorio o un número que tú hayas leído en pantalla. Si los cuatro entregan el borrador igual, se nota.
- Pasa el archivo a Word o a PDF. Revisa tildes antes de enviar. La rúbrica califica ortografía con hasta 3 puntos.
- La bibliografía ya está en APA con las fuentes de la guía. No la borres.

## Defensa oral

Estudia `docs/03_preguntas_defensa.md`. El docente puede preguntar a cualquier integrante, y de eso depende la nota. Tienes que poder explicar, sin leer:

- qué es la tabla de hechos y qué es una dimensión;
- por qué `USR002` y `CNT002` quedan una sola vez;
- cómo se calcula el porcentaje y por qué REP015 no pasa de 100;
- qué hace cada tarea del control flow;
- a qué hora corre el job y dónde queda la simulación del correo.

## Reparto sugerido para el grupo de cuatro

| Integrante | Se encarga de construir | Tiene que poder explicar |
| --- | --- | --- |
| 1 | Script de la base, conexiones y flujo de usuarios | Nulos, fechas y rechazos |
| 2 | Flujos de contenidos y de reproducciones | Duración en segundos y tipos de dato |
| 3 | Dimensiones, hechos y porcentaje | Modelo estrella y la medida |
| 4 | Job del Agent, validación y armado del PDF | Programación y los números OK |

Los cuatro revisan el paquete juntos antes de la defensa.
