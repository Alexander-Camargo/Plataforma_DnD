# Registro de Cambios y Progreso — LA CRIPTA

Este archivo sirve como bitácora y registro cronológico de todas las funcionalidades, optimizaciones y cambios arquitectónicos implementados en **LA CRIPTA**.

---

## Bitácora de Versiones e Hitos

### 1. Reestructuración del Proyecto y Monolito en Un Solo Puerto (Fase 1)
- Migración de la arquitectura inicial hacia **Flutter Web** para la interfaz de usuario y **FastAPI (Python)** para el backend con persistencia en **PostgreSQL 16**.
- Implementación de **Docker Compose** para orquestar contenedores (`dnd_postgres`, `dnd_backend`, `dnd_tunnel`).
- Configuración de FastAPI para servir los archivos estáticos compilados de Flutter Web desde `/srv/static`, permitiendo servir tanto la API REST (`/api/v1/...`) como la aplicación web (`/`) bajo un único puerto (`8000`).
- Creación de `app_theme.dart` para unificar paleta de colores (oro antiguo `#dfba73`, fondo oscuro `#121212`, paneles pergamino) y eliminar estilos fijos dispersos.

### 2. Seguridad y Cifrado de Datos de Usuario
- Autenticación mediante **JWT** (JSON Web Tokens) con verificación de `token_version` para revocación instantánea de sesiones.
- Hashing de contraseñas de alta seguridad con **Argon2id**.
- Cifrado en reposo para correos electrónicos utilizando **Fernet (AES-128-CBC)** con clave simétrica configurable.
- Índice ciego (**HMAC Blind Index**) para permitir búsquedas exactas de correo electrónico sin revelar información en texto plano ni vulnerar el cifrado.
- Componente interactivo `PasswordRequirementsView` con validación reactiva en tiempo real de longitud, mayúsculas, minúsculas, números y caracteres especiales.

### 3. Migración de Catálogos D&D 5e a Base de Datos Relacional
- Sustitución de archivos JSON estáticos por un esquema relacional normalizado en PostgreSQL:
  - `dnd_races`: Razas oficiales SRD 5.1 con bonificadores fijos, idiomas, competencias y rasgos.
  - `dnd_subraces`: Subrazas con bonificadores propios, competencias y PG adicionales (ej. Enano de la colina).
  - `dnd_classes`: Clases oficiales con dados de golpe, características principales, salvaciones e indumentaria.
  - `dnd_class_levels`: Progresión nivel a nivel (bonificador de competencia, rasgos desbloqueados, espacios de conjuro).
  - `dnd_backgrounds`: Trasfondos con competencias en habilidades, herramientas, idiomas y rasgos narrativos.
  - `dnd_skills` y `dnd_ability_score_info`: Catálogo de habilidades y descriptores educativos de atributos.
- Sembrado automático e idempotente (`catalog_seed.py`) ejecutado durante el ciclo de vida `lifespan` de FastAPI.

### 4. Flujo Oficial de Creación de Aventureros (D&D 5e 2014)
- Asistente de creación guiada paso a paso (`CreateCharacterScreen`):
  - Sistema de **Compra de Puntos (Point Buy)** oficial de 27 puntos para puntuaciones base de 8 a 15.
  - Asignación dinámica de bonificadores raciales fijos y de libre elección (ej. Semielfo +1/+1).
  - Selección de competencias de clase, raza y trasfondo con validación contra duplicidad.
  - Validación matemática estricta y auditoría tanto en el cliente como en el backend.

### 5. Mecánica de Subida de Nivel y Progresión 5e (Fase 3)
- **Motor de Reglas 5e para Aumento de Nivel:**
  - Asistente interactivo guiado (`LevelUpDialog`):
    - Incremento de Puntos de Golpe: opción de tomar el valor medio fijo oficial o registrar tirada manual del dado de golpe, aplicando retroactivamente el modificador de Constitución.
    - Selección de **Subclase** al alcanzar el nivel requerido según la clase (nivel 1 para Clérigo/Brujo/Hechicero, nivel 2 para Mago/Druida, nivel 3 para Guerrero/Pícaro/Paladín/Bárbaro/Bardo/Monje/Explorador).
    - Desbloqueo y acumulación automática de rasgos de clase y raza.
  - **Mejora de Características (ASI - Ability Score Improvement):**
    - Desbloqueo en niveles oficiales (4, 8, 12, 16, 19 para la mayoría; bonificaciones adicionales para Guerrero en niveles 6 y 14, y Pícaro en nivel 10).
    - Selección de +2 a una característica o +1 a dos distintas, con tope máximo oficial de 20.

### 6. Sistema de Campañas, Hitos (Milestones) y Experiencia (XP)
- **Regla de Progresión en Campaña:** Los personajes solo pueden subir de nivel si pertenecen a una campaña activa y cuentan con la experiencia requerida según la tabla oficial de D&D 5e.
- **Hitos de Campaña (`campaign_milestones`):**
  - El Dungeon Master puede crear hitos narrativos con título, descripción y nivel objetivo.
  - El sistema calcula automáticamente la XP necesaria para alcanzar dicho nivel (ej. 300 XP para Nivel 2, 900 XP para Nivel 3).
  - Al marcar un hito como completado, se otorga la experiencia requerida a todos los personajes de la campaña en una sola operación atómica.
- **Pestaña "Control de Personajes" en la Campaña:**
  - Monitor para el DM con resumen de PV, CA, Percepción Pasiva, estado narrativo y contador de experiencia de cada aventurero.
  - Funcionalidad para que el DM conceda o modifique experiencia acumulada directamente.
  - Persistencia de la experiencia (`experience INTEGER`) en la ficha del personaje entre campañas.

### 7. Optimización Responsiva para Teléfonos Móviles
- Adaptación total de la interfaz para dispositivos móviles (ancho de pantalla < 600px).
- Reemplazo de tablas rígidas y layouts horizontales por tarjetas apiladas dinámicas (`Wrap`, `SingleChildScrollView`, `Column`).
- Diálogo de subida de nivel adaptativo con modales `isScrollControlled` y botones táctiles optimizados.
- Prevención de desbordamientos visuales (`RenderFlex overflowed`) en todas las pantallas principales.

### 8. Despliegue en Producción e Infraestructura Cloudflare
- **Despliegue Continuo (CI/CD):** Pipeline en GitHub Actions configurado para servidor Raspberry Pi local (`self-hosted, raspi`) con actualización automática al pushear a la rama `release`.
- **Cloudflare Tunnel (`dnd_tunnel`):** Exposición segura a internet mediante contenedor oficial `cloudflare/cloudflared` con token bajo el dominio HTTPS **`app.la-cripta.party`**.
- **Canvaskit Local:** Compilación de Flutter Web con la bandera `--no-web-resources-cdn` para empaquetar `canvaskit.wasm` localmente, eliminando fallas por bloqueo de CDNs externas o conexiones lentas.
- **Enrutamiento SPA en FastAPI:** Fallback transparente hacia `index.html` en peticiones GET de navegación SPA (rutas sin extensión como `/login`, `/my-characters`, `/campaign/*`), evitando errores 404 al refrescar o acceder por URL directa.
- **Pipeline Automatizado de Cache-Busting (`scripts/post_build_web.py`):**
  - Inyección automática de sellos de versión únicos (UNIX timestamp) en `index.html` y `flutter_bootstrap.js` tras cada compilación.
  - Solicitud de `main.dart.js?v=TIMESTAMP` que fuerza la invalidación de la caché perimetral de Cloudflare (`cf-cache-status: BYPASS`) y asegura que todos los navegadores carguen la versión más reciente al instante.
  - Purgado automático de Service Workers y `CacheStorage` residuales.

### 9. Rebranding Oficial: LA CRIPTA
- Actualización total de la identidad visual de la plataforma a **LA CRIPTA**.
- Títulos de documentos, manifiesto PWA (`manifest.json`), pantalla de bienvenida, encabezados de login y documentación unificados.
- Guardián reactivo de título de pestaña con `onGenerateTitle` en Flutter y `MutationObserver` en el DOM para mantener el nombre **LA CRIPTA** en todo momento.

---

## Resumen de Cobertura de Pruebas
- **Backend:** 158 pruebas automatizadas con `pytest` (cobertura en autenticación, catálogos, creación 5e, reglas mecánicas, seguridad y enrutamiento estático).
- **Frontend:** 96 pruebas de widgets y unitarias con `flutter test` (cobertura en providers, router, pantallas, formularios de creación, subida de nivel y responsividad móvil).
