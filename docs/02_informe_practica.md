# Informe de práctica 3

**Universidad Estatal de Milagro**  
Facultad de Ciencias e Ingenierías  
Carrera de Software, modalidad presencial  
Asignatura: Inteligencia de Negocios  

| Campo | Dato |
| --- | --- |
| Guía | G003-S10-SOFTWARE2019-PRESENCIAL-INTELIGENCIA DE NEGOCIOS-B1 |
| Práctica | 3. Diseño de procesos ETL |
| Docente de la asignatura | Arévalo Gamboa Lissett Margarita |
| Docente de la práctica | Oviedo Armijos Omar Andrés |
| Integrantes | [NOMBRE 1, CÉDULA] · [NOMBRE 2, CÉDULA] · [NOMBRE 3, CÉDULA] · [NOMBRE 4, CÉDULA] |
| Paralelo | [PARALELO] |
| Fecha de entrega | [FECHA] |

Antes de exportar a PDF: completa la tabla, pega las capturas del anexo y sustituye las conclusiones borrador. Cada persona escribe la suya.

## 1. Objetivo

Implementar el proceso ETL de AulaStream en SQL Server Integration Services y automatizar la carga con un job de SQL Server Agent, de modo que el área administrativa consulte un data warehouse ya limpio.

## 2. Caso y grano del modelo

AulaStream publica videos y audios de formación. La gerencia no decide con el archivo plano: necesita saber qué contenidos se terminan, en qué mes se concentra el uso y si los usuarios nuevos abandonan antes que los recurrentes. Howson (2009) plantea la inteligencia de negocios como el paso de datos dispersos a información para decidir. En este caso la decisión es concreta: qué material se mantiene, cuál se reclasifica y a quién se le ofrece una ruta más corta.

El modelo es una estrella. Auribox Training (2017) separa la tabla de hechos, donde viven las medidas, de las dimensiones, que describen el contexto. Ramos (2011) usa ese mismo criterio en la plataforma de Microsoft. El grano de `dw.Hechos_Reproduccion` es **una reproducción vigente**: si el mismo código llega dos veces, se conserva la de fecha más reciente. Las dimensiones son `dw.Dim_Usuario`, `dw.Dim_Contenido` y `dw.Dim_Tiempo`.

La medida principal es el porcentaje de visualización:

- 0 si no hay segundos vistos;
- 100 si los segundos alcanzan o superan la duración del contenido;
- `ROUND(segundos × 100 / duración, 2)` en el resto.

`Completo` vale 1 cuando el porcentaje es mayor o igual que 90. Si el origen trae más segundos que la duración, la medida se recorta y `SuperaDuracion` queda en 1. Así un error del reproductor no infla el tiempo visto.

## 3. Fuentes y reglas de limpieza

Se usaron tres archivos delimitados por coma, leídos como texto Unicode para que la conversión ocurra dentro del flujo y las filas dañadas se puedan rechazar:

| Archivo | Filas leídas | Qué trae de problema |
| --- | ---: | --- |
| `Usuarios.csv` | 18 | Nombre vacío, correo vacío, país en minúsculas, segmento vacío, fecha `32/13/2024`, clave vacía, `USR002` repetido |
| `Contenidos.csv` | 15 | Duración en minutos, en `hh:mm:ss`, en segundos o vacía; categoría vacía; clave vacía; `CNT002` repetido |
| `Reproducciones.csv` | 32 | Segundos `abc` y negativos, fecha imposible, dispositivo vacío, usuario o contenido inexistente, `REP002` repetido |

La limpieza de nulos y el recorte de espacios ocurren en columnas derivadas. La fecha `dd/mm/aaaa` se normaliza a `aaaa-mm-dd` y después el Data Conversion la pasa a fecha, con la fila de error redirigida a `aud.Rechazo`. La duración se interpreta en el mismo flujo: `45 min` = 2700 segundos, `1:30:00` = 5400, `25:00` = 1500. SpanishPASS (2017) muestra precisamente esta idea de SSIS: el origen entrega filas y las transformaciones las preparan antes del destino.

Cuando hay dos versiones válidas del mismo código, se conserva la fecha más reciente. `USR002` queda como Luis A. Mendoza, segmento Recurrente. `CNT002` queda como «Modelo estrella actualizado», de 5400 segundos. La versión anterior no se borra en silencio: entra a `aud.Rechazo` con el motivo «Versión anterior reemplazada por un registro más reciente».

## 4. Flujo del ETL

```text
CSV de usuarios, contenidos y reproducciones
        |
        v
Limpieza de nulos + conversión de tipos + rechazo de calidad
        |
        v
stg.Usuario (16)   stg.Contenido (13)   stg.Reproduccion (28)
        |
        v
Quedarse con la versión más reciente y cargar Dim_Tiempo
        |
        v
stg.UsuarioListo (15) -> dw.Dim_Usuario
stg.ContenidoListo (12) -> dw.Dim_Contenido
        |
        v
Lookup de usuario y de contenido
        |
        v
Columna derivada: porcentaje, completo, segundos recortados, TiempoSK
        |
        v
dw.Hechos_Reproduccion (24)
        |
        v
Borrar fechas sin hechos, cerrar aud.Ejecucion
y grabar el correo simulado en aud.Notificacion
```

El paquete se llama `ETL_AulaStream`. El control flow tiene nueve tareas: tres Execute SQL Task y seis Data Flow. Los destinos que pide la guía son `dw.Dim_Usuario` y `dw.Hechos_Reproduccion`. También se carga `dw.Dim_Contenido` y `dw.Dim_Tiempo`, porque un hecho sin esas claves no se puede analizar por categoría ni por mes.

El job `JOB_ETL_AulaStream_Diario` ejecuta el `.dtsx` todos los días a la 01:00. Si el paso termina bien, el siguiente inserta una notificación con estado `SIMULADO`. Si falla, el paso 3 inserta la notificación de error y el job queda en fallo. El operador `Operador_BI_AulaStream` queda asociado al job para cuando exista Database Mail. Mientras el laboratorio no tenga SMTP, la evidencia del correo es la tabla `aud.Notificacion`.

## 5. Resultados

La carga de referencia, con las mismas reglas, produce los siguientes totales. Después de ejecutar el paquete, `sql/03_consultas_validacion.sql` debe marcar OK en los nueve indicadores. La captura de esa cuadrícula va en el anexo.

| Indicador | Esperado |
| --- | ---: |
| `Dim_Usuario` | 15 |
| `Dim_Contenido` | 12 |
| `Dim_Tiempo` | 22 |
| `Hechos_Reproduccion` | 24 |
| Rechazos de calidad | 11 |
| Versiones reemplazadas | 3 |
| Reproducciones completas | 12 |
| Filas que superan la duración | 1 |
| Suma de porcentajes | 1727.40 |

De 65 filas de origen, 11 no entran al modelo por calidad (16,9 %) y 3 son versiones viejas reemplazadas. El rechazo no es una pérdida escondida: cada motivo queda en `aud.Rechazo`.

Ejemplos que demuestran el cálculo:

| Hecho | Cálculo | Resultado |
| --- | --- | --- |
| REP014 | 600 / 1800 × 100 | 33,33 % y no completa |
| REP002 | 4000 / 5400 × 100, redondeado | 74,07 %. Se descartó la versión del 20/06 |
| REP011 | 1890 / 2100 × 100 | 90,00 % y completa |
| REP015 | 6000 segundos contra una duración de 5400 | 100 %, medida recortada a 5400, `SuperaDuracion` = 1 |
| REP016 | 0 segundos | 0 % |

`USR004` sí entra a la dimensión, con el nombre «Sin nombre», y no tiene hechos: su única reproducción traía el texto `abc` en los segundos. Conviene mostrarlo en la defensa, porque separa un usuario válido de un evento inválido.

### Lectura para la gerencia

| Categoría | Reproducciones | % promedio | Tasa de finalización |
| --- | ---: | ---: | ---: |
| Comercial | 3 | 80,00 | 66,67 % |
| Inteligencia de negocios | 4 | 76,85 | 50,00 % |
| Analítica, bases de datos, finanzas, servicio y talento humano | 2 cada una | 75,00 | 50,00 % |
| Gobierno de datos | 2 | 70,00 | 50,00 % |
| Visualización | 2 | 45,00 | 50,00 % |
| Sin categoría | 3 | 66,67 | 33,33 % |

La tasa más baja está en **Sin categoría** (33,33 %). Ahí cayeron «Limpieza de datos» y «Podcast de KPI» porque el archivo venía sin categoría. Antes de comparar áreas, catalogación tiene que completar ese dato: si no, el tablero castiga a un contenido por un vacío de origen.

El promedio más bajo es **Visualización** (45 %), empujado por REP016, que duró 0 segundos. El contenido con más reproducciones es «Indicadores de ventas» (3), con 80 % de promedio. Julio es el mes con más actividad (4 reproducciones).

Por segmento, los usuarios recurrentes promedian **76,71 %** en 17 reproducciones. Los nuevos promedian **46,67 %** en 5. La diferencia sostiene una acción concreta: la bienvenida de un usuario nuevo no debería abrir por el material más largo. Méndez del Río (2006) insiste en que el valor del proyecto aparece cuando el indicador cambia una decisión de gestión, no cuando el cubo solo se publica.

## 6. Conclusiones

Cada bloque es un borrador. El integrante lo reescribe con lo que vio en su pantalla y lo firma con su nombre. Un texto idéntico al de otra persona no sirve en la defensa.

### Integrante 1 — calidad de los datos

[NOMBRE 1]

De las 65 filas de origen, 11 se rechazaron y 3 quedaron como versión anterior. El caso que más me sirvió para entender la limpieza fue `USR004`: el usuario entra a la dimensión aunque el nombre viniera vacío, pero su reproducción no entra a los hechos porque los segundos decían `abc`. Si esa fila hubiera llegado al porcentaje, el promedio de Visualización quedaría falso. Dejar el motivo en `aud.Rechazo` permite devolver el archivo a quien lo genera, en lugar de corregirlo a mano cada noche. En el laboratorio comprobé este conteo en la consulta de control: [anota aquí el OK que viste].

### Integrante 2 — modelo estrella

[NOMBRE 2]

El grano del hecho es una reproducción vigente, no el usuario ni el contenido. Por eso `USR002` y `CNT002`, que venían dos veces, ocupan una sola fila de dimensión: se guardó la fecha más reciente y la anterior quedó auditada. Sin `Dim_Tiempo` podría filtrar por usuario, pero no podría decir que julio concentra cuatro reproducciones. La separación entre dimensiones y hechos es la que describe el modelo estrella, y en el paquete se ve en los destinos distintos: las listas limpias van a `Dim_Usuario` y a `Dim_Contenido`, y solo después el Lookup resuelve la clave subrogada del hecho.

### Integrante 3 — porcentaje de visualización

[NOMBRE 3]

La columna derivada del flujo de hechos aplica tres reglas. REP014 da 33,33 porque 600 segundos son la tercera parte de 1800. REP011 da 90 y por eso `Completo` vale 1. REP015 traía 6000 segundos sobre un video de 5400: el porcentaje se queda en 100, la medida se recorta a 5400 y `SuperaDuracion` marca el error. Sin ese tope, el tiempo visto de Inteligencia de negocios quedaría por encima de la duración real del material. La suma de los 24 porcentajes es 1727,40 y es el número que usé para saber que el Data Flow no había redondeado de otra forma.

### Integrante 4 — automatización

[NOMBRE 4]

Ejecutar el paquete a mano sirve para la prueba, pero la carga de un data warehouse tiene que repetirse sola. El job `JOB_ETL_AulaStream_Diario` quedó diario a la 01:00, que es una hora de bajo uso. Lo corrí una vez desde el Agent para no esperar al día siguiente y el historial mostró el resultado. El correo se simuló en `aud.Notificacion` con estado SIMULADO, porque en el laboratorio no hay servidor SMTP. Si el `.dtsx` cambia de carpeta, el job falla aunque el paquete en Visual Studio siga en verde: la ruta del paso tiene que ser la del archivo copiado a `C:\PracticaBI`.

## 7. Recomendaciones

1. Completar la categoría de CNT003 y CNT006 en el sistema origen. Mientras lleguen vacías, el tablero seguirá mostrando «Sin categoría» como el grupo que menos finaliza.
2. Revisar el reproductor que generó los 6000 segundos de REP015. El warehouse ya no infla la medida, pero el error sigue naciendo en la aplicación.
3. Activar Database Mail cuando la universidad entregue un SMTP. El operador ya está creado; la tabla de simulación puede quedar como respaldo.
4. Conservar historia del segmento del usuario si más adelante preguntan cuándo alguien pasó de Nuevo a Recurrente. Hoy la dimensión guarda solo la versión vigente.
5. Valorar, para un entorno sin licencia de SQL Server, una herramienta libre de ETL. Durá Subiela (2011) compara ese tipo de opciones y sirve como ruta si el proyecto sale del laboratorio.

## 8. Bibliografía

Auribox Training. (2017, 15 de junio). *Tabla de hechos y dimensiones | Modelo estrella* [Video]. YouTube. https://youtu.be/HVZO18FUJQY

Durá Subiela, S. (2011). *Sistemas de información BI: estado actual y herramientas de software libre* [Trabajo final de máster, Universitat Oberta de Catalunya]. http://openaccess.uoc.edu/webapps/o2/bitstream/10609/8175/1/sduras_TFM_0611.pdf

Howson, C. (2009). *Business Intelligence*. McGraw-Hill.

Méndez del Río, L. (2006). *Más allá del Business Intelligence: 16 experiencias de éxito*. Ediciones Gestión 2000.

Ramos, S. (2011). *Microsoft Business Intelligence: vea el cubo medio lleno*. SolidQ Press.

SpanishPASS. (2017, 17 de abril). *Introducción a SSIS* [Video]. YouTube. https://youtu.be/O3JQEF0ZP6Q

## 9. Anexos

Pega cada captura debajo de su título. Si una ventana no cabe, recorta solo después de que se lean los números.

### Anexo 1. Control flow del paquete

[CAPTURA 1]

### Anexo 2. Limpieza y conversión del flujo de usuarios

[CAPTURA 2]

### Anexo 3. Expresión de limpieza de nulos

[CAPTURA 3]

### Anexo 4. Conversión de la duración en el flujo de contenidos

[CAPTURA 4]

### Anexo 5. Lookup y columna derivada del flujo de hechos

[CAPTURA 5]

### Anexo 6. Expresión del porcentaje de visualización

[CAPTURA 6]

### Anexo 7. Ejecución del paquete en verde

[CAPTURA 7]

### Anexo 8. Consulta de control con los nueve OK

[CAPTURA 8]

### Anexo 9. Hechos REP002, REP014, REP015 y REP016

[CAPTURA 9]

### Anexo 10. Programación diaria del job a la 01:00

[CAPTURA 10]

### Anexo 11. Historial de ejecución del job

[CAPTURA 11]

### Anexo 12. Notificación simulada

[CAPTURA 12]

### Anexo 13. Finalización por categoría

[CAPTURA 13]
