# Plan de Desarrollo — LA CRIPTA

El desarrollo de **LA CRIPTA** se estructura en fases secuenciales para garantizar estabilidad, modularidad y apego riguroso a las reglas oficiales del SRD 5.1 (D&D 5e 2014).

---

## ✅ Fase 1: Fundaciones y Estructura Base (Completada)
*   [x] Configuración de Docker Compose y contenedores (`dnd_postgres`, `dnd_backend`, `dnd_tunnel`).
*   [x] Autenticación robusta con JWT, hashing Argon2id, cifrado Fernet AES-128 para correos e índice ciego HMAC.
*   [x] Creación de modelo relacional base (Usuarios, Campañas, Miembros, Personajes y Eventos de Estado).
*   [x] Configuración de Flutter Web y conexión cliente-servidor mediante `ApiClient`.
*   [x] Estandarización de tema estético fantástico (`app_theme.dart`).
*   [x] Monolito en un solo puerto (`8000`) sirviendo API REST en `/api/v1` y Web en `/`.

## ✅ Fase 2: Gestión de Personajes Básica (Completada)
*   [x] Hoja de personaje interactiva completa (Estadísticas, Atributos, Salvaciones, Habilidades, Trasfondo y Notas).
*   [x] Visualización y gestión de la lista de personajes propios (`MyCharactersScreen`).
*   [x] Edición en vivo de la hoja de personaje con control de concurrencia optimista (`version`).
*   [x] Generación y descarga nativa de archivos PDF para la hoja de personaje en el cliente.

## ⏳ Fase 3: Mecánicas D&D 5e Oficiales (En Progreso)
*   [x] **Migración de Catálogos a BD:** Modelado relacional y persistencia de razas, subrazas, clases, niveles, trasfondos, habilidades y reglas mecánicas en PostgreSQL con seeder automático.
*   [x] **Flujo Oficial de Creación 5e:** Compra de puntos (27 pts), bonificadores raciales dinámicos, selección de competencias y validación cruzada.
*   [x] **Motor de Subida de Nivel 5e:** Asistente interactivo para aumento de PG (media fija oficial o tirada manual + CON retroactivo), selección de subclase según nivel oficial y desbloqueo automático de rasgos.
*   [x] **Mejora de Puntuación de Características (ASI):** Aumento de atributos (+2 a una o +1/+1 a dos hasta máx 20) en niveles correspondientes (4, 8, 12, 16, 19; Guerrero +6/+14; Pícaro +10).
*   [x] **Progresión por Hitos (Milestones) y Experiencia (XP):** Restricción de subida de nivel a personajes en campaña activa que alcancen la XP requerida según la tabla oficial 5e.
*   [x] **Diseño Responsivo Móvil:** Adaptación integral de la hoja de personaje y diálogo de subida de nivel para teléfonos móviles y pantallas pequeñas (<600px).
*   [ ] Selección y asignación de Conjuros (Spellcasting) según espacios y nivel de clase.
*   [ ] Manejo de Inventario Avanzado (Cálculo de peso, capacidad de carga y monedas).
*   [ ] Equipamiento dinámico (Armas, armaduras y cálculo automático de CA y bonificadores de ataque/daño).

## ⏳ Fase 4: Campañas y Gestión de Dungeon Master (En Progreso)
*   [x] Restricción de pertenencia única: un personaje solo puede pertenecer a una campaña activa simultáneamente.
*   [x] Generación y uso de códigos de invitación únicos por campaña.
*   [x] Dashboard del DM (`DmDashboardScreen`): Control de notas privadas de preparación, tablón de anuncios y estados narrativos del grupo.
*   [x] Pestaña de **Hitos de Campaña:** Creación de objetivos narrativos con cálculo automático de XP necesaria y otorgamiento masivo a la mesa al completarlos.
*   [x] Pestaña de **Control de Personajes:** Monitoreo en vivo de estadísticas vitales (PV, CA, Percepción Pasiva) y contador/adición de experiencia por aventurero.
*   [ ] Rastreador de combate y orden de iniciativa persistente.
*   [ ] Canal de tiradas de dados compartidas y log de eventos de mesa en tiempo real.

## ✅ Fase 5: Despliegue en Producción e Infraestructura (Completada)
*   [x] Contenedorización multi-servicio con Docker Compose (PostgreSQL 16, FastAPI y Cloudflare Tunnel).
*   [x] Despliegue continuo (CI/CD) automatizado mediante GitHub Actions en servidor Raspberry Pi (`self-hosted, raspi`) sincronizado con la rama `release`.
*   [x] Conectividad segura HTTPS bajo el dominio oficial **`https://app.la-cripta.party/`** a través de Cloudflare Tunnel sin exponer puertos en el router.
*   [x] Compilación de Flutter Web con CanvasKit local (`--no-web-resources-cdn`) para autonomía total de CDNs externas.
*   [x] Enrutamiento SPA en FastAPI con fallback hacia `index.html` para navegación directa en rutas profundas.
*   [x] Pipeline automatizado de cache-busting post-compilación (`scripts/post_build_web.py`) con invalidación perimetral de Cloudflare (`cf-cache-status: BYPASS`).
*   [x] Rebranding integral de la plataforma a **LA CRIPTA** con bloqueo reactivo de título de pestaña.
