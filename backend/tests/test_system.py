import pytest
from fastapi.testclient import TestClient
from app.main import app, NoCacheStaticFiles
from app.core.config import Settings
from app.db import session as session_module


def test_health_endpoint(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "env": "test"}


@pytest.mark.parametrize("env,expected", [("production", True), ("development", False), ("test", False)])
def test_production_flag(env, expected):
    assert Settings(env=env).is_production is expected


def test_session_dependency_closes_after_use(db, monkeypatch):
    monkeypatch.setattr(session_module, "SessionLocal", lambda: db)
    dependency = session_module.get_db()
    assert next(dependency) is db
    with pytest.raises(StopIteration):
        next(dependency)


def test_static_bootstrap_is_not_cached_but_other_assets_keep_normal_headers(tmp_path):
    from fastapi import FastAPI
    (tmp_path / "index.html").write_text("<html>Test</html>")
    (tmp_path / "flutter_bootstrap.js").write_text("window.test = true;")
    (tmp_path / "asset.txt").write_text("asset")
    test_app = FastAPI()
    test_app.mount("/", NoCacheStaticFiles(directory=str(tmp_path), html=True))
    with TestClient(test_app) as static_client:
        for path in ("/", "/index.html", "/flutter_bootstrap.js"):
            response = static_client.get(path)
            assert response.status_code == 200
            assert "no-store" in response.headers["cache-control"]
            assert response.headers["pragma"] == "no-cache"
        assert "cache-control" not in static_client.get("/asset.txt").headers

