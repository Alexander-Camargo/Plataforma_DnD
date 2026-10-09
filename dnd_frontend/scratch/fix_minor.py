import os

def main():
    base_dir = r"c:\1- PROYECTOS\Hoja para DnD\Plataforma_DnD\dnd_frontend\lib"
    char_path = os.path.join(base_dir, "screens", "character_screen.dart")
    
    with open(char_path, "r", encoding="utf-8") as f:
        char = f.read()
    
    char = char.replace("final data = await _api.patch('/characters/${_character!.id}'", "await _api.patch('/characters/${_character!.id}'")
    char = char.replace("offset: Offset(0, 2)", "offset: const Offset(0, 2)")
    char = char.replace("offset: Offset(0, 3)", "offset: const Offset(0, 3)")
    
    with open(char_path, "w", encoding="utf-8") as f:
        f.write(char)

if __name__ == "__main__":
    main()
