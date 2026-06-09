#!/bin/bash

set -e

# Validación de parámetros
if [ $# -ne 5 ]; then
  echo "Uso: $0 \"NOMBRE_DEL_HOTEL\" \"ACCOUNT\" \"WEBSITE\" \"BOOKING_ENGINE\" \"LINK_TICKET\""
  exit 1
fi

NOMBRE_DEL_HOTEL="$1"
ACCOUNT="$2"
WEBSITE="$3"
BOOKING_ENGINE="$4"
LINK_TICKET="$5"
FECHA=$(date +"%Y-%m-%d")

OUTPUT_FILE="${ACCOUNT}.md"

cat > "$OUTPUT_FILE" <<EOF
## Checklist operativo de configuración de cuenta

- Hotel: ${NOMBRE_DEL_HOTEL}
- Cuenta: ${ACCOUNT}
- Dominio web: ${WEBSITE}
- Motor de reservas: ${BOOKING_ENGINE}
- Ticket: ${LINK_TICKET}
- Fecha de creación: ${FECHA}

---

### 🟩 Inicio

- [ ] Verificar que el ticket contiene nombre del hotel, dominio y motor de reservas
- [ ] Marcar ticket como “En progreso”
- [ ] Confirmar que dominio y motor están correctos (validar ortografía y TLD: .com / .com.mx / .hotel / etc)
- [ ] Confirmar si la cuenta ya existe en Revenatium (evitar duplicados)

---

### 📄 Registro en hoja de seguimiento (Google Sheets “Cuentas de Analytics GA4”)

- [ ] Duplicar fila plantilla manteniendo formato
- [ ] Verificar que no existan IDs previamente asignados a este hotel

---

### 📊 Propiedad GA4

- [ ] Crear propiedad GA4 en cuenta principal Revenatium
- [ ] Configurar:
- [ ] Zona horaria: México/México City
- [ ] Moneda: MXN
- [ ] Obtener Measurement ID (G-XXXXXXX)
- [ ] Pegar en hoja de seguimiento columna GA4
- [ ] Configurar:
- [ ] Conexiones básicas de datos
- [ ] Audiencias (si aplica)
- [ ] Activar Google Signals (si aplica)
- [ ] Documentar cualquier condición especial de implementación

---

### 🏷️ Google Tag Manager

- [ ] Crear contenedor con nombre del hotel o dominio
- [ ] Añadir GTM-XXXXXX a hoja de seguimiento (columna TAG MANAGER)

**Ejecutar revenatium_tools:**

- [ ] Iniciar sesión correctamente

**Registrar la cuenta con:**

- [ ] ACCOUNT: ${ACCOUNT}
- [ ] GA4 ID: {{MEASUREMENT_ID}}
- [ ] GTM ID: {{ID_TAG_MANAGER}}
- [ ] Llenar formulario del hotel
- [ ] Generar JSON de etiquetas
- [ ] Importar JSON en contenedor

**Revisar:**

- [ ] Eventos necesarios incluidos
- [ ] Variables completas
- [ ] Triggers correctos
- [ ] Publicar contenedor

---

### 📈 Reporte CRS en Looker Studio

- [ ] Crear fuente de datos desde la propiedad GA4
- [ ] Clonar reporte base de Revenatium
- [ ] Reemplazar la fuente del reporte
- [ ] Actualizar título del reporte con nombre del hotel
- [ ] Hacerlo público
- [ ] Obtener enlace y pegar en hoja de seguimiento columna REPORTE CRS

---

### 🔁 Validación final

- [ ] Probar datos vivos con DebugView GA4
- [ ] Testear eventos básicos en GTM Preview
- [ ] Verificar que el dominio del sitio carga el contenedor GTM
- [ ] Quitar etiquetas “dummy” si existían
- [ ] Revisar consistencia de nombres: GA4, GTM y Sheets deben coincidir exactamente

---

### 📬 Cierre del ticket

- [ ] Dejar comentarios con enlaces:
- [ ] ID GTM
- [ ] GA4 Measurement ID
- [ ] Reporte CRS público
- [ ] Cambiar estado a “EN REVISION”
- [ ] Solicitar confirmación interna (QA si existe)

---

### 📝 Notas específicas de este caso

- [ ] ¿Hubo alguna particularidad en este caso? Documentar aquí.

---

### ¿Qué hiciste SI O SI para evitar cagadas futuras?

- [ ] Confirmé que el dominio estará en producción y no es temporal
- [ ] Verifiqué que no hay duplicado del hotel en la cuenta
- [ ] Dejé trazabilidad y documentación en el ticket y el sheet

---

### Resultado esperado

Si no puedes marcar absolutamente todo con 🔳, la cuenta NO está lista.
EOF

echo "Checklist generado: ${OUTPUT_FILE}"