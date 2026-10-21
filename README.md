# LA CRIPTA

Plataforma web integral para la creación, gestión y subida de nivel de personajes de D&D 5e, organización de campañas y panel de control de mesa para Dungeon Masters. Basada estrictamente en las reglas oficiales de la 5ª edición (2014) y el SRD 5.1.

---

## Funciones Principales

- **Creación Oficial de Personajes 5e:** Asistente paso a paso con compra de puntos (*point buy* de 27 pts), bonificadores raciales dinámicos, selección de competencias de clase/raza/trasfondo y validación matemática en servidor.
- **Subida de Nivel Guiada (Motor 5e):** Incremento de PG por valor medio oficial o tirada manual (+ CON retroactivo), selección de subclase según nivel oficial y Mejora de Puntuación de Características (ASI) en niveles correspondientes (+2 a una o +1/+1 a dos hasta máx 20).
- **Sistema de Hitos (Milestones) y Experiencia (XP):** Restricción de subida de nivel a personajes en campaña activa. El DM puede definir hitos con cálculo automático de XP necesaria y otorgamiento simultáneo al grupo, o asignar XP individualmente desde el Control de Personajes.
- **Control de Mesa para el Dungeon Master:** Vista resumida de PV, CA, Percepción Pasiva, notas secretas del DM, tablón de anuncios, estados narrativos y crónica de eventos.
- **Diseño Responsivo Móvil:** Adaptación fluida para teléfonos móviles y pantallas pequeñas (<600px), con modales interactivos y controles táctiles optimizados.
- **Exportación a PDF en Cliente:** Generación y descarga directa de la hoja de personaje sin sobrecargar el servidor backend.
- **Guía de Juego Integrada:** Catálogo educativo de temas de ayuda sobre reglas, atributos, tiradas y combate en mesa.

---

## Tecnologías

| Componente | Tecnología |
| --- | --- |
| **Interfaz (Frontend)** | Flutter Web (Dart), Provider, GoRouter y CanvasKit local |
| **API Backend** | FastAPI (Python 3.12), Pydantic v2 y SQLAlchemy 2.0 |
| **Base de Datos** | PostgreSQL 16 (con soporte SQLite en memoria para tests) |
| **Seguridad** | JWT con versión de token, Argon2id, Fernet AES-128 y HMAC Blind Index |
| **Despliegue e Infraestructura** | Docker Compose, Cloudflare Tunnel (`cloudflared`) y GitHub Actions CI/CD en Raspberry Pi |
| **Dominio de Producción** | [https://app.la-cripta.party/](https://app.la-cripta.party/) |
| **Pruebas Automatizadas** | pytest (158 pruebas) y flutter_test (96 pruebas) |

---

## Requisitos de Desarrollo

- Git.
- Docker Desktop o Docker Engine (Linux/Windows).
- Flutter SDK (versión 3.22 o superior) configurado en el PATH con soporte web.
- Python 3.12 (opcional para desarrollo local fuera de Docker).

---

## Ejecutar la Aplicación en Local

Todos los comandos se ejecutan desde la raíz del repositorio, salvo que se indique lo contrario.

### Opción 1: Entorno Completo con Docker (Interfaz + API + DB)

1. Compila la interfaz de Flutter Web empaquetando CanvasKit localmente:
   ```powershell
   cd dnd_frontend
   flutter pub get
   flutter build web --release --no-web-resources-cdn
   python ..\scripts\post_build_web.py
   cd ..
   ```

2. Inicia los servicios de Docker:
   ```powershell
   docker compose up -d --build db backend
   ```

3. Abre en tu navegador [http://localhost:8000](http://localhost:8000). La API REST y documentación interactiva están disponibles en [http://localhost:8000/api/v1/docs](http://localhost:8000/api/v1/docs).

### Opción 2: Desarrollo Frontend Reactivo con Flutter

1. Inicia la base de datos y la API en Docker:
   ```powershell
   docker compose up -d db backend
   ```

2. Ejecuta la interfaz en modo desarrollo con recarga rápida:
   ```powershell
   cd dnd_frontend
   flutter pub get
   flutter run -d chrome --dart-define=API_URL=http://localhost:8000/api/v1
   ```

---

## Configuración y Variables de Entorno

El archivo `.env` en la raíz permite configurar los parámetros de seguridad e infraestructura:

```env
POSTGRES_USER=dnd_user
POSTGRES_PASSWORD=tu_password_seguro
POSTGRES_DB=dnd_db
JWT_SECRET=tu_jwt_secret_largo
DATA_ENCRYPTION_KEY=clave_fernet_aes128_base64
EMAIL_HASH_KEY=pimienta_para_hmac_blind_index
CLOUDFLARE_TUNNEL_TOKEN=token_del_tunel_cloudflare_en_produccion
```

> [!WARNING]
> En instalaciones con usuarios existentes, cambiar `DATA_ENCRYPTION_KEY` o `EMAIL_HASH_KEY` impedirá descifrar o autenticar los correos previamente registrados.

---

## Pruebas Automatizadas

El proyecto cuenta con una cobertura integral de pruebas unitarias y de integración:

```powershell
# Ejecutar ambas suites (backend y frontend)
.\scripts\test-local.ps1

# Ejecutar únicamente pruebas del backend (158 pruebas)
cd backend
.\.venv\Scripts\python.exe -m pytest

# Ejecutar únicamente pruebas del frontend (96 pruebas)
cd dnd_frontend
flutter test --no-pub
```

### Comportamientos Verificados

| Área | Alcance de Pruebas |
| --- | --- |
| **Seguridad y Cripto** | Validación de contraseñas, cifrado Fernet de correos, índices ciegos HMAC, tokens JWT y revocación de sesiones |
| **Catálogos D&D 5e** | Seeder de razas, clases, trasfondos, niveles y tablas relacionales |
| **Creación 5e** | Compra de puntos (27 pts), bonificadores raciales fijos y elegibles, competencias de clase y prevención de duplicidad |
| **Subida de Nivel** | Fórmulas de PG (media o dado + CON), selección de subclase, progresión ASI y desbloqueo de rasgos |
| **Campañas e Hitos** | Restricción de campaña activa única, creación y resolución de hitos, otorgamiento de XP y control de concurrencia optimista |
| **Interfaz y Responsividad** | Navegación, providers, formularios reactivos, diálogo de nivel móvil y preservación del título LA CRIPTA |
| **Servicio Web y SPA** | Enrutamiento SPA con fallback index.html, cabeceras anti-caché y pipeline de cache-busting |

---

## Estructura del Repositorio

```text
backend/
  app/
    api/v1/            Routers de autenticación, personajes, campañas y reglas
    core/              Configuraciones y utilidades criptográficas
    db/                Modelos SQLAlchemy, sesiones y seeder de catálogos
    rules/             Motor matemático y validaciones de D&D 5e
  tests/               158 pruebas automatizadas de backend
dnd_frontend/
  lib/
    core/              Enrutador GoRouter, tema visual y catálogos cliente
    models/            Modelos de datos y adaptadores JSON
    providers/         Gestores de estado ChangeNotifier (Auth, Character, Campaign)
    screens/           Pantallas de login, creación, hoja, campañas y tutorial
    widgets/           Componentes modulares (LevelUpDialog, MainDrawer, PasswordRequirements)
  web/                 PWA manifest, index.html con interceptor y recursos web
  test/                96 pruebas automatizadas de Flutter
scripts/
  post_build_web.py    Script de cache-busting automático para Cloudflare
  test-local.ps1       Suite de pruebas local integral
docs/
  arquitectura.md          Arquitectura técnica y componentes
  diagrama_arquitectura.md Diagrama Mermaid de red y servicios
  diagrama_bd.md           Diagrama Entidad-Relación y diccionario de datos
  plan_de_desarrollo.md    Estado de fases y próximos pasos
  registro_de_cambios.md   Bitácora cronológica detallada de cambios
.github/workflows/
  deploy.yml           Pipeline CI/CD en Raspberry Pi con auto cache-busting
docker-compose.yml     Definición de servicios (db, backend, tunnel)
```
