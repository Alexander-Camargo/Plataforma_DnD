# LA CRIPTA

Aplicación web para crear y consultar personajes de D&D 5e, organizar campañas y gestionar una mesa como Dungeon Master. La guía de juego utiliza las reglas de 2014 y el SRD 5.1.

## Funciones

- Crear personajes y editar sus hojas.
- Crear campañas y unirse mediante un código de invitación.
- Consultar al grupo y registrar estados narrativos desde la vista del DM.
- Llevar iniciativa y PG de combate mientras permanece abierta la pantalla.
- Guardar notas privadas de la campaña.
- Consultar una guía para principiantes y ayudas junto a los campos.
- Exportar la hoja de personaje a PDF.

La iniciativa y los PG del rastreador no se guardan al salir ni modifican automáticamente la hoja. La subida de nivel guiada y otras elecciones de reglas todavía están en desarrollo.

## Tecnologías

| Componente | Tecnología |
| --- | --- |
| Interfaz | Flutter Web, Dart, Provider y GoRouter |
| API | FastAPI, Pydantic y SQLAlchemy con sesiones síncronas |
| Base de datos | PostgreSQL 16 |
| Entorno local | Docker Compose |
| Pruebas | pytest, pytest-cov y flutter_test |

## Requisitos

- Git.
- Docker Desktop abierto, con contenedores Linux.
- Flutter en PATH, con soporte web. En el entorno Windows del proyecto se utiliza Edge.
- Acceso a internet para descargar dependencias e imágenes en la primera ejecución.

Python y PostgreSQL se ejecutan en contenedores; no es necesario instalarlos en el host para los comandos de esta guía.

## Ejecutar la aplicación local

Los comandos siguientes se ejecutan desde la raíz del repositorio, salvo que se indique otra carpeta.

### Interfaz y API en un solo puerto

Compila primero la interfaz:

```powershell
cd dnd_frontend
flutter pub get
flutter build web
cd ..
```

Después inicia los servicios:

```powershell
docker compose up -d --build
```

Abre [http://localhost:8000](http://localhost:8000). La API está disponible bajo `/api/v1`.

Docker sirve la interfaz desde `dnd_frontend/build/web`. Si esa carpeta no existe, debes compilar Flutter antes de abrir la web.

### Desarrollo con Flutter

Inicia la API y PostgreSQL:

```powershell
docker compose up -d db backend
```

Ejecuta la interfaz con el backend local:

```powershell
cd dnd_frontend
flutter pub get
flutter run -d edge --dart-define=API_URL=http://localhost:8000/api/v1
```

Flutter abre una dirección local con su propio puerto. El backend sigue en el puerto 8000. El parámetro `API_URL` establece explícitamente esa conexión.

- Cambios de interfaz: utiliza la recarga rápida de Flutter.
- Rutas nuevas o cambios de inicialización: utiliza un **hot restart**, con `R` en la terminal de Flutter.
- Cambios de `--dart-define`: detén y vuelve a ejecutar el comando completo.
- Cambios de Python: reinicia el backend.
- Para actualizar la interfaz servida en el puerto 8000: vuelve a ejecutar `flutter build web`.

### Comprobar y administrar los servicios

```powershell
docker compose ps
docker compose logs --tail 50 backend
docker compose restart backend
```

- Estado de la API: [http://localhost:8000/health](http://localhost:8000/health).
- Documentación de endpoints: [http://localhost:8000/api/v1/docs](http://localhost:8000/api/v1/docs).

Para detener los servicios conservando la base de datos:

```powershell
docker compose stop
```

Para iniciarlos de nuevo:

```powershell
docker compose start
```

La base de datos utiliza el volumen `pgdata`. Eliminar ese volumen elimina los datos locales.

## Configuración

Docker Compose configura la conexión de PostgreSQL. Permite definir variables como `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `JWT_SECRET`, `DATA_ENCRYPTION_KEY` y `EMAIL_HASH_KEY` desde un archivo `.env` en la raíz.

Los valores predeterminados del repositorio son para desarrollo local. `DATA_ENCRYPTION_KEY` debe ser una clave Fernet válida. En una instalación con usuarios existentes, cambiar las claves de cifrado o del índice de email afecta a la lectura y búsqueda de esos datos.

## Pruebas automatizadas

Ejecuta ambas suites desde la raíz:

```powershell
.\scripts\test-local.ps1
```

Si Flutter no está en PATH, indica la ruta de su ejecutable:

```powershell
.\scripts\test-local.ps1 -FlutterExecutable 'C:\ruta\flutter\bin\flutter.bat'
```

Para ejecutar una suite por separado:

```powershell
.\scripts\test-local.ps1 -BackendOnly
.\scripts\test-local.ps1 -FrontendOnly
```

El script se detiene si falla una suite o Flutter Analyze encuentra problemas. Las dependencias de Flutter deben estar disponibles; ejecuta `flutter pub get` en `dnd_frontend/` antes de la primera ejecución.

### Aislamiento

El backend se prueba en una imagen independiente definida en `backend/Dockerfile.test`. El contenedor de pruebas se ejecuta sin red. Los fixtures utilizan SQLite en memoria, activan claves foráneas y crean una sesión nueva por petición; no acceden al PostgreSQL de la aplicación ni a sus personajes.

El frontend utiliza preferencias simuladas y respuestas HTTP de `MockClient`. Sus solicitudes de prueba no llegan al servidor real.

### Qué comprueban

| Área | Comportamientos |
| --- | --- |
| Autenticación | Contraseñas, cifrado e índices de email, tokens, registro, login y permisos |
| Campañas | Creación, invitaciones, membresía y privacidad de notas del DM |
| Personajes | Lectura, edición, versiones optimistas, niveles, puntuaciones y rollback |
| Historia de campaña | Cambios de estado y eventos, retirada, historial y eliminación con cascada |
| Reglas existentes | Modificadores, competencia, percepción pasiva, compra de puntos y reglas de progresión implementadas |
| Interfaz | Providers, rutas protegidas, tutorial, asistente, notas, combate, edición y confirmación de eliminación |
| Servicio web | Health y encabezados de caché de los archivos de arranque |

Estas suites no sustituyen una prueba integral de navegador, API y PostgreSQL juntos. La descarga de PDF, el importador antiguo y todos los casos visuales de tamaños de pantalla no tienen cobertura completa. Probar una fórmula implementada no significa que una función todavía en desarrollo, como la subida de nivel guiada, esté terminada.

### Informes de cobertura

El script genera:

- Backend: `backend/coverage/html/index.html` y `backend/coverage/coverage.json`.
- Frontend: `dnd_frontend/coverage/lcov.info`.

Los informes quedan ignorados por Git. Una cobertura alta indica qué código se ejecutó durante las pruebas; no garantiza ausencia de errores.

## Estructura

```text
backend/
  app/                 API, modelos, seguridad y reglas
  tests/               Pruebas unitarias y de API
  Dockerfile.test      Entorno aislado de pruebas
dnd_frontend/
  lib/                 Pantallas, providers, modelos y widgets
  test/                Pruebas unitarias y de interfaz
scripts/
  test-local.ps1       Ejecución de suites e informes
docs/                  Referencias del proyecto
docker-compose.yml     Servicios de la aplicación local
```

## Archivos locales y Git

El `.gitignore` excluye los Markdown nuevos de referencia local, con una excepción para este `README.md` de la raíz. Los Markdown que ya estaban versionados siguen bajo seguimiento.

`requirements.txt` y `requirements-dev.txt` sí se versionan: son necesarios para instalar las dependencias. El archivo `.env`, los informes de pruebas y las cachés se mantienen locales.


### Creación de personajes: D&D 5e (2014)

El catálogo del backend (`/api/v1/rules/creation`, requiere sesión) adapta los slugs de las tablas JSON a las claves españolas de las hojas existentes. La creación envía elecciones en `creation`: las seis puntuaciones base, bonificadores raciales elegibles, habilidades de clase/raza, trasfondo, sustituciones de competencias repetidas y pericias. El servidor valida la compra de 27 puntos (base 8–15) y calcula bonificadores de raza/subraza, habilidades, salvaciones, PG, velocidad y CA sin armadura. Las clases no asignan puntuaciones fijas. Las opciones de trasfondo indican su procedencia en el catálogo.

El asistente crea nivel 1. El equipo y demás rasgos se completan con el DM; registrar equipo aún no calcula automáticamente la CA de armaduras. No se reasignan puntuaciones ni se inventan elecciones de competencias para personajes antiguos: sus datos guardados se conservan. La hoja y el PDF calculan los totales con las competencias y pericias registradas. Los tests usan SQLite efímera y una instantánea del catálogo para Flutter.