# Filosofía del repositorio

## Objetivo

Este repositorio existe para una sola cosa: **arrancar un entorno de desarrollo funcional, consistente y productivo en el menor tiempo posible**, sin importar el sistema operativo ni el hardware.

La meta es eliminar fricción. Cero improvisación. Si una máquina muere, se formatea o se cambia, el entorno vuelve a levantarse con uno o pocos comandos.

El hardware es reemplazable. El tiempo y el enfoque no.

---

## Problema que resuelve

Configurar un entorno de desarrollo desde cero suele implicar:

- Repetir pasos manuales que nadie documenta bien.
- Olvidar configuraciones pequeñas pero críticas.
- Diferencias sutiles entre máquinas que generan errores difíciles de rastrear.
- Pérdida de horas o días cada vez que se cambia de equipo.

Este repositorio elimina ese costo oculto.

---

## Filosofía

### 1. Todo debe ser reproducible

Si no puede instalarse desde cero de forma automatizada, no pertenece aquí.

Cada script y cada configuración deben poder ejecutarse múltiples veces sin romper nada. El resultado final debe ser el mismo siempre.

---

### 2. El entorno debe poder destruirse sin miedo

Este repositorio **no es un backup**.

Debe ser posible:

- Borrar el sistema operativo.
- Cambiar de máquina.
- Reinstalar todo desde cero.

Sin pérdida de información crítica ni configuraciones clave.

Si algo no puede recrearse automáticamente, está mal planteado.

---

### 3. Cero secretos en el repositorio

Nunca se versionan:

- Tokens
- API keys
- Contraseñas
- Certificados privados

Este repositorio asume que los secretos se gestionan externamente mediante gestores de contraseñas, variables de entorno o servicios dedicados.

Aquí solo vive la **estructura**, nunca los valores sensibles. Es un repositorio público por diseño. Es convención sobre configuración, no magia oculta. Se debe usar para compartir y colaborar sin riesgos de seguridad.

---

### 4. Separación clara entre configuración y lógica

- Las listas de paquetes no contienen lógica.
- Los scripts no contienen decisiones mágicas.
- Las configuraciones no dependen de una máquina específica.

Cada pieza tiene una responsabilidad clara. Si una parte empieza a hacer de todo, se rompe.

---

### 5. Idempotencia como regla, no como excepción

Todo comando debe poder ejecutarse más de una vez sin efectos colaterales.

Esto permite:

- Actualizar sin miedo.
- Reparar instalaciones rotas.
- Reejecutar procesos sin limpiar manualmente.

Un script frágil es peor que no tener script.

---

### 6. Productividad desde el minuto uno

El objetivo no es tener el entorno "perfecto".

El objetivo es poder:

- Abrir el editor
- Clonar un repo
- Ejecutar el proyecto

En minutos, no en horas.

Las personalizaciones estéticas van después. El flujo de trabajo va primero.

---

## Por qué usar este repositorio

- Reduce el tiempo de setup a minutos.
- Elimina diferencias entre entornos.
- Facilita cambiar de sistema operativo o hardware.
- Hace explícitas las decisiones técnicas.
- Reduce el estrés operativo.

Es una inversión única que se paga cada vez que algo falla.

---

## Qué NO es este repositorio

- No es un backup de archivos personales.
- No es un lugar para hacks temporales.
- No es una colección de experimentos.
- No es específico de una sola máquina.

Si algo no aporta a la reproducibilidad y productividad, no pertenece aquí.

---

## Regla final

Si una configuración, script o herramienta no ayuda a **trabajar mejor desde el primer momento**, se elimina.

Menos cosas. Más foco.

El entorno debe adaptarse al trabajo, no al revés.
