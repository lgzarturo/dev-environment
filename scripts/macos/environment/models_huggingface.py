import os
import argparse
import shutil
from huggingface_hub import scan_cache_dir

# Función para obtener el tamaño de un directorio
def get_directory_size(path):
    total_size = 0
    for dirpath, dirnames, filenames in os.walk(path):
        for f in filenames:
            fp = os.path.join(dirpath, f)
            total_size += os.path.getsize(fp)
    return total_size

# Función para listar los modelos descargados y su tamaño
def list_models():
    cache_info = scan_cache_dir()
    print("Modelos descargados:")
    for idx, repo_info in enumerate(cache_info.repos):
        size_in_bytes = get_directory_size(repo_info.repo_path)
        size_in_mb = size_in_bytes / (1024 * 1024)
        print(f"{idx + 1}. Model: {repo_info.repo_id} | Size: {size_in_mb:.2f} MB | Path: {repo_info.repo_path}")

# Función para eliminar un modelo
def delete_model(model_path):
    try:
        shutil.rmtree(model_path)  # Borrar la carpeta completa del modelo
        print(f"El modelo en '{model_path}' ha sido eliminado correctamente.")
    except FileNotFoundError:
        print(f"Error: El modelo en '{model_path}' no se encontró.")
    except Exception as e:
        print(f"Error al eliminar el modelo en '{model_path}': {e}")

# Función principal que gestiona los comandos
def main():
    parser = argparse.ArgumentParser(description="Gestión de modelos descargados de Hugging Face.")
    parser.add_argument('--list', action='store_true', help="Lista todos los modelos descargados y el tamaño que ocupan en disco.")
    parser.add_argument('--delete', type=int, help="Elimina el modelo especificado por su número en la lista.")

    args = parser.parse_args()

    cache_info = scan_cache_dir()

    if args.list:
        list_models()
    elif args.delete is not None:
        if 1 <= args.delete <= len(cache_info.repos):
            print(f"Eliminando modelo número {args.delete}...")
            repo_keys = list(cache_info.repos.keys())
            print(repo_keys)
            repo_key = repo_keys[args.delete - 1]
            repo_info = cache_info.repos[repo_key]
            print(f"Modelo: {repo_info.repo_id}")
            #delete_model(repo_info.repo_path)
        else:
            print("El número de modelo especificado no es válido.")
    else:
        print("Por favor, usa --list para listar los modelos o --delete <número> para eliminar un modelo.")

if __name__ == "__main__":
    main()
