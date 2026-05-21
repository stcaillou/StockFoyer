##Ici on récupere le csv 'data_cleaned.csv'
##Puis on le charge dans la BDD

import mysql.connector
from pathlib import Path
import argparse
import re
import csv
from datetime import datetime, timezone

DB_CONFIG = {
    "host": "mysql",      
    "user": "root",
    "password": "rootpassword",
    "database": "app_db",
    "port": 3306
}

def extract_data(file):
    with open(file, newline='') as csvfile:
        spamreader = csv.reader(csvfile, delimiter=';', quotechar='|')

        connection = mysql.connector.connect(**DB_CONFIG)
        cursor = connection.cursor()
        print("Connecté à MySQL")

        cursor.execute("SELECT datetime FROM historique_vente ORDER BY datetime DESC LIMIT 1")
        
        result = cursor.fetchone()

        last_date = result[0] if result else None

        if last_date is not None and last_date.tzinfo is None:
            last_date = last_date.replace(tzinfo=timezone.utc).replace(microsecond=0)

        for row in spamreader:
            if row[0] != "Date":
                dt = row[0]
                
                dt = datetime.fromisoformat(dt.replace("Z", "+00:00")).replace(microsecond=0)
                if(last_date == None or dt > last_date):
                    cursor.execute(
                        "INSERT INTO historique_vente (datetime, nom_tpe) VALUES (%s, %s)",
                        (dt, row[8])
                    )
                
        connection.commit()

def main():
    parser = argparse.ArgumentParser(description="Extraire les données d'un excel et les insérer en MySQL.")
    parser.add_argument(
        "--file",
        type=str,
        required=True,
        help="Chemin vers le fichier excel à traiter."
    )
    args = parser.parse_args()

    if not Path(args.file).exists():
        print(f"Erreur : Le fichier {args.file} n'existe pas.")
        return

    data = extract_data(args.file)

if __name__ == "__main__":
    main()    
