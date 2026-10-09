import os

def main():
    base_dir = r"c:\1- PROYECTOS\Hoja para DnD\Plataforma_DnD\dnd_frontend\lib"
    char_path = os.path.join(base_dir, "screens", "character_screen.dart")
    
    with open(char_path, "r", encoding="utf-8") as f:
        char = f.read()
    
    # In _saveChanges, it should be: final data = await _api.patch(
    # In _levelUp, it should be: await _api.patch(
    # Because my previous script just replaced all of them with await _api.patch(
    # Let's restore the one in _saveChanges which has `sheet': newSheet`
    
    char = char.replace("await _api.patch('/characters/${_character!.id}', {\n        'sheet': newSheet,", "final data = await _api.patch('/characters/${_character!.id}', {\n        'sheet': newSheet,")
    
    with open(char_path, "w", encoding="utf-8") as f:
        f.write(char)

if __name__ == "__main__":
    main()
