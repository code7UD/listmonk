#!/usr/bin/env python3

import psycopg2
import json
from datetime import datetime

# Configuration de la base de données
DB_CONFIG = {
    'host': 'localhost',
    'database': 'listmonk',
    'user': 'postgres',
    'password': ''
}

def connect_db():
    """Connexion à la base de données PostgreSQL"""
    return psycopg2.connect(**DB_CONFIG)

def demo_geographic_queries():
    """Démonstration des requêtes géographiques"""
    print("🗺️  DÉMONSTRATION DES FONCTIONNALITÉS GÉOGRAPHIQUES LISTMONK")
    print("=" * 70)
    
    conn = connect_db()
    cursor = conn.cursor()
    
    # 1. Statistiques globales
    print("\n📊 1. STATISTIQUES GLOBALES")
    print("-" * 30)
    
    cursor.execute("""
        SELECT COUNT(*) as total_subscribers,
               COUNT(DISTINCT departement_numero) as departements_count,
               COUNT(DISTINCT nom_commune) as communes_count,
               COUNT(DISTINCT csp) as csp_count
        FROM subscribers 
        WHERE status = 'enabled' AND code_insee IS NOT NULL
    """)
    
    stats = cursor.fetchone()
    print(f"Total abonnés avec données géo: {stats[0]}")
    print(f"Départements représentés: {stats[1]}")
    print(f"Communes représentées: {stats[2]}")
    print(f"CSP différentes: {stats[3]}")
    
    # 2. Répartition par région
    print("\n🏛️  2. RÉPARTITION PAR RÉGION")
    print("-" * 30)
    
    cursor.execute("""
        SELECT drm.region_nom, COUNT(*) as count_subscribers
        FROM subscribers s 
        LEFT JOIN departement_region_mapping drm ON s.departement_numero = drm.departement_numero 
        WHERE s.status = 'enabled' AND s.code_insee IS NOT NULL
        GROUP BY drm.region_nom 
        ORDER BY count_subscribers DESC
    """)
    
    regions = cursor.fetchall()
    for region, count in regions:
        print(f"  {region}: {count} abonnés")
    
    # 3. Répartition par département
    print("\n🏢 3. RÉPARTITION PAR DÉPARTEMENT")
    print("-" * 30)
    
    cursor.execute("""
        SELECT drm.departement_nom, s.departement_numero, COUNT(*) as count_subscribers
        FROM subscribers s 
        LEFT JOIN departement_region_mapping drm ON s.departement_numero = drm.departement_numero 
        WHERE s.status = 'enabled' AND s.code_insee IS NOT NULL
        GROUP BY drm.departement_nom, s.departement_numero 
        ORDER BY count_subscribers DESC
    """)
    
    departements = cursor.fetchall()
    for dept_nom, dept_num, count in departements:
        print(f"  {dept_nom} ({dept_num}): {count} abonnés")
    
    # 4. Répartition par CSP
    print("\n👥 4. RÉPARTITION PAR CSP")
    print("-" * 30)
    
    cursor.execute("""
        SELECT csp, COUNT(*) as count_subscribers
        FROM subscribers 
        WHERE status = 'enabled' AND csp IS NOT NULL AND csp != ''
        GROUP BY csp 
        ORDER BY count_subscribers DESC
    """)
    
    csps = cursor.fetchall()
    for csp, count in csps:
        print(f"  {csp}: {count} abonnés")
    
    # 5. Statistiques de population
    print("\n🏘️  5. STATISTIQUES DE POPULATION")
    print("-" * 30)
    
    cursor.execute("""
        SELECT 
            MIN(population_commune) as min_pop,
            MAX(population_commune) as max_pop,
            AVG(population_commune)::int as avg_pop,
            SUM(population_commune) as total_pop
        FROM subscribers 
        WHERE status = 'enabled' AND population_commune > 0
    """)
    
    pop_stats = cursor.fetchone()
    print(f"Population minimale: {pop_stats[0]:,} habitants")
    print(f"Population maximale: {pop_stats[1]:,} habitants")
    print(f"Population moyenne: {pop_stats[2]:,} habitants")
    print(f"Population totale représentée: {pop_stats[3]:,} habitants")
    
    # 6. Exemples de requêtes de segmentation
    print("\n🎯 6. EXEMPLES DE SEGMENTATION GÉOGRAPHIQUE")
    print("-" * 45)
    
    # Segmentation par région
    print("\n   a) Abonnés en Auvergne-Rhône-Alpes:")
    cursor.execute("""
        SELECT s.email, s.nom_commune, s.population_commune
        FROM subscribers s 
        LEFT JOIN departement_region_mapping drm ON s.departement_numero = drm.departement_numero 
        WHERE s.status = 'enabled' AND drm.region_nom = 'Auvergne-Rhône-Alpes'
    """)
    
    auvergne_subscribers = cursor.fetchall()
    for email, commune, pop in auvergne_subscribers:
        print(f"      {email} - {commune} ({pop:,} hab.)")
    
    # Segmentation par population
    print("\n   b) Abonnés dans des communes de 10k-50k habitants:")
    cursor.execute("""
        SELECT s.email, s.nom_commune, s.population_commune, drm.region_nom
        FROM subscribers s 
        LEFT JOIN departement_region_mapping drm ON s.departement_numero = drm.departement_numero 
        WHERE s.status = 'enabled' 
        AND s.population_commune >= 10000 
        AND s.population_commune <= 50000
        ORDER BY s.population_commune DESC
    """)
    
    medium_cities = cursor.fetchall()
    for email, commune, pop, region in medium_cities:
        print(f"      {email} - {commune} ({pop:,} hab.) - {region}")
    
    # Segmentation par CSP
    print("\n   c) Cadres et professions intellectuelles supérieures:")
    cursor.execute("""
        SELECT s.email, s.nom_commune, drm.region_nom
        FROM subscribers s 
        LEFT JOIN departement_region_mapping drm ON s.departement_numero = drm.departement_numero 
        WHERE s.status = 'enabled' 
        AND s.csp = 'Cadres et professions intellectuelles supérieures'
    """)
    
    cadres = cursor.fetchall()
    for email, commune, region in cadres:
        print(f"      {email} - {commune} - {region}")
    
    # 7. Requête complexe combinée
    print("\n   d) Requête complexe - Cadres en Île-de-France dans grandes villes:")
    cursor.execute("""
        SELECT s.email, s.nom_commune, s.population_commune, s.csp
        FROM subscribers s 
        LEFT JOIN departement_region_mapping drm ON s.departement_numero = drm.departement_numero 
        WHERE s.status = 'enabled' 
        AND drm.region_nom = 'Île-de-France'
        AND s.csp LIKE '%Cadres%'
        AND s.population_commune > 40000
    """)
    
    complex_query = cursor.fetchall()
    for email, commune, pop, csp in complex_query:
        print(f"      {email} - {commune} ({pop:,} hab.) - {csp}")
    
    # 8. Simulation d'une campagne ciblée
    print("\n📧 7. SIMULATION DE CAMPAGNE CIBLÉE")
    print("-" * 35)
    
    scenarios = [
        {
            "name": "Campagne Régionale Sud",
            "query": """
                SELECT COUNT(*) FROM subscribers s 
                LEFT JOIN departement_region_mapping drm ON s.departement_numero = drm.departement_numero 
                WHERE s.status = 'enabled' 
                AND drm.region_nom IN ('Provence-Alpes-Côte d''Azur', 'Occitanie')
            """
        },
        {
            "name": "Campagne Grandes Métropoles",
            "query": """
                SELECT COUNT(*) FROM subscribers s 
                WHERE s.status = 'enabled' 
                AND s.population_commune > 100000
            """
        },
        {
            "name": "Campagne CSP Cadres",
            "query": """
                SELECT COUNT(*) FROM subscribers s 
                WHERE s.status = 'enabled' 
                AND s.csp LIKE '%Cadres%'
            """
        },
        {
            "name": "Campagne Villes Moyennes Rhône-Alpes",
            "query": """
                SELECT COUNT(*) FROM subscribers s 
                LEFT JOIN departement_region_mapping drm ON s.departement_numero = drm.departement_numero 
                WHERE s.status = 'enabled' 
                AND drm.region_nom = 'Auvergne-Rhône-Alpes'
                AND s.population_commune BETWEEN 20000 AND 100000
            """
        }
    ]
    
    for scenario in scenarios:
        cursor.execute(scenario["query"])
        count = cursor.fetchone()[0]
        print(f"  {scenario['name']}: {count} destinataires")
    
    cursor.close()
    conn.close()
    
    print("\n✅ Démonstration terminée avec succès!")
    print("\n💡 FONCTIONNALITÉS DISPONIBLES:")
    print("   • Segmentation par région française")
    print("   • Segmentation par département")
    print("   • Segmentation par commune")
    print("   • Filtrage par population communale")
    print("   • Filtrage par CSP (Catégorie Socio-Professionnelle)")
    print("   • Combinaison de critères multiples")
    print("   • API REST pour intégration frontend")
    print("   • Import CSV avec données géographiques")

if __name__ == "__main__":
    try:
        demo_geographic_queries()
    except Exception as e:
        print(f"❌ Erreur: {e}")
        print("Vérifiez que PostgreSQL est démarré et que la base de données est configurée.")