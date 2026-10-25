# Test d'affichage de base
import sys

def main():
    print("Test d'affichage de base")
    print(f"Version de Python: {sys.version}")
    print("Ceci est un test simple")
    
    # Écriture dans un fichier
    with open("test_output.txt", "w", encoding="utf-8") as f:
        f.write("Test d'écriture dans un fichier\n")
        f.write(f"Version de Python: {sys.version}\n")
    
    print("Fin du test - Vérifiez le fichier test_output.txt")

if __name__ == "__main__":
    main()
