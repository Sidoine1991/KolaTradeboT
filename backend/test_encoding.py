# Test d'encodage et de sortie de base
import sys

def main():
    print("=== Test d'encodage et de sortie ===")
    print(f"Version de Python: {sys.version}")
    print("Test de caractères spéciaux: éèàçù")
    
    # Tester l'écriture dans un fichier
    with open("test_output.txt", "w", encoding="utf-8") as f:
        f.write("Ceci est un test d'écriture avec des caractères spéciaux: éèàçù\n")
        f.write(f"Version de Python: {sys.version}\n")
    
    print("Test d'écriture dans un fichier réussi. Vérifiez le fichier test_output.txt")

if __name__ == "__main__":
    main()
