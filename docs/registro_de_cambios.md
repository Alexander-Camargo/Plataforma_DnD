# Registro de Cambios y Progreso

Este archivo sirve como bitácora de todo lo que se ha implementado en la plataforma hasta la fecha.

## Hitos Importantes

### 1. Reestructuración del Proyecto
- Se migró el código desde un prototipo en HTML/JS a una pila completa utilizando **Flutter Web** para la interfaz y **FastAPI (Python)** para el backend.
- Se implementó **Docker Compose** para asegurar que la base de datos (PostgreSQL) y el backend se mantengan sincronizados y portables.

### 2. Estandarización Estética
- Se creó `app_theme.dart` para unificar todos los colores, tipografías y sombras de la aplicación basándose en un diseño inspirado en pergaminos y temas de fantasía (D&D).
- Se eliminaron todos los colores "hardcodeados" en el proyecto para usar variables limpias.
- Todas las pantallas (`home`, `login`, `my_characters`, `character_screen`) han sido adaptadas para seguir esta estética.

### 3. Solución de "Un Solo Puerto" (Monolito)
- Para facilitar compartir el proyecto por internet (ej. Ngrok) sin chocar con errores de CORS o tener que iniciar varios túneles, se configuró el backend de FastAPI para que **sirva automáticamente la carpeta de Flutter Web**.
- Comando utilizado: `flutter build web` que luego es copiado al volumen de Docker en `/srv/static`.
- Esto permite acceder a `http://localhost:8000` y ver el proyecto entero.

### 4. Implementación de Hoja de Personaje
- Se implementó la visualización de la ficha del personaje completa (Vida, CA, Atributos, Tiradas de Salvación y Habilidades).
- Se habilitó el **Modo Edición**, para que el jugador pueda guardar cambios sobre la marcha.
- Se añadió la exportación a **PDF**, recreando la lógica del antiguo `html2pdf.js` pero en Dart, utilizando el paquete `pdf` y forzando la descarga nativa mediante `universal_html` para evadir problemas de plugins en web.

### 5. Control de Versiones
- Se ha inicializado un repositorio en **Git** en la carpeta raíz.
- Se agregó el archivo `.gitignore` para prevenir la subida de binarios, archivos temporales y la base de datos local.
- Se vinculó y realizó un `push` inicial exitoso a la cuenta de GitHub asociada (`Alexander-Camargo/Plataforma_DnD`).
