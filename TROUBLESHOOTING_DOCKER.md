# 🔧 Dépannage Docker - Extension Géographique Listmonk

## ❌ Problèmes Courants et Solutions

### 1. Erreur "go.mod requires go >= 1.24.1"

**Symptôme :**
```
go: go.mod requires go >= 1.24.1 (running go 1.21.13; GOTOOLCHAIN=local)
ERROR: Service 'listmonk' failed to build : Build failed
```

**Cause :** Le Dockerfile utilise une version Go trop ancienne.

**Solution Rapide :**
```bash
# Exécuter le script de correction
./fix-docker-go-version.sh
```

**Solution Manuelle :**
```bash
# 1. Corriger la version Go dans Dockerfile.geo
sed -i 's/golang:1.21-alpine/golang:1.24-alpine/g' Dockerfile.geo

# 2. Nettoyer et reconstruire
docker-compose -f docker-compose.geo.yml down
docker system prune -f
docker-compose -f docker-compose.geo.yml build --no-cache
docker-compose -f docker-compose.geo.yml up -d
```

### 1.1. Erreur de Build Frontend (ESLint)

**Symptôme :**
```
Error: Cannot read .eslintignore file: /src/frontend/.gitignore
Error: ENOENT: no such file or directory, open '/src/frontend/.gitignore'
```

**Cause :** Problèmes avec la configuration ESLint du frontend.

**Solution Rapide :**
```bash
# Utiliser la version simplifiée sans build frontend
./start-geo-simple.sh
```

**Solution Alternative :**
```bash
# Corriger les problèmes de frontend
./fix-frontend-build.sh
```

**Solution Manuelle :**
```bash
# Utiliser le docker-compose simplifié
docker-compose -f docker-compose.simple.yml build --no-cache
docker-compose -f docker-compose.simple.yml up -d
```

### 2. Ports Déjà Utilisés

**Symptôme :**
```
ERROR: for listmonk-postgres-geo  Cannot start service postgres: driver failed programming external connectivity on endpoint listmonk-postgres-geo: Bind for 0.0.0.0:5432 failed: port is already allocated
```

**Solution :**
```bash
# Vérifier les ports utilisés
netstat -tulpn | grep -E ':(9000|5432|8080)'

# Option 1: Arrêter les services conflictuels
sudo systemctl stop postgresql
sudo systemctl stop apache2
sudo systemctl stop nginx

# Option 2: Modifier les ports dans docker-compose.geo.yml
# Changer "5432:5432" en "5433:5432" par exemple
```

### 3. Erreur de Permissions

**Symptôme :**
```
permission denied: ./start-geo.sh
```

**Solution :**
```bash
# Rendre les scripts exécutables
chmod +x start-geo.sh
chmod +x fix-docker-go-version.sh
chmod +x test-docker-geo.sh
chmod +x docker/entrypoint.sh
chmod +x docker/scripts/*.sh
```

### 4. Services ne Démarrent Pas

**Symptôme :**
```
listmonk-app-geo exited with code 1
```

**Diagnostic :**
```bash
# Vérifier les logs
docker-compose -f docker-compose.geo.yml logs

# Vérifier l'état des services
docker-compose -f docker-compose.geo.yml ps

# Vérifier les ressources système
docker system df
free -h
```

**Solution :**
```bash
# Nettoyer et redémarrer
docker-compose -f docker-compose.geo.yml down -v
docker system prune -f
./start-geo.sh
```

### 5. Base de Données Non Accessible

**Symptôme :**
```
connection to server at "postgres" (172.x.x.x), port 5432 failed
```

**Solution :**
```bash
# Vérifier PostgreSQL
docker-compose -f docker-compose.geo.yml exec postgres pg_isready -U listmonk

# Redémarrer PostgreSQL
docker-compose -f docker-compose.geo.yml restart postgres

# Vérifier les logs PostgreSQL
docker-compose -f docker-compose.geo.yml logs postgres
```

### 6. Interface Web Non Accessible

**Symptôme :**
```
curl: (7) Failed to connect to localhost port 9000: Connection refused
```

**Diagnostic :**
```bash
# Vérifier que Listmonk fonctionne
docker-compose -f docker-compose.geo.yml exec listmonk ps aux

# Vérifier les logs Listmonk
docker-compose -f docker-compose.geo.yml logs listmonk

# Tester depuis le container
docker-compose -f docker-compose.geo.yml exec listmonk wget -qO- http://localhost:9000/health
```

### 7. Import CSV Échoue

**Symptôme :**
```
Error importing CSV: invalid character encoding
```

**Solution :**
```bash
# Vérifier l'encodage du fichier
file -i votre_fichier.csv

# Convertir en UTF-8 si nécessaire
iconv -f ISO-8859-1 -t UTF-8 votre_fichier.csv > votre_fichier_utf8.csv

# Vérifier la structure CSV
head -5 votre_fichier.csv
```

### 8. Erreur de Migration

**Symptôme :**
```
migration failed: relation "departement_region_mapping" already exists
```

**Solution :**
```bash
# Réinitialiser la base de données
docker-compose -f docker-compose.geo.yml down -v
docker-compose -f docker-compose.geo.yml up -d

# Ou forcer la migration
docker-compose -f docker-compose.geo.yml exec postgres psql -U listmonk -d listmonk -c "
DROP TABLE IF EXISTS departement_region_mapping CASCADE;
"
docker-compose -f docker-compose.geo.yml restart listmonk
```

## 🔍 Commandes de Diagnostic

### Vérification Complète
```bash
# Test automatique complet
./test-docker-geo.sh
```

### État des Services
```bash
# État des containers
docker-compose -f docker-compose.geo.yml ps

# Utilisation des ressources
docker stats listmonk-app-geo listmonk-postgres-geo

# Logs en temps réel
docker-compose -f docker-compose.geo.yml logs -f
```

### Base de Données
```bash
# Connexion à PostgreSQL
docker-compose -f docker-compose.geo.yml exec postgres psql -U listmonk -d listmonk

# Vérifier les tables géographiques
docker-compose -f docker-compose.geo.yml exec postgres psql -U listmonk -d listmonk -c "
SELECT COUNT(*) FROM departement_region_mapping;
SELECT COUNT(*) FROM subscribers WHERE code_insee IS NOT NULL;
"
```

### Réseau
```bash
# Vérifier la connectivité réseau
docker network ls
docker network inspect listmonk-geo_listmonk-network

# Test de connectivité interne
docker-compose -f docker-compose.geo.yml exec listmonk ping postgres
```

## 🚨 Réinitialisation Complète

Si tous les dépannages échouent :

```bash
# 1. Arrêter tous les services
docker-compose -f docker-compose.geo.yml down -v

# 2. Nettoyer Docker
docker system prune -a -f
docker volume prune -f

# 3. Supprimer les données locales
rm -rf data/

# 4. Redémarrer depuis zéro
./start-geo.sh
```

## 📞 Support

### Informations à Fournir
Lors d'une demande de support, incluez :

```bash
# Version Docker
docker --version
docker-compose --version

# État des services
docker-compose -f docker-compose.geo.yml ps

# Logs récents
docker-compose -f docker-compose.geo.yml logs --tail=50

# Configuration système
uname -a
free -h
df -h
```

### Logs Utiles
```bash
# Sauvegarder les logs pour analyse
docker-compose -f docker-compose.geo.yml logs > debug_logs_$(date +%Y%m%d_%H%M%S).txt

# Exporter la configuration
docker-compose -f docker-compose.geo.yml config > config_export.yml
```

## ✅ Vérifications Post-Installation

Après résolution d'un problème :

```bash
# 1. Test de connectivité
curl http://localhost:9000/health

# 2. Test de la base de données
docker-compose -f docker-compose.geo.yml exec postgres psql -U listmonk -d listmonk -c "SELECT 1;"

# 3. Test des fonctionnalités géographiques
docker-compose -f docker-compose.geo.yml exec postgres psql -U listmonk -d listmonk -f /listmonk/demo/demo_geographic_queries.sql

# 4. Test complet
./test-docker-geo.sh
```

---

**💡 Conseil :** Gardez toujours une sauvegarde de vos données avant de faire des modifications importantes !