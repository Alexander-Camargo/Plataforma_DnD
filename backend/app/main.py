import json
from contextlib import asynccontextmanager
from pathlib import Path
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

from app.core.config import get_settings
from app.api.v1.api import api_router
from app.db.session import engine, Base
import app.db.models  # Forzar carga de modelos

settings = get_settings()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Setup inicial (crear tablas si no existen ya que no tenemos migraciones iniciales aún)
    Base.metadata.create_all(bind=engine)
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
        if path in ("", "index.html", "flutter_bootstrap.js", "version.json", "manifest.json", "flutter_service_worker.js"):
            response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate, max-age=0"
            response.headers["Pragma"] = "no-cache"
            response.headers["Expires"] = "0"
        return response

# Servir Frontend compilado (si existe)
# Esto permite usar ngrok en el puerto 8000 y servir tanto API como Web
static_dir = Path("/srv/static")
if static_dir.exists():
    app.mount("/", NoCacheStaticFiles(directory=str(static_dir), html=True), name="web")
