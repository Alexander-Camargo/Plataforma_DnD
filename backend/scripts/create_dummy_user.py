import os
import sys

# Añadir el directorio base al sys.path para importar app
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy.orm import Session
from app.db.session import SessionLocal, engine, Base
import app.db.models
from app.services.auth_service import create_user
from app.schemas.api_models import UserCreate

def create_dummy():
    # Asegurarnos que las tablas existan
    Base.metadata.create_all(bind=engine)
    
    db: Session = SessionLocal()
    try:
        dummy_in = UserCreate(
            username="master",
            email="master@dnd.com",
            password="Password123!"
        )
        user = create_user(db, dummy_in)
        print(f"Usuario Dummy creado exitosamente!")
        print(f"Email: {user.email_encrypted} (En BD está encriptado)")
        print(f"Contraseña: Password123!")
    except Exception as e:
        print(f"No se pudo crear el usuario o ya existe: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    create_dummy()
