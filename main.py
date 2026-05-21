import re
import argparse
import mysql.connector
from pathlib import Path
from pdfminer.high_level import extract_text

DB_CONFIG = {
    "host": "mysql",      
    "user": "root",
    "password": "rootpassword",
    "database": "app_db",
    "port": 3306
}

def extract_data_from_pdf(pdf_path):
    """Extrait les données du PDF et retourne une liste de dictionnaires."""
    print(f"Lecture du PDF : {pdf_path}...")
    text = extract_text(pdf_path)

    pattern = re.compile(
        r"""
        ^\s*
        (?P<code>\d{7})             
        \s+
        (?P<designation>.*?)         
        \s+
        \d+,\d+                     
        \s+
        (?P<colisage>\d+)            
        \s+
        (?P<quantite>\d+)            
        \s+
        (?P<montant>\d+,\d+)        
        """,
        re.VERBOSE | re.MULTILINE
    )

    results = []

    for match in pattern.finditer(text):
        code = match.group("code")
        designation = match.group("designation").strip()
        colisage = int(match.group("colisage"))
        quantite = int(match.group("quantite"))
        montant = float(match.group("montant").replace(",", "."))

        total = quantite * colisage

        results.append({
            "code_article": code,
            "designation": designation,
            "quantite": total
        })

    return results

def insert_into_mysql(data):
    """Insère les données en base MySQL."""
    connection = None
    try:
        connection = mysql.connector.connect(**DB_CONFIG)
        cursor = connection.cursor()
        print("Connecté à MySQL")

        for row in data:
            cursor.execute(
                "SELECT quantite FROM stock WHERE code_article = %s",
                (row["code_article"],)
            )
            existing_row = cursor.fetchone()

            if existing_row:
                new_quantite = existing_row[0] + row["quantite"]
                cursor.execute(
                    """
                    UPDATE stock
                    SET quantite = %s, designation = %s
                    WHERE code_article = %s
                    """,
                    (new_quantite, row["designation"], row["code_article"])
                )
                print(f"MAJ : {row['code_article']} (Quantité totale: {new_quantite})")
            else:
                cursor.execute(
                    """
                    INSERT INTO stock (code_article, designation, quantite)
                    VALUES (%s, %s, %s)
                    """,
                    (row["code_article"], row["designation"], row["quantite"])
                )
                print(f"Ajout : {row['code_article']} (Quantité: {row['quantite']})")

        connection.commit()
        print("Import terminé avec succès !")

    except mysql.connector.Error as err:
        print(f"Erreur MySQL : {err}")
        if connection:
            connection.rollback()
    finally:
        if connection:
            cursor.close()
            connection.close()

def main():
    parser = argparse.ArgumentParser(description="Extraire les données d'un PDF et les insérer en MySQL.")
    parser.add_argument(
        "--file",
        type=str,
        required=True,
        help="Chemin vers le fichier PDF à traiter."
    )
    args = parser.parse_args()

    if not Path(args.file).exists():
        print(f"Erreur : Le fichier {args.file} n'existe pas.")
        return

    data = extract_data_from_pdf(args.file)
    print(f"\n{len(data)} lignes extraites.")

    insert_into_mysql(data)

if __name__ == "__main__":
    main()