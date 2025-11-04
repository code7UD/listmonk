# 🐳 NOTICE D'INSTALLATION DOCKER - Listmonk Extension Géographique

## 🎯 OBJECTIF

Cette notice vous guide pour installer **Listmonk avec l'extension géographique française** en utilisant Docker. La solution est **complètement testée et validée** avec corrections ESLint et build multi-stage fonctionnel.

## 📦 Prérequis

### Système
- **Docker** 20.10+ installé et fonctionnel
- **Docker Compose** 2.0+ installé
- **2GB d'espace disque** minimum
- **Ports disponibles** : 5432, 8080, 9000 (gestion automatique des conflits)

### Vérification Rapide
```bash
docker --version && docker-compose --version
docker info  # Vérifier que Docker fonctionne
```

## 🚀 Installation Automatique

### Étape 1: Cloner le Repository
```bash
git clone https://github.com/code7UD/listmonk.git
cd listmonk
git checkout feature/french-geographic-segmentation
```

### Étape 2: Installation Complète
```bash
# Installation automatique avec gestion d'erreurs
./install-listmonk-geo.sh
```

### Étape 3: Validation
```bash
# Vérifier que tout fonctionne
./scripts/docker/validate-installation.sh
```

## 🔧 Options d'Installation

### Installation Standard
```bash
./install-listmonk-geo.sh
```

### Installation avec Nettoyage Préalable
```bash
./install-listmonk-geo.sh --clean
```

### Installation Silencieuse
```bash
./install-listmonk-geo.sh --quiet
```

## 📊 Architecture Déployée

### Services Docker
```yaml
Services déployés:
├── listmonk-postgres-geo    # PostgreSQL 17 avec extensions géographiques
├── listmonk-adminer-geo     # Interface d'administration base de données
└── listmonk                 # Application Listmonk avec extension géographique
```

### Volumes Persistants
```yaml
Volumes:
├── postgres_data            # Données PostgreSQL persistantes
└── uploads_data            # Fichiers uploadés Listmonk
```

### Réseau
```yaml
Réseau: listmonk-network (bridge)
```

## 🌐 Accès aux Services

### URLs par Défaut
- **Listmonk** : http://localhost:9000
- **Adminer** : http://localhost:8080
- **PostgreSQL** : localhost:5432

### Gestion des Conflits de Ports
Le script détecte automatiquement les ports occupés et utilise des alternatives :
- Listmonk : 9000 → 9001 → 9002
- Adminer : 8080 → 8081 → 8082
- PostgreSQL : 5432 → 5433 → 5434

### Identifiants par Défaut
```
Utilisateur : admin
Mot de passe : admin123!
```

## 🗺️ Extension Géographique

### Données Pré-chargées
- **95 départements français** avec mapping régions
- **13 régions françaises** 
- **Extensions PostgreSQL** : uuid-ossp, pg_trgm
- **Index optimisés** pour recherches géographiques

### Fonctionnalités Disponibles
- ✅ Segmentation par région française
- ✅ Segmentation par département
- ✅ Segmentation par commune (autocomplete)
- ✅ Filtrage par population communale
- ✅ Filtrage par CSP (catégorie socio-professionnelle)
- ✅ Combinaison de critères multiples
- ✅ Prévisualisation temps réel du nombre d'abonnés

## 📁 Structure des Fichiers

### Fichiers de Configuration
```
listmonk/
├── docker-compose.simple.yml       # Configuration Docker principale
├── Dockerfile.geo.simple          # Image Listmonk avec extension
├── .env.example                   # Variables d'environnement
└── install-listmonk-geo.sh       # Script d'installation principal
```

### Scripts Utilitaires
```
scripts/docker/
├── diagnose.sh                    # Diagnostic complet système
├── fix-postgres-version.sh       # Résolution problèmes PostgreSQL
└── validate-installation.sh      # Validation post-installation
```

### Configuration PostgreSQL
```
docker/
├── init-scripts/01-init-geo.sql  # Initialisation base géographique
└── entrypoint.sh                 # Point d'entrée avec configuration dynamique
```

### Données de Démonstration
```
demo_geo_data.csv                 # Données CSV d'exemple
demo_geographic_queries.sql       # Requêtes de test
test_geo_data.csv                # Données de test
```

## 🔍 Diagnostic et Dépannage

### Diagnostic Automatique
```bash
# Analyse complète de l'environnement
./scripts/docker/diagnose.sh
```

### Problèmes Courants et Solutions

#### 1. Erreur de Version PostgreSQL
```bash
# Solution automatique
./scripts/docker/fix-postgres-version.sh
```

#### 2. Ports Occupés
```bash
# Le script gère automatiquement les conflits
# Ou forcer des ports spécifiques :
LISTMONK_PORT=9001 ADMINER_PORT=8081 ./install-listmonk-geo.sh
```

#### 3. Problèmes de Permissions Docker
```bash
# Ajouter l'utilisateur au groupe docker
sudo usermod -aG docker $USER
# Puis redémarrer la session
```

#### 4. Espace Disque Insuffisant
```bash
# Nettoyer Docker
docker system prune -af
docker volume prune -f
```

### Logs Détaillés
```bash
# Logs en temps réel
docker-compose -f docker-compose.simple.yml logs -f

# Logs par service
docker-compose logs postgres    # PostgreSQL
docker-compose logs listmonk    # Listmonk
docker-compose logs adminer     # Adminer
```

## 📋 Validation de l'Installation

### Tests Automatiques
```bash
# Validation complète
./scripts/docker/validate-installation.sh
```

### Tests Manuels

#### 1. Vérifier PostgreSQL
```bash
docker exec -it listmonk-postgres-geo psql -U listmonk -d listmonk -c "SELECT COUNT(*) FROM departement_region_mapping;"
# Doit retourner : 95
```

#### 2. Vérifier Listmonk
```bash
curl -f http://localhost:9000/health
# Doit retourner : HTTP 200
```

#### 3. Vérifier l'Interface Géographique
1. Accéder à http://localhost:9000
2. Se connecter (admin/admin123!)
3. Aller dans "Listes" → "Créer une liste"
4. Vérifier l'onglet "Géographie"
5. Tester les dropdowns régions/départements

## 🔄 Gestion des Mises à Jour

### Mise à Jour de l'Extension
```bash
# Récupérer les dernières modifications
git pull origin feature/french-geographic-segmentation

# Reconstruire et redéployer
./install-listmonk-geo.sh --clean && ./install-listmonk-geo.sh
```

### Sauvegarde des Données
```bash
# Sauvegarde PostgreSQL
docker exec listmonk-postgres-geo pg_dump -U listmonk listmonk > backup.sql

# Sauvegarde volumes
docker run --rm -v listmonk_postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres_backup.tar.gz /data
```

### Restauration
```bash
# Restaurer PostgreSQL
docker exec -i listmonk-postgres-geo psql -U listmonk listmonk < backup.sql
```

## 🛡️ Sécurité

### Recommandations de Production
1. **Changer les mots de passe par défaut**
2. **Utiliser HTTPS** avec un reverse proxy
3. **Restreindre l'accès réseau** aux ports nécessaires
4. **Activer les sauvegardes automatiques**
5. **Surveiller les logs** pour détecter les anomalies

### Configuration Sécurisée
```bash
# Créer un fichier .env personnalisé
cp .env.example .env
# Éditer .env avec des mots de passe forts
```

## 📞 Support et Ressources

### Documentation
- **Guide de test** : `GUIDE_TEST_FINAL.md`
- **Solutions rapides** : `SOLUTION_RAPIDE.md`
- **Documentation Listmonk** : https://listmonk.app/docs/

### Scripts d'Aide
```bash
./scripts/docker/diagnose.sh              # Diagnostic complet
./scripts/docker/fix-postgres-version.sh  # Fix PostgreSQL
./scripts/docker/validate-installation.sh # Validation
```

### Commandes Utiles
```bash
# État des services
docker-compose ps

# Redémarrage complet
docker-compose restart

# Nettoyage et réinstallation
./install-listmonk-geo.sh --clean && ./install-listmonk-geo.sh
```

## ✅ Checklist de Validation

- [ ] Docker et Docker Compose installés
- [ ] Repository cloné sur la bonne branche
- [ ] Installation exécutée sans erreur
- [ ] PostgreSQL 17 démarré avec 95 départements
- [ ] Listmonk accessible sur http://localhost:9000
- [ ] Connexion réussie avec admin/admin123!
- [ ] Onglet "Géographie" visible dans création de listes
- [ ] Dropdowns régions/départements fonctionnels
- [ ] Import CSV avec données géographiques testé

---

**🎉 Installation terminée ! Votre instance Listmonk avec extension géographique française est prête à l'emploi.**