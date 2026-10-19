"""
Archivo: main.py
Propósito: Punto de entrada de la aplicación FastAPI, configuración de ciclo de vida (lifespan), CORS, rutas API y servicio de archivos estáticos del frontend.
Creador: Alexander Camargo
Modificaciones / Actualizaciones:
- 2026-10-08 [Alexander Camargo]: Configuración base de FastAPI, routers y CORS.
- 2026-10-12 [Joshua Pérez Bullen]: Cabeceras anti-caché en archivos bootstrap de Flutter web.
- 2026-10-18 [Alexander Camargo]: Inicialización automática de tablas y siembra de catálogos en el evento lifespan.
- 2026-10-19 [Alexander Camargo]: Garantizar columna experience en tabla characters durante lifespan.
"""
from contextlib import asynccontextmanager
from pathlib import Path
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from app.core.config import get_settings
from app.api.v1.api import api_router
from app.db.session import engine, Base, SessionLocal
from app.db.catalog_seed import seed_catalogs
import app.db.models  # Forzar carga de modelos

settings = get_settings()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Setup inicial (crear tablas si no existen ya que no tenemos migraciones iniciales aún)
    Base.metadata.create_all(bind=engine)
    if engine.dialect.name == "postgresql":
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE characters ADD COLUMN IF NOT EXISTS experience INTEGER DEFAULT 0;"))
    with SessionLocal() as session:
        seed_catalogs(session)
    yield
    # Limpieza

app = FastAPI(
    title="Plataforma D&D API",
    description="API para generador y gestor de personajes D&D 5e.",
    version="1.0.0",
    lifespan=lifespan,
    openapi_url="/api/v1/openapi.json",
    docs_url="/api/v1/docs"
)

if settings.cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[str(origin) for origin in settings.cors_origins],
        allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

app.include_router(api_router, prefix="/api/v1")

@app.get("/health", tags=["system"])
def health_check():
    return {"status": "ok", "env": settings.env}

class NoCacheStaticFiles(StaticFiles):
    async def get_response(self, path: str, scope):
        response = await super().get_response(path, scope)
        if path in (".", "", "index.html", "flutter_bootstrap.js", "version.json", "manifest.json", "flutter_service_worker.js"):
            response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate, max-age=0"
            response.headers["Pragma"] = "no-cache"
            response.headers["Expires"] = "0"
        return response

# Servir Frontend compilado (si existe)
# Esto permite usar ngrok en el puerto 8000 y servir tanto API como Web
static_dir = Path("/srv/static")
if static_dir.exists():
    app.mount("/", NoCacheStaticFiles(directory=str(static_dir), html=True), name="web")
