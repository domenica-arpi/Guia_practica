# Preguntas que pueden hacer en la defensa

Responde con el caso AulaStream, no con una definición suelta. Si te trabas, abre la consulta y señala la fila.

## Modelo

**¿Cuál es el grano de la tabla de hechos?**  
Una reproducción vigente. Cada `ReproduccionBK` aparece una vez. Si el archivo trae dos fechas, se guarda la más reciente.

**¿Por qué USR002 no está dos veces en `Dim_Usuario`?**  
Porque es la misma clave de negocio. La fila del 2 de febrero era Luis Mendoza, segmento Nuevo. La del 18 de junio es Luis A. Mendoza, segmento Recurrente. Esa es la que queda. La otra está en `aud.Rechazo` como versión reemplazada.

**¿Qué es una clave subrogada y cuál es la de negocio?**  
`UsuarioSK` la genera SQL Server y sirve para unir el hecho con la dimensión. `UsuarioBK` (`USR001`, `USR002`…) viene del sistema origen y es la que reconoce el negocio. El Lookup traduce una en la otra.

**¿Por qué hace falta `Dim_Tiempo` si el hecho ya podría guardar una fecha?**  
Porque el análisis por mes, trimestre y día de la semana sale de atributos compartidos, no de repetir el nombre del mes en cada hecho. En este modelo hay 22 fechas, las de las reproducciones que sí se cargaron.

## Transformaciones

**¿Dónde se limpian los nulos?**  
En la columna derivada del flujo de cada archivo. El nombre vacío o el texto `NULL` pasa a «Sin nombre», el correo vacío a «No registrado», el país vacío a «No especificado» y la categoría vacía a «Sin categoría».

**¿Por qué el CSV entra todo como texto?**  
Para que `abc`, `32/13/2024` y la duración vacía no rompan el origen. El Data Conversion intenta el tipo y la fila mala se va a `aud.Rechazo` con un motivo.

**¿Cómo `45 min` termina en 2700?**  
La expresión detecta la palabra `min`, se queda con el 45 y lo multiplica por 60. `1:30:00` se parte en horas, minutos y segundos: 3600 + 1800. Un número pelado, como 1800, ya está en segundos.

**Calcula el porcentaje de REP014.**  
600 segundos entre 1800 de duración. 600 × 100 / 1800 = 33,333…, redondeado a 33,33. Como es menor que 90, `Completo` es 0.

**¿Por qué REP015 no da más de 100?**  
El origen dice 6000 segundos y el video dura 5400. La regla topa el porcentaje en 100, guarda 5400 como segundos de la medida y deja `SegundosOrigen` en 6000 con `SuperaDuracion` = 1. Si no se topara, el tiempo visto mentiría.

**¿Por qué USR004 está en la dimensión y no en los hechos?**  
El usuario es válido: solo le faltaba el nombre y se reemplazó por «Sin nombre». Su reproducción REP005 traía segundos `abc`, y eso sí se rechaza.

## Carga y automatización

**¿Cuántas filas tiene que haber y cuál es la suma de control?**  
15 usuarios, 12 contenidos, 22 fechas y 24 hechos. La suma de los porcentajes es 1727,40. Si ese número no cuadra, el redondeo o un rechazo está distinto.

**¿Qué pasa si ejecuto el paquete dos veces?**  
`SQL_Iniciar` borra hechos, dimensiones, staging y rechazos de la corrida anterior. No duplica. La auditoría de ejecuciones y las notificaciones sí se acumulan, porque son el historial.

**¿A qué hora corre el job y cómo lo probaste sin esperar a mañana?**  
Todos los días a la 01:00. La prueba fue **Start Job at step** y la captura del historial.

**¿Dónde está el correo si el laboratorio no tiene SMTP?**  
En `aud.Notificacion`, con estado `SIMULADO`. Hay una fila que escribe el paquete al cerrar y otra que escribe el paso del job. El operador queda creado para cuando activen Database Mail.

**¿Qué le dices a la gerencia con estos datos?**  
Los usuarios nuevos promedian 46,67 % y los recurrentes 76,71 %. Sin categoría tiene la peor tasa de finalización, 33,33 %, porque dos contenidos llegaron sin clasificar. Visualización promedia 45 % por una reproducción de cero segundos. La acción es clasificar esos contenidos y acortar la primera experiencia de quien recién entra.
