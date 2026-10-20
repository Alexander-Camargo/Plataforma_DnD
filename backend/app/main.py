"""
Archivo: main.py
Propósito: Punto de entrada de la aplicación FastAPI, configuración de ciclo de vida (lifespan), CORS, rutas API y servicio de archivos estáticos del frontend.
Creador: Alexander Camargo
Modificaciones / Actualizaciones:
- 2026-10-08 [Alexander Camargo]: Configuración base de FastAPI, routers y CORS.
- 2026-10-12 [Joshua Pérez Bullen]: Cabeceras anti-caché en archivos bootstrap de Flutter web.
- 2026-10-18 [Alexander Camargo]: Inicialización automática de tablas y siembra de catálogos en el evento lifespan.
- 2026-10-19 [Alexander Camargo]: Garantizar columna experience en tabla characters durante lifespan.
- 2026-10-19 [Alexander Camargo]: Enrutamiento SPA en FastAPI con fallback index.html y soporte CORS para IPs de red local.
- 2026-10-19 [Alexander Camargo]: Actualización de nombre oficial del sistema a LA CRIPTA.
"""
from contextlib import asynccontextmanager
from pathlib import Path
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from starlette.exceptions import HTTPException as StarletteHTTPException
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
    title="LA CRIPTA API",
    description="API para LA CRIPTA - Plataforma y gestor de personajes D&D 5e.",
    version="1.0.0",
    lifespan=lifespan,
    openapi_url="/api/v1/openapi.json",
    docs_url="/api/v1/docs"
)

if settings.cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[str(origin) for origin in settings.cors_origins],
        allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1|0\.0\.0\.0|192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+|172\.(1[6-9]|2\d|3[0-1])\.\d+\.\d+)(:\d+)?$",
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
        try:
            response = await super().get_response(path, scope)
            if path in (".", "", "index.html", "flutter_bootstrap.js", "version.json", "manifest.json", "flutter_service_worker.js"):
                response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate, max-age=0"
                response.headers["Pragma"] = "no-cache"
                response.headers["Expires"] = "0"
            return response
        except StarletteHTTPException as ex:
            # Si el archivo no existe y es una petición GET de navegación SPA (sin extensión de archivo estático)
            if ex.status_code == 404 and scope.get("method") == "GET":
                if "." not in Path(path).name:
                    index_file = Path(self.directory) / "index.html"
                    if index_file.exists():
                        return FileResponse(
                            index_file,
                            headers={
                                "Cache-Control": "no-cache, no-store, must-revalidate, max-age=0",
                                "Pragma": "no-cache",
                                "Expires": "0",
                            },
                        )
            raise

SPAStaticFiles = NoCacheStaticFiles

# Servir Frontend compilado (si existe)
# Busca en /srv/static (contenedor Docker) o en la ruta relativa de frontend para desarrollo local
static_dir = Path("/srv/static")
if not static_dir.exists():
    local_static = Path(__file__).resolve().parent.parent.parent / "dnd_frontend" / "build" / "web"
    if local_static.exists():
        static_dir = local_static

if static_dir.exists() and (static_dir / "index.html").exists():
    app.mount("/", NoCacheStaticFiles(directory=str(static_dir), html=True), name="web")
