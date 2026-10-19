# Plan de Desarrollo

El desarrollo de la **Plataforma DnD** se divide en fases para asegurar entregas funcionales y estables.

## ✅ Fase 1: Fundaciones y Estructura Base (Completada)
*   [x] Configuración de Docker y contenedores (PostgreSQL + FastAPI).
*   [x] Implementación de JWT y seguridad básica en backend.
*   [x] Creación de modelo de datos para Usuarios, Campañas y Personajes.
*   [x] Configuración de Flutter Web.
*   [x] Conexión entre Frontend y Backend.
*   [x] Refactorización de estética y tema de la aplicación.
*   [x] Exportación e inicialización del entorno unificado bajo el puerto 8000 (UI + API).

## ✅ Fase 2: Gestión de Personajes Básica (Completada)
*   [x] Creación de hoja de personaje interactiva.
*   [x] Posibilidad de ver la lista de personajes creados y abrirlos.
*   [x] Edición en vivo de la hoja de personaje (Stats, Vida, Detalles).
*   [x] Integración de generación de archivos PDF para la hoja de personaje (compatible con la web nativa).

## ⏳ Fase 3: Mecánicas D&D 5e Avanzadas (En Progreso)
*   [x] **Migración de Catálogos a BD:** Modelado relacional y persistencia de razas, subrazas, clases, trasfondos, habilidades y reglas mecánicas en la base de datos (eliminando dependencia de JSON estáticos).
*   [x] **Flujo de Creación Oficial 5e:** Compra de puntos (27 pts), bonificadores raciales dinámicos y validación de competencias en backend y frontend.
*   [ ] **Subida de Nivel:** Interfaz para notificar cuando hay un nivel disponible y aplicar cambios.
*   [ ] **Mejora de Puntuación de Características (ASI):** Lógica para aumentar atributos o escoger dotes cada ciertos niveles.
*   [ ] Selección y asignación de Conjuros (Spellcasting) dependiendo de la clase.
*   [ ] Manejo de Inventario Avanzado (Cálculo de peso y monedas).
*   [ ] Equipamiento dinámico (Armas, armaduras y bonificadores automáticos a la CA o ataques).

## 📋 Fase 4: Campañas y Dungeon Master
*   [ ] Lógica en tiempo real o *polling* para Campañas activas.
*   [ ] Un personaje solo puede pertenecer a una campaña simultáneamente (Terminar campaña actual para unirse a otra).
*   [ ] Dashboard del DM: El creador de la campaña debe poder ver las fichas resumidas de sus jugadores en vivo.
*   [ ] Chat o log de tiradas de dados compartidas en la campaña.

## 🚀 Fase 5: Despliegue en Producción
*   [ ] Compilación final optimizada.
*   [ ] Adquisición de servidor VPS o Cloud (AWS/GCP/DigitalOcean).
*   [ ] Configuración de dominio HTTPS, certificado SSL y Nginx como proxy inverso.
*   [ ] Migración de la base de datos de SQLite/local-Postgres a PostgreSQL persistente en producción.
