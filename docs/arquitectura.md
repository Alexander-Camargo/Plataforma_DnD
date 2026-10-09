# Arquitectura de Plataforma DnD

La plataforma está diseñada con una arquitectura moderna de cliente-servidor, separando claramente la interfaz de usuario (Frontend) de la lógica de negocio y persistencia de datos (Backend). 

## 1. Frontend (Cliente)
Desarrollado en **Flutter Web**.
*   **Lenguaje:** Dart
*   **Framework:** Flutter (configurado para Web)
*   **Estado:** Uso del patrón `Provider` para manejar el estado global (sesión de usuario, personaje actual, campañas).
*   **Navegación:** Manejada con `go_router` para permitir rutas declarativas y deep-linking.
*   **Responsividad:** Adaptable a navegador móvil, tablet y escritorio.
*   **Características Especiales:** 
    * Generación de PDF en el lado del cliente usando `universal_html` y el paquete `pdf` para las Hojas de Personaje.
    * Conexión dinámica a la API a través de `ApiClient` que se ajusta a la URL donde esté servida la aplicación.

## 2. Backend (Servidor)
Desarrollado en **Python**.
*   **Framework:** FastAPI
*   **ORM:** SQLAlchemy 2.0 (Asíncrono)
*   **Base de Datos:** PostgreSQL (Ejecutado en un contenedor Docker)
*   **Seguridad:** 
    * Autenticación basada en JWT (JSON Web Tokens).
    * Contraseñas hasheadas con bcrypt.
    * Validación estricta de datos mediante esquemas Pydantic.
*   **Características Especiales:** 
    * Servicio de archivos estáticos: FastAPI está configurado para servir los archivos generados de Flutter Web desde `/srv/static`. Esto permite un entorno "monolítico" donde un solo puerto (`8000`) sirve tanto la API (en `/api/v1/...`) como la Interfaz Gráfica (en `/`).

## 3. Despliegue y Contenerización
El entorno se administra mediante **Docker Compose**.
*   **Servicios:**
    *   `db`: Contenedor de PostgreSQL.
    *   `backend`: Contenedor principal que ejecuta la aplicación FastAPI (y sirve el Frontend compilado).
*   **Flujo de Despliegue Local:**
    1. Se compila el frontend: `flutter build web`
    2. Los archivos resultantes se mapean (vía volúmenes de Docker) a `/srv/static` en el contenedor del backend.
    3. `ngrok http 8000` expone el contenedor a internet, permitiendo que cualquiera acceda a la UI y la API simultáneamente sin problemas de CORS.
