# 📋 NOTICE D'INSTALLATION - Listmonk Extension Géographique Française

## 🎯 Version Complète avec Frontend

Cette notice décrit l'installation de Listmonk avec l'extension géographique française en utilisant une compilation complète (frontend + backend).

## 📋 Prérequis

### Système
- **Docker** 20.10+ et **Docker Compose** 2.0+
- **4 GB RAM** minimum (compilation frontend)
- **10 GB espace disque** libre
- **Ports libres** : 9000 (Listmonk), 5432 (PostgreSQL)

### Vérification
```bash
docker --version
docker compose version
df -h
```

## 🚀 Installation Automatique

### 1. Cloner le Repository
```bash
git clone https://github.com/code7UD/listmonk.git
cd listmonk
git checkout feature/french-geographic-segmentation
```

### 2. Lancer l'Installation
```bash
# Installation complète automatique
./install-listmonk-geo.sh

# Ou étape par étape
chmod +x scripts/docker/*.sh
./scripts/docker/install-listmonk-geo.sh
```

### 3. Validation
```bash
# Validation automatique
./validate-installation.sh

# Accès interface
open http://localhost:9000
```

## 🔧 Installation Manuelle

### 1. Préparation
```bash
# Créer les répertoires
mkdir -p docker/init-scripts docker/scripts uploads

# Copier les fichiers de configuration
cp .env.example .env
```

### 2. Configuration
```bash
# Éditer le fichier .env
nano .env

# Variables importantes :
LISTMONK_APP_ADMIN_USERNAME=admin
LISTMONK_APP_ADMIN_PASSWORD=votre_mot_de_passe_securise
LISTMONK_DB_PASSWORD=mot_de_passe_db_securise
```

### 3. Construction et Démarrage
```bash
# Construction de l'image (peut prendre 10-15 minutes)
docker compose -f docker-compose.simple.yml build

# Démarrage des services
docker compose -f docker-compose.simple.yml up -d

# Vérification des logs
docker compose -f docker-compose.simple.yml logs -f
```

### 4. Initialisation
```bash
# Attendre que PostgreSQL soit prêt
docker compose -f docker-compose.simple.yml exec postgres pg_isready

# Initialiser Listmonk
docker compose -f docker-compose.simple.yml exec listmonk ./listmonk --install --yes
```

## 📊 Test des Fonctionnalités Géographiques

### 1. Import de Données Test
```bash
# Copier le fichier CSV de test
docker cp test_geo_data.csv listmonk-app-geo:/listmonk/

# Importer via l'interface web
# Aller sur http://localhost:9000/admin/subscribers/import
```

### 2. Vérification Base de Données
```bash
# Connexion à PostgreSQL
docker compose -f docker-compose.simple.yml exec postgres psql -U listmonk -d listmonk

# Vérifier les extensions géographiques
\d+ subscribers
SELECT COUNT(*) FROM departement_region_mapping;
SELECT region_nom, COUNT(*) FROM departement_region_mapping GROUP BY region_nom;
```

### 3. Test des Requêtes Géographiques
```bash
# Tester les endpoints API
curl -X GET "http://localhost:9000/api/geo/regions"
curl -X GET "http://localhost:9000/api/geo/departements"
curl -X GET "http://localhost:9000/api/geo/communes?limit=10"
```

## 🏗️ Architecture de la Solution

### Build Multi-Stage
```
Stage 1: Node.js 18 Alpine
├── Installation yarn dependencies
├── Compilation frontend Vue.js
└── Génération assets optimisés

Stage 2: Go 1.24 Alpine  
├── Téléchargement modules Go
├── Copie source + frontend compilé
├── Installation stuffbin
├── Compilation backend avec assets intégrés
└── Binaire final avec tout intégré

Stage 3: Alpine Runtime
├── Installation dépendances runtime
├── Copie binaire final
├── Configuration utilisateur
└── Scripts d'initialisation
```

### Fichiers Clés
- `Dockerfile.geo.complete` - Build complet frontend + backend
- `docker-compose.simple.yml` - Orchestration PostgreSQL 17 + Listmonk
- `docker/init-scripts/01-init-geo.sql` - Extensions géographiques
- `docker/entrypoint.sh` - Point d'entrée avec initialisation

## 🔍 Diagnostic et Dépannage

### Vérification de l'État
```bash
# État des conteneurs
docker compose -f docker-compose.simple.yml ps

# Logs détaillés
docker compose -f docker-compose.simple.yml logs listmonk

# Diagnostic complet
./scripts/docker/diagnose.sh
```

### Problèmes Courants

#### 1. Erreur de Compilation Frontend
```bash
# Vérifier Node.js dans le conteneur
docker run --rm node:18-alpine node --version

# Nettoyer et reconstruire
docker compose -f docker-compose.simple.yml down
docker system prune -f
docker compose -f docker-compose.simple.yml build --no-cache
```

#### 2. Erreur Base de Données
```bash
# Réinitialiser PostgreSQL
docker compose -f docker-compose.simple.yml down -v
docker volume rm listmonk_postgres_data
docker compose -f docker-compose.simple.yml up -d postgres

# Attendre initialisation
sleep 30
docker compose -f docker-compose.simple.yml up -d listmonk
```

#### 3. Erreur Permissions
```bash
# Corriger les permissions
sudo chown -R $USER:$USER .
chmod +x scripts/docker/*.sh
```

## 📈 Fonctionnalités Géographiques

### Interface Utilisateur
- ✅ Sélection par région française (13 régions)
- ✅ Sélection par département (95 départements)
- ✅ Recherche de communes avec autocomplete
- ✅ Filtrage par population communale
- ✅ Filtrage par CSP (Catégorie Socio-Professionnelle)
- ✅ Prévisualisation temps réel du nombre d'abonnés

### API Endpoints
```
GET  /api/geo/regions          - Liste des régions
GET  /api/geo/departements     - Liste des départements
GET  /api/geo/communes         - Recherche de communes
GET  /api/geo/csps            - Liste des CSP
GET  /api/geo/stats           - Statistiques géographiques
POST /api/lists/query/geo     - Requête de segmentation
```

### Base de Données
```sql
-- Nouvelles colonnes dans subscribers
ALTER TABLE subscribers ADD COLUMN code_insee VARCHAR(10);
ALTER TABLE subscribers ADD COLUMN population_commune INTEGER;
ALTER TABLE subscribers ADD COLUMN departement_numero VARCHAR(3);
-- ... autres colonnes géographiques

-- Table de mapping départements/régions
CREATE TABLE departement_region_mapping (
    departement_numero VARCHAR(3) PRIMARY KEY,
    departement_nom VARCHAR(255) NOT NULL,
    region_nom VARCHAR(255) NOT NULL,
    region_code VARCHAR(3) NOT NULL
);
```

## 🎯 Validation Finale

### Checklist de Validation
- [ ] Conteneurs démarrés sans erreur
- [ ] Interface accessible sur http://localhost:9000
- [ ] Connexion admin réussie
- [ ] Import CSV avec données géographiques
- [ ] Onglet "Géographie" visible dans QueryBuilder
- [ ] Sélection par région fonctionnelle
- [ ] Recherche de communes opérationnelle
- [ ] Comptage temps réel des abonnés
- [ ] Création de liste segmentée géographiquement

### Script de Validation
```bash
# Validation automatique complète
./validate-installation.sh

# Validation manuelle
curl -f http://localhost:9000/health
curl -f http://localhost:9000/api/geo/regions
```

## 📞 Support

### Logs Utiles
```bash
# Logs application
docker compose -f docker-compose.simple.yml logs listmonk

# Logs PostgreSQL
docker compose -f docker-compose.simple.yml logs postgres

# Logs build
docker compose -f docker-compose.simple.yml build 2>&1 | tee build.log
```

### Informations Système
```bash
# Informations Docker
docker info
docker compose version

# Ressources système
free -h
df -h
```

---

## 🎉 Félicitations !

Votre installation de Listmonk avec extension géographique française est maintenant opérationnelle !

**Accès :** http://localhost:9000  
**Admin :** Utilisez les identifiants configurés dans `.env`  
**Documentation :** Consultez `GUIDE_TEST_FINAL.md` pour les tests avancés