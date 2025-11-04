#!/usr/bin/env python3

import requests
import json

# Configuration
BASE_URL = "http://localhost:9000"

def test_geo_apis():
    print("🧪 Test des API géographiques de Listmonk")
    print("=" * 50)
    
    # Test 1: Récupérer les régions
    print("\n1. Test API /api/geo/regions")
    try:
        response = requests.get(f"{BASE_URL}/api/geo/regions")
        print(f"Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"Nombre de régions: {len(data.get('data', []))}")
            if data.get('data'):
                print(f"Première région: {data['data'][0]}")
        else:
            print(f"Erreur: {response.text}")
    except Exception as e:
        print(f"Erreur de connexion: {e}")
    
    # Test 2: Récupérer les départements
    print("\n2. Test API /api/geo/departements")
    try:
        response = requests.get(f"{BASE_URL}/api/geo/departements")
        print(f"Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"Nombre de départements: {len(data.get('data', []))}")
            if data.get('data'):
                print(f"Premier département: {data['data'][0]}")
        else:
            print(f"Erreur: {response.text}")
    except Exception as e:
        print(f"Erreur de connexion: {e}")
    
    # Test 3: Récupérer les communes
    print("\n3. Test API /api/geo/communes")
    try:
        response = requests.get(f"{BASE_URL}/api/geo/communes")
        print(f"Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"Nombre de communes: {len(data.get('data', []))}")
            if data.get('data'):
                print(f"Première commune: {data['data'][0]}")
        else:
            print(f"Erreur: {response.text}")
    except Exception as e:
        print(f"Erreur de connexion: {e}")
    
    # Test 4: Récupérer les CSP
    print("\n4. Test API /api/geo/csps")
    try:
        response = requests.get(f"{BASE_URL}/api/geo/csps")
        print(f"Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"Nombre de CSP: {len(data.get('data', []))}")
            if data.get('data'):
                print(f"Première CSP: {data['data'][0]}")
        else:
            print(f"Erreur: {response.text}")
    except Exception as e:
        print(f"Erreur de connexion: {e}")
    
    # Test 5: Récupérer les statistiques géographiques
    print("\n5. Test API /api/geo/stats")
    try:
        response = requests.get(f"{BASE_URL}/api/geo/stats")
        print(f"Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"Statistiques: {json.dumps(data.get('data', {}), indent=2)}")
        else:
            print(f"Erreur: {response.text}")
    except Exception as e:
        print(f"Erreur de connexion: {e}")
    
    # Test 6: Test de requête géographique
    print("\n6. Test API /api/lists/query/geo")
    try:
        query_params = {
            "regions": ["Auvergne-Rhône-Alpes"],
            "use_population": True,
            "population_min": 500
        }
        response = requests.post(f"{BASE_URL}/api/lists/query/geo", json=query_params)
        print(f"Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"Résultat de la requête: {json.dumps(data.get('data', {}), indent=2)}")
        else:
            print(f"Erreur: {response.text}")
    except Exception as e:
        print(f"Erreur de connexion: {e}")

if __name__ == "__main__":
    test_geo_apis()