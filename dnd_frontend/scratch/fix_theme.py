import os

def main():
    base_dir = r"c:\1- PROYECTOS\Hoja para DnD\Plataforma_DnD\dnd_frontend\lib"
    char_path = os.path.join(base_dir, "screens", "character_screen.dart")
    
    with open(char_path, "r", encoding="utf-8") as f:
        char = f.read()
    
    char = char.replace("AppColors.bgLight", "AppColors.bgCard")
    char = char.replace("AppColors.borderLight", "AppColors.border")
    char = char.replace("AppColors.textMain", "AppColors.text")
    char = char.replace("const AppColors.", "AppColors.")
    
    with open(char_path, "w", encoding="utf-8") as f:
        f.write(char)

if __name__ == "__main__":
    main()
