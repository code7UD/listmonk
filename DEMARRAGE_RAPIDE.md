# 🚀 DÉMARRAGE RAPIDE - Listmonk Extension Géographique

## ⚡ Installation en 3 Commandes

```bash
# 1. Cloner et préparer
git clone https://github.com/code7UD/listmonk.git
cd listmonk
git checkout feature/french-geographic-segmentation

# 2. Valider l'environnement
./validate-docker-build.sh

# 3. Installer et démarrer
./install-listmonk-geo.sh
```

**Accès :** http://localhost:9000  
**Admin :** admin / admin123 (modifiable dans .env)

## 🎯 Fonctionnalités Géographiques

### ✅ Ce qui fonctionne maintenant
- **Segmentation par région** (13 régions françaises)
- **Segmentation par département** (95 départements)
- **Recherche de communes** avec autocomplete
- **Filtrage par population** communale
- **Filtrage par CSP** (Catégorie Socio-Professionnelle)
- **Prévisualisation temps réel** du nombre d'abonnés
- **Import CSV** avec données géographiques françaises

### 📊 Structure CSV Supportée
```csv
email,firstname,lastname,city,state,zipcode,country,code_insee,population_commune,nom_commune,departement_numero,csp
user@example.com,Jean,Dupont,Paris,PARIS,75001,France,75101,2161000,PARIS,75,Cadres
```

### 🗺️ Interface Utilisateur
1. **Onglet "Géographie"** dans le QueryBuilder
2. **Sélection par région** → départements → communes
3. **Sliders population** min/max
4. **Sélection multiple CSP**
5. **Compteur temps réel** d'abonnés correspondants

## 🔧 Architecture Technique

### Docker Multi-Stage
```
Node.js 18 → Compilation Frontend Vue.js
     ↓
Go 1.24 → Compilation Backend + Intégration Assets
     ↓  
Alpine → Image finale optimisée
```

### Base de Données
- **PostgreSQL 17** avec extensions géographiques
- **Table subscribers** étendue (code_insee, population_commune, etc.)
- **Table departement_region_mapping** (95 départements pré-chargés)
- **Index optimisés** pour requêtes géographiques

### API Endpoints
```
GET  /api/geo/regions          # Liste des régions
GET  /api/geo/departements     # Liste des départements  
GET  /api/geo/communes         # Recherche communes
POST /api/lists/query/geo      # Requête segmentation
```

## 🛠️ Résolution de Problèmes

### Problème : Construction Docker échoue
```bash
# Nettoyer et reconstruire
docker system prune -f
docker compose -f docker-compose.simple.yml build --no-cache
```

### Problème : Base de données ne démarre pas
```bash
# Réinitialiser PostgreSQL
docker compose -f docker-compose.simple.yml down -v
docker volume rm listmonk_postgres_data
docker compose -f docker-compose.simple.yml up -d
```

### Problème : Interface inaccessible
```bash
# Vérifier les logs
docker compose -f docker-compose.simple.yml logs listmonk

# Vérifier les ports
netstat -tulpn | grep :9000
```

## 📋 Validation Rapide

### Test Automatique
```bash
./validate-installation.sh
```

### Test Manuel
```bash
# 1. Vérifier les conteneurs
docker compose -f docker-compose.simple.yml ps

# 2. Tester l'API
curl http://localhost:9000/api/geo/regions

# 3. Accéder à l'interface
open http://localhost:9000
```

## 📁 Fichiers Importants

### Configuration
- `.env` - Variables d'environnement
- `docker-compose.simple.yml` - Orchestration services
- `Dockerfile.geo.complete` - Build complet

### Scripts
- `install-listmonk-geo.sh` - Installation automatique
- `validate-docker-build.sh` - Validation environnement
- `validate-installation.sh` - Test post-installation

### Documentation
- `NOTICE_INSTALLATION_COMPLETE.md` - Guide détaillé
- `GUIDE_TEST_FINAL.md` - Tests avancés
- `SOLUTION_RAPIDE.md` - Corrections apportées

### Données
- `test_geo_data.csv` - Données de test
- `demo_geo_data.csv` - Données de démonstration
- `docker/init-scripts/01-init-geo.sql` - Extensions BDD

## 🎯 Prochaines Étapes

### 1. Personnalisation
```bash
# Modifier les identifiants admin
nano .env

# Personnaliser la configuration
cp config.toml.sample config.toml
nano config.toml
```

### 2. Import de Données
1. Préparer votre CSV avec la structure supportée
2. Aller sur http://localhost:9000/admin/subscribers/import
3. Mapper les colonnes géographiques
4. Lancer l'import

### 3. Création de Listes
1. Aller sur "Listes" → "Nouvelle liste"
2. Utiliser l'onglet "Géographie" dans QueryBuilder
3. Sélectionner régions/départements/communes
4. Définir critères population/CSP
5. Créer la liste segmentée

## 📞 Support

### Logs Utiles
```bash
# Application
docker compose -f docker-compose.simple.yml logs listmonk

# Base de données
docker compose -f docker-compose.simple.yml logs postgres

# Diagnostic complet
./scripts/docker/diagnose.sh
```

### Ressources
- **Repository :** https://github.com/code7UD/listmonk
- **Branch :** feature/french-geographic-segmentation
- **Documentation Listmonk :** https://listmonk.app/docs/

---

## 🎉 Félicitations !

Votre Listmonk avec extension géographique française est opérationnel !

**Interface Admin :** http://localhost:9000  
**Segmentation géographique :** Onglet "Géographie" dans QueryBuilder  
**Import CSV :** Support complet des données géographiques françaises