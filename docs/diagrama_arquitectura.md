# Diagrama de Arquitectura — LA CRIPTA

A continuación se ilustra la arquitectura de alto nivel de **LA CRIPTA**, mostrando el flujo de interacción de los usuarios a través del túnel seguro de Cloudflare, la capa de contenedores Docker y la comunicación interna entre servicios.

```mermaid
flowchart TD
    %% Usuarios y Clientes
    subgraph Clients [Usuarios de LA CRIPTA]
        User((Jugador\nMóvil / Web))
        DM((Dungeon Master\nMóvil / Web))
    end

    %% Capa de Red y Seguridad Cloudflare
    subgraph CloudflareNetwork [Cloudflare Edge Network]
        Domain[Dominio HTTPS\napp.la-cripta.party]
        EdgeSSL[Terminación SSL/TLS\ny Protección DDoS]
    end

    %% Servidor de Producción (Raspberry Pi)
    subgraph HostServer [Servidor de Producción - Raspberry Pi]
        subgraph DockerEnv [Docker Compose]
            
            %% Contenedor Túnel
            subgraph TunnelContainer [Contenedor: dnd_tunnel]
                Cloudflared[cloudflared client\nToken Tunnel]
            end

            %% Contenedor Backend
            subgraph BackendContainer [Contenedor: dnd_backend]
                FastAPIApp[FastAPI 3.12 Engine]
                StaticSPA[NoCacheStaticFiles\nFallback SPA + Cache-Control]
                AuthModule[Seguridad & Cripto\nJWT + Argon2id + Fernet AES]
                SeedModule[Catalog Seeder\nLifespan D&D 5e]
                APIRouter[Router REST /api/v1\nCharacters, Campaigns, Milestones]
                ORM[SQLAlchemy ORM 2.0]
            end

            %% Contenedor Base de Datos
            subgraph DBContainer [Contenedor: dnd_postgres]
                Postgres[(PostgreSQL 16\nVolumen pgdata)]
            end

            %% Volúmenes Compartidos
            StaticVolume[(Volumen /srv/static\nFlutter Web Assets)]
        end
    end

    %% Flujos de Red
    User -->|HTTPS| Domain
    DM -->|HTTPS| Domain
    Domain --> EdgeSSL
    EdgeSSL <==>|Túnel Seguro Bidireccional| Cloudflared
    Cloudflared <-->|HTTP localhost:8000| FastAPIApp

    %% Enrutamiento Interno Backend
    FastAPIApp --> StaticSPA
    FastAPIApp --> APIRouter
    StaticVolume -.->|Montado en| StaticSPA

    %% Lógica de Negocio y Base de Datos
    APIRouter --> AuthModule
    APIRouter --> ORM
    SeedModule --> ORM
    ORM <-->|TCP/IP: 5432| Postgres
```

---

## Explicación Detallada de los Flujos

1. **Acceso Seguro sin Puertos Abiertos:**
   - Tanto los jugadores como el Dungeon Master ingresan a través del dominio seguro `https://app.la-cripta.party/`.
   - La red perimetral de Cloudflare gestiona los certificados SSL/TLS y redirige las peticiones al contenedor `dnd_tunnel` (`cloudflared`) que mantiene una conexión saliente segura desde la Raspberry Pi, evitando tener que abrir puertos en el router o configurar DNS dinámico.

2. **Carga de la Aplicación Web (SPA):**
   - El contenedor `dnd_backend` recibe el tráfico en el puerto interno `8000`.
   - Si la petición es hacia la raíz (`/`) o hacia una ruta profunda de navegación de Flutter (`/login`, `/my-characters`, `/campaign/123`), el componente `NoCacheStaticFiles` entrega `index.html` con cabeceras anti-caché estrictas.
   - Flutter Web se inicializa utilizando **CanvasKit Local**, descargando los recursos compilados desde el volumen `/srv/static`.
   - Gracias al script `scripts/post_build_web.py`, los archivos `flutter_bootstrap.js` y `main.dart.js` cuentan con sellos de versión únicos, logrando que Cloudflare eluda la caché perimetral (`cf-cache-status: BYPASS`) y garantice código fresco.

3. **Operaciones REST y Lógica de Juego:**
   - La interfaz de Flutter invoca los endpoints de la API (`/api/v1/...`) mediante `ApiClient`.
   - Las rutas protegidas verifican el token JWT y su `token_version` en la base de datos.
   - Las operaciones de creación, subida de nivel, hitos de campaña y persistencia de experiencia (XP) se validan mediante esquemas Pydantic y se ejecutan atómicamente a través de SQLAlchemy ORM contra la base de datos PostgreSQL.
