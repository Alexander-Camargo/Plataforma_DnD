"""
Archivo: post_build_web.py
Propósito: Script post-compilación para aplicar cache-busting automático en Flutter Web (Cloudflare Edge & Navegadores).
Creador: Alexander Camargo
"""
import time
from pathlib import Path

def apply_cache_busting():
    repo_root = Path(__file__).resolve().parent.parent
    web_dir = repo_root / "dnd_frontend" / "build" / "web"
    
    if not web_dir.exists():
        print(f"Error: {web_dir} no existe.")
        return False
        
    version = int(time.time())
    
    # 1. Parchear flutter_bootstrap.js para que solicite main.dart.js con version hash
    bootstrap_file = web_dir / "flutter_bootstrap.js"
    if bootstrap_file.exists():
        content = bootstrap_file.read_text(encoding="utf-8")
        # Evitar duplicar ?v= si ya se aplicó
        if "main.dart.js?v=" not in content:
            new_content = content.replace("main.dart.js", f"main.dart.js?v={version}")
            bootstrap_file.write_text(new_content, encoding="utf-8")
            print(f"flutter_bootstrap.js parcheado con main.dart.js?v={version}")
        else:
            print("flutter_bootstrap.js ya contiene parámetro de versión.")

    # 2. Parchear index.html para que solicite flutter_bootstrap.js con version hash
    index_file = web_dir / "index.html"
    if index_file.exists():
        content = index_file.read_text(encoding="utf-8")
        if "flutter_bootstrap.js?v=" not in content:
            new_content = content.replace("flutter_bootstrap.js", f"flutter_bootstrap.js?v={version}")
            index_file.write_text(new_content, encoding="utf-8")
            print(f"index.html parcheado con flutter_bootstrap.js?v={version}")
        else:
            print("index.html ya contiene parámetro de versión.")
            
    print(f"Cache-busting completado exitosamente con versión {version}.")
    return True

if __name__ == "__main__":
    apply_cache_busting()
