# Arquitectura del Sistema — LA CRIPTA

**LA CRIPTA** está estructurada bajo una arquitectura cliente-servidor desacoplada pero servida en producción como un monolito unificado y seguro dentro de un entorno de contenedores Docker.

---

## 1. Frontend (Capa Cliente)
Desarrollado en **Flutter Web**.
*   **Lenguaje y Framework:** Dart y Flutter Web (compilado en modo release con soporte local para CanvasKit).
*   **Gestión de Estado:** Patrón `Provider` / `ChangeNotifier` para modularizar reactivamente:
    *   `AuthProvider`: Sesión de usuario, almacenamiento seguro de JWT y verificación de permisos.
    *   `CharacterProvider`: Selección, creación, edición concurrente optimista y subida de nivel de personajes.
    *   `CampaignProvider`: Administración de campañas, notas del DM, hitos y control de experiencia.
*   **Enrutamiento Declarativo:** `go_router` con guardas de autenticación y redirecciones transparentes.
*   **Diseño Responsivo:** Arquitectura visual basada en `LayoutBuilder` y breakpoints que adapta la interfaz de forma fluida a teléfonos móviles (<600px), tabletas y monitores de escritorio.
*   **Generación de Documentos:** Creación de PDFs en el cliente mediante el paquete `pdf` y descarga nativa a través de `universal_html`, sin sobrecargar el servidor backend.
*   **Optimización de Carga:** 
    *   Empaquetado de **CanvasKit Local** (`--no-web-resources-cdn`) para operar sin dependencia de la CDN de Google.
    *   Pantalla de carga inicial ligera e inmediata en CSS nativo dentro de `index.html`.
    *   Bloqueo reactivo del título de la pestaña mediante `onGenerateTitle` y un `MutationObserver` en el DOM que mantiene el título como **LA CRIPTA** ante cualquier cambio de estado.

---

## 2. Backend (Capa de Aplicación y API)
Desarrollado en **Python 3.12**.
*   **Framework:** FastAPI con validación estricta a través de esquemas **Pydantic v2**.
*   **ORM y Base de Datos:** SQLAlchemy 2.0 con motor PostgreSQL y sesiones gestionadas por generador de contexto de dependencias.
*   **Seguridad y Criptografía:**
    *   **Contraseñas:** Hashing mediante **Argon2id** (resistente a ataques GPU/ASIC).
    *   **Cifrado de Datos Personales:** Correos electrónicos cifrados en reposo mediante **Fernet (AES-128-CBC)**.
    *   **Índice Ciego (Blind Index):** Búsqueda y unicidad de emails mediante **HMAC-SHA256** con sal y pimienta de servidor (`EMAIL_HASH_KEY`).
    *   **Tokens:** **JWT** con firma criptográfica y control de versión (`token_version`) en la base de datos para invalidación instantánea de sesiones ante cambios de contraseña o cierres globales.
*   **Servicio de Archivos Estáticos y Enrutamiento SPA:**
    *   La clase `NoCacheStaticFiles` intercepta las peticiones de navegación SPA en rutas profundas (`/login`, `/my-characters`, `/campaign/*`) devolviendo `index.html` con código 200, mientras que preserva el código 404 para recursos estáticos inexistentes (`.wasm`, `.js`).
    *   Inyección de cabeceras anti-caché estrictas (`Cache-Control: no-cache, no-store, must-revalidate, max-age=0`) para código fuente cliente (`.js`, `.wasm`, `.json`, `.html`).
*   **Sembrado de Catálogos:** Inicialización automática e idempotente en el evento `lifespan` de FastAPI que garantiza la presencia y actualización de tablas oficiales de D&D 5e (razas, clases, trasfondos, habilidades).

---

## 3. Infraestructura y Despliegue en Producción
Todo el sistema se despliega en un servidor **Raspberry Pi** mediante **Docker Compose** y un túnel seguro de **Cloudflare**.

*   **Servicios Contenerizados:**
    1.  `db`: Base de datos **PostgreSQL 16 Alpine** con persistencia en el volumen de Docker `pgdata`.
    2.  `backend`: Aplicación **FastAPI** ejecutándose en el puerto interno `8000`, la cual monta los archivos compilados de Flutter Web en `/srv/static` y los archivos multimedia en el volumen `uploaded_images`.
    3.  `tunnel`: Contenedor oficial **`cloudflare/cloudflared`** conectado a Cloudflare Edge mediante token privado (`CLOUDFLARE_TUNNEL_TOKEN`).
*   **Acceso y Certificados:**
    *   El túnel expone la aplicación bajo el dominio oficial seguro **`https://app.la-cripta.party/`**.
    *   Cloudflare gestiona automáticamente los certificados SSL/TLS y la terminación HTTPS sin necesidad de abrir puertos en el router ni configurar proxies inversos manuales (Nginx).
*   **Despliegue Continuo (CI/CD):**
    *   Flujo automatizado en **GitHub Actions** (`.github/workflows/deploy.yml`) ejecutado por un runner auto-hospedado en la Raspberry Pi (`runs-on: [self-hosted, raspi]`).
    *   Se activa automáticamente con cada `push` a la rama `release`.
*   **Pipeline de Cache-Busting (`scripts/post_build_web.py`):**
    *   Tras la compilación de Flutter Web, el script genera un UNIX timestamp único y versiona las referencias de `main.dart.js` y `flutter_bootstrap.js`.
    *   Esto obliga a Cloudflare a responder con `cf-cache-status: BYPASS` en cada despliegue, asegurando que los usuarios finales siempre reciban la última versión sin colisiones de caché.
