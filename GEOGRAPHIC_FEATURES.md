# 🗺️ Extension Géographique Française pour Listmonk

## 📋 Vue d'ensemble

Cette extension ajoute des fonctionnalités de segmentation géographique française complètes à Listmonk, permettant de filtrer et cibler les abonnés par régions, départements, communes, population et catégories socio-professionnelles (CSP).

## ✨ Fonctionnalités

### 🎯 Segmentation Géographique
- **Filtrage par région** : 13 régions françaises métropolitaines
- **Filtrage par département** : 95 départements français
- **Filtrage par commune** : Toutes les communes françaises avec codes INSEE
- **Filtrage par population** : Fourchettes de population communale
- **Filtrage par CSP** : Catégories socio-professionnelles

### 📊 Données Géographiques Supportées
- **Code INSEE** : Identification unique des communes
- **Population communale** : Nombre d'habitants
- **Mapping départements/régions** : Correspondance automatique
- **Données démographiques** : CSP, dates de naissance
- **Coordonnées complètes** : Adresses, codes postaux, téléphones

## 🗄️ Structure de Base de Données

### Table `subscribers` (étendue)
```sql
-- Nouveaux champs géographiques ajoutés
ALTER TABLE subscribers ADD COLUMN code_insee VARCHAR(10);
ALTER TABLE subscribers ADD COLUMN population_commune INTEGER;
ALTER TABLE subscribers ADD COLUMN date_naissance DATE;
ALTER TABLE subscribers ADD COLUMN csp VARCHAR(100);
ALTER TABLE subscribers ADD COLUMN siren VARCHAR(20);
ALTER TABLE subscribers ADD COLUMN siret VARCHAR(20);
ALTER TABLE subscribers ADD COLUMN telecopie VARCHAR(20);
ALTER TABLE subscribers ADD COLUMN nom_commune VARCHAR(255);
ALTER TABLE subscribers ADD COLUMN departement_numero VARCHAR(3);
ALTER TABLE subscribers ADD COLUMN phone VARCHAR(50);
ALTER TABLE subscribers ADD COLUMN website VARCHAR(255);
ALTER TABLE subscribers ADD COLUMN address1 TEXT;
ALTER TABLE subscribers ADD COLUMN city VARCHAR(255);
ALTER TABLE subscribers ADD COLUMN state VARCHAR(255);
ALTER TABLE subscribers ADD COLUMN zipcode VARCHAR(10);
ALTER TABLE subscribers ADD COLUMN country VARCHAR(100);
ALTER TABLE subscribers ADD COLUMN title VARCHAR(10);
```

### Table `departement_region_mapping`
```sql
CREATE TABLE departement_region_mapping (
    departement_numero VARCHAR(3) PRIMARY KEY,
    departement_nom VARCHAR(255) NOT NULL,
    region_nom VARCHAR(255) NOT NULL,
    region_code VARCHAR(3) NOT NULL
);
```

## 📥 Format CSV d'Import

### Structure CSV Supportée
```csv
email,firstname,lastname,title,phone,website,address1,city,state,zipcode,country,code_insee,population_commune,date_naissance,csp,siren,siret,telecopie,nom_commune,departement_numero
```

### Exemple de Données
```csv
marie.dupont@example.com,Marie,DUPONT,Mme,01 23 45 67 89,www.example.com,"123 rue de la Paix",PARIS 1ER ARRONDISSEMENT,PARIS,75001,France,75101,50000,15/03/1985,Cadres et professions intellectuelles supérieures,123456789,12345678901234,,PARIS 1ER ARRONDISSEMENT,75
```

## 🔌 API REST

### Endpoints Géographiques

#### 1. Récupérer les Régions
```http
GET /api/geo/regions
```
**Réponse :**
```json
{
  "data": [
    {
      "region_nom": "Auvergne-Rhône-Alpes",
      "region_code": "84"
    }
  ]
}
```

#### 2. Récupérer les Départements
```http
GET /api/geo/departements?region=Auvergne-Rhône-Alpes
```
**Réponse :**
```json
{
  "data": [
    {
      "departement_numero": "01",
      "departement_nom": "Ain",
      "region_nom": "Auvergne-Rhône-Alpes",
      "region_code": "84"
    }
  ]
}
```

#### 3. Récupérer les Communes
```http
GET /api/geo/communes?departement=01&search=ABERGEMENT&limit=20
```
**Réponse :**
```json
{
  "data": [
    {
      "nom_commune": "L'ABERGEMENT-CLÉMENCIAT",
      "code_insee": "1001",
      "population_commune": 780,
      "departement_numero": "01",
      "count": 1
    }
  ]
}
```

#### 4. Récupérer les CSP
```http
GET /api/geo/csps
```
**Réponse :**
```json
{
  "data": [
    {
      "csp": "Cadres et professions intellectuelles supérieures",
      "count": 15
    }
  ]
}
```

#### 5. Statistiques Géographiques
```http
GET /api/geo/stats
```
**Réponse :**
```json
{
  "data": {
    "total_subscribers": 1250,
    "by_region": {
      "Île-de-France": 450,
      "Auvergne-Rhône-Alpes": 200
    },
    "by_csp": {
      "Cadres et professions intellectuelles supérieures": 300,
      "Employés": 250
    },
    "population_stats": {
      "min": 780,
      "max": 2200000,
      "avg": 45000,
      "total": 56250000
    }
  }
}
```

#### 6. Requête de Segmentation
```http
POST /api/lists/query/geo
```
**Corps de la requête :**
```json
{
  "regions": ["Auvergne-Rhône-Alpes", "Provence-Alpes-Côte d'Azur"],
  "departements": ["01", "13"],
  "communes": ["LYON", "MARSEILLE"],
  "use_population": true,
  "population_min": 10000,
  "population_max": 100000,
  "csps": ["Cadres et professions intellectuelles supérieures"],
  "date_naissance_min": "1980-01-01",
  "date_naissance_max": "1990-12-31"
}
```
**Réponse :**
```json
{
  "data": {
    "count": 42,
    "query": "SELECT COUNT(*) FROM subscribers s LEFT JOIN...",
    "params": {...}
  }
}
```

## 🎨 Interface Frontend (Vue.js)

### Composant GeoSelector
Le composant `GeoSelector.vue` fournit une interface utilisateur intuitive avec :

- **Onglets de navigation** : Région, Département, Commune
- **Sélection multiple** : Dropdowns avec sélection multiple
- **Autocomplete** : Recherche de communes en temps réel
- **Filtres de population** : Sliders pour min/max
- **Filtres CSP** : Sélection des catégories socio-professionnelles
- **Prévisualisation** : Comptage en temps réel des abonnés correspondants

### Store Vuex
Le module `store/modules/geo.js` gère :
- État des données géographiques
- Actions pour récupérer les données via API
- Mutations pour mettre à jour l'état
- Cache des données pour optimiser les performances

## 📊 Exemples de Requêtes

### 1. Segmentation par Région
```sql
SELECT COUNT(*) FROM subscribers s 
LEFT JOIN departement_region_mapping drm ON s.departement_numero = drm.departement_numero 
WHERE s.status = 'enabled' AND drm.region_nom = 'Auvergne-Rhône-Alpes';
```

### 2. Filtrage par Population
```sql
SELECT COUNT(*) FROM subscribers s 
WHERE s.status = 'enabled' 
AND s.population_commune BETWEEN 10000 AND 50000;
```

### 3. Segmentation par CSP
```sql
SELECT COUNT(*) FROM subscribers s 
WHERE s.status = 'enabled' 
AND s.csp = 'Cadres et professions intellectuelles supérieures';
```

### 4. Requête Complexe Combinée
```sql
SELECT COUNT(*) FROM subscribers s 
LEFT JOIN departement_region_mapping drm ON s.departement_numero = drm.departement_numero 
WHERE s.status = 'enabled' 
AND drm.region_nom = 'Île-de-France'
AND s.csp LIKE '%Cadres%'
AND s.population_commune > 40000;
```

## 🚀 Installation et Configuration

### 1. Migration de Base de Données
```bash
./listmonk --upgrade --config config.toml
```

### 2. Configuration
Aucune configuration supplémentaire requise. Les extensions géographiques sont automatiquement activées.

### 3. Import de Données
1. Préparer un fichier CSV avec la structure géographique
2. Utiliser l'interface d'import de Listmonk
3. Mapper les colonnes CSV aux champs géographiques

## 🎯 Cas d'Usage

### 1. Campagnes Régionales
- Cibler les abonnés d'une région spécifique
- Adapter le contenu aux spécificités locales
- Optimiser les horaires d'envoi par fuseau horaire

### 2. Marketing Local
- Promouvoir des événements dans des villes spécifiques
- Cibler par taille de commune (rural vs urbain)
- Segmenter par densité de population

### 3. Segmentation Démographique
- Cibler par catégorie socio-professionnelle
- Adapter les messages par tranche d'âge
- Personnaliser par niveau socio-économique

### 4. Analyses Géomarketing
- Analyser la répartition géographique des abonnés
- Identifier les zones de forte/faible pénétration
- Optimiser les stratégies d'acquisition

## 📈 Performance

### Index Optimisés
```sql
CREATE INDEX idx_subscribers_departement ON subscribers(departement_numero);
CREATE INDEX idx_subscribers_code_insee ON subscribers(code_insee);
CREATE INDEX idx_subscribers_population ON subscribers(population_commune);
CREATE INDEX idx_subscribers_csp ON subscribers(csp);
CREATE INDEX idx_subscribers_nom_commune ON subscribers(nom_commune);
```

### Optimisations
- **Requêtes indexées** : Toutes les colonnes de filtrage sont indexées
- **Jointures optimisées** : Mapping départements/régions en table séparée
- **Cache frontend** : Données géographiques mises en cache côté client
- **Pagination** : Limitation des résultats pour les grandes listes

## 🔧 Maintenance

### Mise à Jour des Données Géographiques
Les données de population et de découpage administratif peuvent être mises à jour via :
```sql
UPDATE subscribers SET population_commune = NEW_VALUE WHERE code_insee = 'CODE';
```

### Ajout de Nouvelles Régions/Départements
```sql
INSERT INTO departement_region_mapping VALUES ('XX', 'Nouveau Département', 'Nouvelle Région', 'XX');
```

## 🐛 Dépannage

### Problèmes Courants

1. **Import CSV échoue**
   - Vérifier la structure des colonnes
   - Contrôler l'encodage UTF-8
   - Valider les codes INSEE

2. **Requêtes lentes**
   - Vérifier les index
   - Analyser les plans d'exécution
   - Optimiser les filtres

3. **Données manquantes**
   - Contrôler les jointures
   - Vérifier les codes départements
   - Valider les données sources

## 📚 Références

- **Codes INSEE** : [insee.fr](https://www.insee.fr)
- **Découpage administratif** : [data.gouv.fr](https://www.data.gouv.fr)
- **Documentation Listmonk** : [listmonk.app](https://listmonk.app)

## 🤝 Contribution

Pour contribuer à cette extension :
1. Fork le repository
2. Créer une branche feature
3. Implémenter les modifications
4. Ajouter des tests
5. Soumettre une pull request

## 📄 Licence

Cette extension suit la même licence que Listmonk (AGPL v3).