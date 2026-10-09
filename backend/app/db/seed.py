import json
import uuid
from pathlib import Path

from app.db.session import SessionLocal
from app.db.models import Character

def seed_db():
    db = SessionLocal()
    if db.query(Character).count() > 0:
        print("La base de datos ya tiene personajes. Saltando el seeder.")
        db.close()
        return

    # Ruta al archivo original
    seed_file = Path(__file__).parent.parent.parent.parent.parent / "Generador_Personajes_Avanzado" / "db_personajes.json"
    
    if not seed_file.exists():
        print(f"No se encontró el archivo {seed_file}")
        db.close()
        return

    with open(seed_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    print("Importando personajes originales...")
    for key, char_data in data.items():
        # Extracción de campos
        name = char_data.get("name", "Desconocido")
        class_name = char_data.get("class_name", "Desconocida")
        # El slug podría ser normalizado
        class_slug = class_name.lower().replace(" ", "_")
        
        race = char_data.get("race", "Desconocida")
        level = char_data.get("level", 1)
        avatar_url = char_data.get("image", None)
        status = "alive"
        
        # Mapeamos lo extra a la sheet (jsonb)
        sheet = {
            "stats": char_data.get("stats", {}),
            "modifiers": char_data.get("modifiers", {}),
            "saves": char_data.get("saves", {}),
            "skills": char_data.get("skills", {}),
            "ac": char_data.get("ac", 10),
            "hp": char_data.get("hp", 10),
            "initiative": char_data.get("initiative", "0"),
            "speed": char_data.get("speed", 30),
            "attacks": char_data.get("attacks", []),
            "features": char_data.get("features", []),
            "equipment": char_data.get("equipment", []),
            "spells": char_data.get("spells", []),
            "background": char_data.get("background", {})
        }
        
        char = Character(
            id=uuid.uuid4(),
            name=name,
            race=race,
            class_slug=class_slug,
            level=level,
            avatar_url=avatar_url,
            status=status,
            sheet=sheet
        )
        db.add(char)
    
    db.commit()
    db.close()
    print("Seed completado.")

if __name__ == "__main__":
    seed_db()
