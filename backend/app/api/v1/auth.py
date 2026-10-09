from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_current_user
from app.schemas.api_models import UserCreate, UserLogin, Token, UserOut
from app.services import auth_service
from app.db.models import User

router = APIRouter()

@router.post("/register", response_model=UserOut, status_code=201)
def register(user_in: UserCreate, db: Session = Depends(get_db)):
    return auth_service.create_user(db, user_in)

@router.post("/login", response_model=Token)
def login(user_in: UserLogin, db: Session = Depends(get_db)):
    return auth_service.login(db, user_in)

@router.get("/me", response_model=UserOut)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user
