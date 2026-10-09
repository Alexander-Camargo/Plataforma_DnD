import os
import re

def main():
    base_dir = r"c:\1- PROYECTOS\Hoja para DnD\Plataforma_DnD\dnd_frontend\lib"
    char_path = os.path.join(base_dir, "screens", "character_screen.dart")
    
    with open(char_path, "r", encoding="utf-8") as f:
        char = f.read()
    
    char = char.replace("const AppColors.", "AppColors.")
    
    # Also I need to check if there are other `const` missing.
    # What about BoxShadow?
    # const [ BoxShadow(color: Colors.black.withOpacity(0.04), ...) ]
    # withOpacity is not a const expression.
    char = char.replace("const [", "[")
    char = char.replace("const BoxShadow", "BoxShadow")
    
    # Also let's fix any border side issue: `const BorderSide(color: AppColors.borderLight)` is fine, because AppColors.borderLight is const.
    
    with open(char_path, "w", encoding="utf-8") as f:
        f.write(char)

if __name__ == "__main__":
    main()
