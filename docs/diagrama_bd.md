# Diagrama de Base de Datos (Entidad-Relación)

A continuación se detalla la estructura relacional completa de la base de datos alojada en PostgreSQL (y compatible con SQLite para testing), incluyendo tanto las entidades de usuario y sesión como los catálogos oficiales de D&D 5e (migrados desde archivos JSON estáticos hacia la base de datos).

```mermaid
erDiagram
    USERS {
        uuid id PK
        string username
        string username_norm "Unique, Index"
        text email_encrypted "Fernet AES-128"
        string email_hash "HMAC Blind Index, Unique"
        string password_hash "Argon2id"
        int token_version
        datetime created_at
    }

    CAMPAIGNS {
        uuid id PK
        string name
        text description
        text dm_notes "Notas ocultas del DM"
        text board "Tablon de anuncios de la mesa"
        string join_code "Unique, Index"
        uuid dm_id FK "References users.id"
        datetime created_at
    }

    CAMPAIGN_MEMBERS {
        uuid campaign_id PK,FK "References campaigns.id"
        uuid user_id PK,FK "References users.id"
        string role "'dm' | 'player'"
        datetime joined_at
    }

    CHARACTERS {
        uuid id PK
        uuid owner_id FK "References users.id"
        uuid campaign_id FK "References campaigns.id (Nullable)"
        string name
        string race "Referencia slug de dnd_races"
        string subrace "Referencia slug de dnd_subraces (Nullable)"
        string class_slug "Referencia slug de dnd_classes"
        int level
        string avatar_url
        string status "'alive' | 'dead' | 'undead' | 'lost'..."
        string status_note
        jsonb sheet "Atributos, salvaciones, competencias, equipo..."
        int version "Control de concurrencia optimista"
        datetime created_at
        datetime updated_at
    }

    STATUS_EVENTS {
        uuid id PK
        uuid campaign_id FK "References campaigns.id"
        uuid character_id FK "References characters.id"
        uuid changed_by FK "References users.id"
        string old_status
        string new_status
        string note
        datetime created_at
    }

    %% Tablas de Catalogo D&D 5e (Migradas de JSON a Base de Datos)
    DND_RACES {
        string slug PK "Identificador único (p.ej. 'elf', 'human')"
        string name "Nombre en espanol (p.ej. 'Elfo')"
        string size "Tamanio ('Mediano', 'Pequeno')"
        int speed "Velocidad base en pies"
        jsonb ability_bonuses "Bonificadores raciales fijos"
        jsonb languages "Idiomas raciales"
        int extra_languages "Idiomas a eleccion"
        jsonb skills "Competencias fijas"
        int skill_choices "Numero de competencias elegibles"
        int bonus_choices "Numero de bonificadores elegibles"
        jsonb proficiencies "Competencias con armas/armaduras"
        jsonb traits "Rasgos raciales (nombre, descripcion)"
        text description "Descripcion narrativa"
    }

    DND_SUBRACES {
        string slug PK "Identificador único (p.ej. 'high_elf')"
        string race_slug FK "References dnd_races.slug"
        string name "Nombre de subraza"
        jsonb ability_bonuses "Bonificadores de subraza"
        int speed "Velocidad alternativa (Nullable)"
        int hp_per_level "PG adicionales por nivel"
        jsonb proficiencies "Competencias de subraza"
        jsonb traits "Rasgos de subraza"
    }

    DND_CLASSES {
        string slug PK "Identificador único (p.ej. 'fighter')"
        string name "Nombre en espanol (p.ej. 'Guerrero')"
        text description "Descripcion narrativa de la clase"
        int hit_die "Dado de golpe (d6, d8, d10, d12)"
        jsonb primary_abilities "Caracteristicas principales"
        jsonb saving_throws "Tiradas de salvacion competentes"
        jsonb skill_choices "Opciones y cantidad de competencias"
        jsonb proficiencies "Armas, armaduras y herramientas"
        jsonb spellcasting "Reglas de magia (Nullable)"
        jsonb recommended_abilities "Prioridad recomendada de atributos"
        jsonb starting_ac "Formula de CA inicial"
        jsonb starting_attacks "Ataques y armas iniciales"
        jsonb starting_equipment "Equipo inicial"
        string subclass_label "Nombre de arquetipo (p.ej. 'Senda primaria')"
        int subclass_level "Nivel donde se elige arquetipo"
        jsonb features "Rasgos de clase por nivel (1..20)"
    }

    DND_BACKGROUNDS {
        string slug PK "Identificador único (p.ej. 'acolyte')"
        string name "Nombre en espanol (p.ej. 'Acolito')"
        jsonb skills "Competencias en habilidades otorgadas"
        int extra_languages "Idiomas adicionales"
        jsonb proficiencies "Herramientas competentes"
        jsonb feature "Rasgo narrativo de trasfondo"
        jsonb equipment "Equipo inicial de trasfondo"
    }

    DND_SKILLS {
        string id PK "Slug canonico (p.ej. 'athletics')"
        string key "Clave espanola (p.ej. 'atletismo')"
        string name "Nombre formal (p.ej. 'Atletismo')"
        string ability "Caracteristica base ('str', 'dex', ...)"
    }

    DND_RULE_CONFIGS {
        string key PK "Clave de regla (p.ej. 'point_costs')"
        jsonb data "Matriz o diccionario de reglas mecanicas"
    }

    %% Relaciones del Sistema
    USERS ||--o{ CAMPAIGNS : "Crea (como DM)"
    USERS ||--o{ CAMPAIGN_MEMBERS : "Participa en"
    CAMPAIGNS ||--o{ CAMPAIGN_MEMBERS : "Tiene miembros"
    USERS ||--o{ CHARACTERS : "Es dueno de"
    CAMPAIGNS ||--o{ CHARACTERS : "Agrupa personajes activos"
    CHARACTERS ||--o{ STATUS_EVENTS : "Registra historial de"
    CAMPAIGNS ||--o{ STATUS_EVENTS : "Alberga eventos de"
    USERS ||--o{ STATUS_EVENTS : "Ejecuta cambio de estado"

    %% Relaciones de Catalogos con Datos y Personajes
    DND_RACES ||--o{ DND_SUBRACES : "Tiene variantes / subrazas"
    DND_RACES ||--o{ CHARACTERS : "Define raza base de"
    DND_CLASSES ||--o{ CHARACTERS : "Define clase de"
```

---

## Explicación de las Entidades

### 1. Entidades de Gestión de Partida y Usuarios

1. **`USERS` (Usuarios):**
   - Maneja la identidad con máxima seguridad criptográfica: contraseñas con **Argon2id**, correos cifrados bidireccionalmente con **Fernet (AES-128)** y búsquedas mediante índice ciego **HMAC (blind index)**.
   - Cuenta con control de revocación de sesiones mediante `token_version`.

2. **`CAMPAIGNS` (Campañas):**
   - Representa la mesa de juego dirigida por un Dungeon Master (`dm_id`).
   - Dispone de un código único de 8 caracteres (`join_code`) para incorporación de jugadores, además de notas privadas exclusivas para el DM (`dm_notes`) y un tablón público (`board`).

3. **`CAMPAIGN_MEMBERS` (Miembros de Campaña):**
   - Tabla asociativa que gestiona los participantes de cada mesa y su rol (`dm` o `player`).

4. **`CHARACTERS` (Personajes):**
   - Cada personaje pertenece a un usuario (`owner_id`) y puede estar asignado a lo sumo a una campaña activa (`campaign_id`).
   - La ficha técnica detallada (puntuaciones, bonificadores, inventario modular, conjuros) reside en la columna `sheet` como `JSONB`, protegida por `version` para evitar colisiones en escrituras concurrentes (*optimistic locking*).
   - Registra el estado narrativo (`alive`, `dead`, `undead`, etc.) gestionado por el DM con una nota explicativa opcional (`status_note`).

5. **`STATUS_EVENTS` (Eventos de Estado):**
   - Registro de auditoría y crónica que guarda cada modificación de estado que el DM aplica a un personaje de la campaña, registrando quién lo hizo, el estado previo y la fecha.

---

### 2. Entidades de Catálogo Oficial D&D 5e (Migradas de JSON a Base de Datos)

Anteriormente, los catálogos y reglas de creación estaban codificados como archivos JSON estáticos en el repositorio. Ahora están estructurados como modelos ORM relacionales gestionados en la base de datos:

1. **`DND_RACES` (Razas):**
   - Almacena las razas oficiales (Humano, Enano, Elfo, etc.) con sus características físicas (tamaño, velocidad), idiomas, competencias inherentes y bonificadores de característica.
   - Soporta razas con opciones dinámicas como los Semielfos (`bonus_choices` y `skill_choices`).

2. **`DND_SUBRACES` (Subrazas):**
   - Variantes vinculadas mediante clave foránea a `dnd_races.slug` (p. ej. *Enano de las colinas*, *Elfo de los bosques*).
   - Otorga bonificaciones adicionales de atributos, vida por nivel (`hp_per_level`), velocidad alternativa y rasgos especiales.

3. **`DND_CLASSES` (Clases):**
   - Registro de las 12 clases oficiales (Bárbaro, Bardo, Clérigo, Guerrero, Pícaro, Mago, etc.).
   - Define el dado de golpe (`hit_die`), tiradas de salvación competentes, reglas de selección de habilidades (`skill_choices`), fórmulas de armadura natural (`starting_ac`) y progresión de rasgos por nivel (`features`).

4. **`DND_BACKGROUNDS` (Trasfondos):**
   - Catálogo de trasfondos (Acólito, Criminal, Sabio, etc.) con las competencias en habilidades que confiere, idiomas adicionales, equipo inicial y rasgos narrativos.

5. **`DND_SKILLS` (Habilidades):**
   - Normalización de las 18 habilidades de D&D 5e mapeando su identificador canónico (`acrobatics`), su clave de hoja en español (`acrobacias`), su nombre formal y su atributo gobernante (`dex`).

6. **`DND_RULE_CONFIGS` (Configuraciones de Reglas Mecánicas):**
   - Parámetros del sistema: tabla de costes de compra de puntos (*point buy* 27 pts), límites de atributos (mínimo 8, máximo 15 base, tope 20), pericias iniciales y defensa sin armadura.

---

## Sincronización y Migración Automática (Seeder)

El módulo [`backend/app/db/catalog_seed.py`](file:///c:/1-%20PROYECTOS/Hoja%20para%20DnD/Plataforma_DnD/backend/app/db/catalog_seed.py) se ejecuta de forma transparente:
* Al arrancar el servidor (`lifespan` en FastAPI), se crean las tablas y se pueblan automáticamente si la base de datos está vacía.
* Las consultas de creación y consulta de catálogo (`/api/v1/rules/creation`, `/api/v1/rules/races`, `/api/v1/rules/classes`, `/api/v1/rules/backgrounds`, `/api/v1/rules/skills`) leen directamente de las tablas de la base de datos.
