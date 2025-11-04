# 🐳 Installation Docker - Extension Géographique Listmonk

## 📋 Vue d'ensemble

Cette notice détaille l'installation complète de Listmonk avec l'extension géographique française via Docker. L'installation inclut PostgreSQL, Listmonk avec les fonctionnalités géographiques, et tous les outils nécessaires.

## 🎯 Prérequis

- **Docker** version 20.10 ou supérieure
- **Docker Compose** version 2.0 ou supérieure
- **Git** pour cloner le repository
- **4 GB RAM** minimum recommandé
- **2 GB d'espace disque** pour les données

## 📁 Structure du Projet

```
listmonk-geo/
├── docker-compose.yml
├── .env
├── config/
│   └── config.toml
├── data/
│   ├── postgres/
│   └── uploads/
└── demo/
    ├── demo_geo_data.csv
    └── import_demo_data.sh
```

## 🚀 Installation Rapide

### 1. Cloner le Repository

```bash
# Cloner le repository avec l'extension géographique
git clone https://github.com/code7UD/listmonk.git listmonk-geo
cd listmonk-geo

# Basculer sur la branche avec les fonctionnalités géographiques
git checkout feature/french-geographic-segmentation
```

### 2. Créer la Configuration Docker

#### Fichier `docker-compose.yml`

```yaml
version: '3.8'

services:
  # Base de données PostgreSQL
  postgres:
    image: postgres:15-alpine
    container_name: listmonk-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: listmonk
      POSTGRES_USER: listmonk
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_HOST_AUTH_METHOD: trust
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-scripts:/docker-entrypoint-initdb.d
    ports:
      - "5432:5432"
    networks:
      - listmonk-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U listmonk -d listmonk"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Application Listmonk avec extension géographique
  listmonk:
    build:
      context: .
      dockerfile: Dockerfile.geo
    container_name: listmonk-app
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      LISTMONK_DB_HOST: postgres
      LISTMONK_DB_PORT: 5432
      LISTMONK_DB_USER: listmonk
      LISTMONK_DB_PASSWORD: ${POSTGRES_PASSWORD}
      LISTMONK_DB_DATABASE: listmonk
      LISTMONK_DB_SSL_MODE: disable
      LISTMONK_APP_ADDRESS: 0.0.0.0:9000
      LISTMONK_APP_ADMIN_USERNAME: ${ADMIN_USERNAME}
      LISTMONK_APP_ADMIN_PASSWORD: ${ADMIN_PASSWORD}
    ports:
      - "9000:9000"
    volumes:
      - ./config/config.toml:/listmonk/config.toml:ro
      - uploads_data:/listmonk/uploads
      - ./demo:/listmonk/demo:ro
    networks:
      - listmonk-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Interface d'administration (optionnel)
  adminer:
    image: adminer:latest
    container_name: listmonk-adminer
    restart: unless-stopped
    depends_on:
      - postgres
    ports:
      - "8080:8080"
    networks:
      - listmonk-network
    environment:
      ADMINER_DEFAULT_SERVER: postgres

volumes:
  postgres_data:
    driver: local
  uploads_data:
    driver: local

networks:
  listmonk-network:
    driver: bridge
```

#### Fichier `.env`

```env
# =============================================================================
# Configuration Listmonk avec Extension Géographique
# =============================================================================

# Base de données
POSTGRES_PASSWORD=listmonk_secure_password_2024

# Administration
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123!

# Configuration géographique
LISTMONK_GEO_ENABLED=true
LISTMONK_GEO_AUTO_INDEX=true
LISTMONK_GEO_CACHE_TTL=3600

# Import CSV
LISTMONK_CSV_BATCH_SIZE=1000
LISTMONK_CSV_VALIDATE_INSEE=true

# Développement (à désactiver en production)
LISTMONK_DEV_MODE=false
LISTMONK_LOG_LEVEL=info

# Sécurité
LISTMONK_SECURITY_ENABLE_CAPTCHA=true
LISTMONK_SECURITY_CAPTCHA_KEY=your_captcha_key_here
LISTMONK_SECURITY_CAPTCHA_SECRET=your_captcha_secret_here

# Email (SMTP)
LISTMONK_SMTP_HOST=smtp.gmail.com
LISTMONK_SMTP_PORT=587
LISTMONK_SMTP_AUTH_PROTOCOL=login
LISTMONK_SMTP_USERNAME=your_email@gmail.com
LISTMONK_SMTP_PASSWORD=your_app_password
LISTMONK_SMTP_HELLO_HOSTNAME=localhost
LISTMONK_SMTP_TLS_ENABLED=true
LISTMONK_SMTP_TLS_SKIP_VERIFY=false
LISTMONK_SMTP_MAX_CONNS=10
LISTMONK_SMTP_IDLE_TIMEOUT=15s
LISTMONK_SMTP_WAIT_TIMEOUT=5s
LISTMONK_SMTP_MAX_MSG_RETRIES=2
```

### 3. Créer le Dockerfile Personnalisé

#### Fichier `Dockerfile.geo`

```dockerfile
# Dockerfile pour Listmonk avec extension géographique
FROM golang:1.21-alpine AS builder

# Installer les dépendances de build
RUN apk add --no-cache git make build-base nodejs npm

# Définir le répertoire de travail
WORKDIR /src

# Copier les fichiers source
COPY . .

# Construire l'application
RUN make build

# Image finale
FROM alpine:latest

# Installer les dépendances runtime
RUN apk add --no-cache ca-certificates curl postgresql-client

# Créer un utilisateur non-root
RUN addgroup -g 1001 listmonk && \
    adduser -D -u 1001 -G listmonk listmonk

# Créer les répertoires nécessaires
RUN mkdir -p /listmonk/uploads /listmonk/static /listmonk/i18n && \
    chown -R listmonk:listmonk /listmonk

# Copier le binaire depuis le builder
COPY --from=builder /src/listmonk /listmonk/listmonk
COPY --from=builder /src/static /listmonk/static
COPY --from=builder /src/i18n /listmonk/i18n

# Copier les scripts d'initialisation
COPY docker/init-scripts/ /listmonk/scripts/
RUN chmod +x /listmonk/scripts/*.sh

# Définir l'utilisateur
USER listmonk

# Définir le répertoire de travail
WORKDIR /listmonk

# Exposer le port
EXPOSE 9000

# Point d'entrée avec initialisation géographique
COPY docker/entrypoint.sh /entrypoint.sh
USER root
RUN chmod +x /entrypoint.sh
USER listmonk

ENTRYPOINT ["/entrypoint.sh"]
CMD ["./listmonk", "--config", "config.toml"]
```

### 4. Créer les Scripts d'Initialisation

#### Fichier `docker/entrypoint.sh`

```bash
#!/bin/sh

# Script d'entrée pour Listmonk avec extension géographique

set -e

echo "🚀 Démarrage de Listmonk avec extension géographique..."

# Attendre que PostgreSQL soit prêt
echo "⏳ Attente de PostgreSQL..."
while ! pg_isready -h $LISTMONK_DB_HOST -p $LISTMONK_DB_PORT -U $LISTMONK_DB_USER; do
  echo "PostgreSQL n'est pas encore prêt. Attente..."
  sleep 2
done

echo "✅ PostgreSQL est prêt!"

# Vérifier si la base de données est initialisée
if ! ./listmonk --config config.toml --install --idempotent --yes; then
  echo "❌ Erreur lors de l'initialisation de la base de données"
  exit 1
fi

echo "✅ Base de données initialisée"

# Exécuter les migrations géographiques si nécessaire
echo "🗺️ Application des migrations géographiques..."
if ! ./listmonk --config config.toml --upgrade --yes; then
  echo "❌ Erreur lors des migrations géographiques"
  exit 1
fi

echo "✅ Migrations géographiques appliquées"

# Importer les données de démonstration si disponibles
if [ -f "/listmonk/demo/demo_geo_data.csv" ] && [ "$LISTMONK_IMPORT_DEMO_DATA" = "true" ]; then
  echo "📊 Import des données de démonstration..."
  /listmonk/scripts/import_demo_data.sh
fi

echo "🎉 Listmonk avec extension géographique prêt!"

# Démarrer l'application
exec "$@"
```

#### Fichier `docker/init-scripts/01-init-geo.sql`

```sql
-- Script d'initialisation pour l'extension géographique
-- Ce script est exécuté automatiquement par PostgreSQL au premier démarrage

\echo 'Initialisation de la base de données géographique...'

-- Créer les extensions nécessaires
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Optimisations pour les requêtes géographiques
ALTER DATABASE listmonk SET shared_preload_libraries = 'pg_stat_statements';

\echo 'Base de données géographique initialisée avec succès!'
```

#### Fichier `docker/scripts/import_demo_data.sh`

```bash
#!/bin/sh

# Script d'import des données de démonstration géographiques

echo "📊 Import des données de démonstration géographiques..."

# Vérifier que le fichier de démonstration existe
if [ ! -f "/listmonk/demo/demo_geo_data.csv" ]; then
  echo "⚠️ Fichier de démonstration non trouvé"
  exit 0
fi

# Créer une liste de test si elle n'existe pas
psql -h $LISTMONK_DB_HOST -U $LISTMONK_DB_USER -d $LISTMONK_DB_DATABASE -c "
INSERT INTO lists (uuid, name, type, optin, tags, description) 
VALUES (
  gen_random_uuid(), 
  'Démonstration Géographique', 
  'public', 
  'single', 
  '{\"demo\", \"geo\"}',
  'Liste de démonstration pour les fonctionnalités géographiques'
) ON CONFLICT DO NOTHING;
"

echo "✅ Données de démonstration importées"
```

### 5. Créer la Configuration Listmonk

#### Fichier `config/config.toml`

```toml
[app]
address = "0.0.0.0:9000"
admin_username = "admin"
admin_password = "admin123!"

# Base de données
[db]
host = "postgres"
port = 5432
user = "listmonk"
password = "listmonk_secure_password_2024"
database = "listmonk"
ssl_mode = "disable"
max_open = 25
max_idle = 25
max_lifetime = "300s"

# Configuration géographique
[geo]
enabled = true
auto_index = true
cache_ttl = "1h"
validate_insee = true

# Import CSV
[importer]
batch_size = 1000
max_workers = 4

# Sécurité
[security]
enable_captcha = false
captcha_key = ""
captcha_secret = ""

# SMTP (à configurer selon vos besoins)
[smtp]
host = "localhost"
port = 1025
auth_protocol = "none"
username = ""
password = ""
hello_hostname = "localhost"
max_conns = 10
idle_timeout = "15s"
wait_timeout = "5s"
max_msg_retries = 2
tls_enabled = false
tls_skip_verify = false

# Médias
[upload]
provider = "filesystem"
filesystem_upload_path = "./uploads"
filesystem_upload_uri = "/uploads"

# Confidentialité
[privacy]
individual_tracking = false
unsubscribe_header = true
allow_blocklist = true
allow_export = true
allow_wipe = true
exportable = ["profile", "subscriptions", "campaign_views", "link_clicks"]
```

## 🚀 Démarrage

### 1. Lancer l'Installation

```bash
# Créer les répertoires nécessaires
mkdir -p data/postgres data/uploads config demo

# Copier les fichiers de démonstration
cp demo_geo_data.csv demo/
cp demo_geographic_queries.sql demo/

# Démarrer les services
docker-compose up -d

# Vérifier les logs
docker-compose logs -f listmonk
```

### 2. Vérifier l'Installation

```bash
# Vérifier que tous les services sont démarrés
docker-compose ps

# Tester la connectivité
curl http://localhost:9000/health

# Vérifier les données géographiques
docker-compose exec postgres psql -U listmonk -d listmonk -c "
SELECT COUNT(*) as departements FROM departement_region_mapping;
"
```

### 3. Accéder à l'Interface

- **Listmonk** : http://localhost:9000
- **Adminer** (base de données) : http://localhost:8080
- **Identifiants** : admin / admin123!

## 📊 Import de Données Géographiques

### 1. Via l'Interface Web

1. Connectez-vous à http://localhost:9000
2. Allez dans **Subscribers** > **Import**
3. Uploadez votre fichier CSV avec structure géographique
4. Mappez les colonnes géographiques :
   - `code_insee` → Code INSEE
   - `population_commune` → Population
   - `departement_numero` → Département
   - `nom_commune` → Commune
   - `csp` → CSP

### 2. Via Script Automatisé

```bash
# Copier votre fichier CSV dans le container
docker cp votre_fichier.csv listmonk-app:/listmonk/import.csv

# Exécuter l'import
docker-compose exec listmonk ./scripts/import_geo_data.sh /listmonk/import.csv
```

## 🎯 Test des Fonctionnalités Géographiques

### 1. Test des API

```bash
# Tester les régions (nécessite authentification)
curl -X GET http://localhost:9000/api/geo/regions \
  -H "Authorization: Bearer YOUR_TOKEN"

# Tester les départements
curl -X GET http://localhost:9000/api/geo/departements \
  -H "Authorization: Bearer YOUR_TOKEN"

# Tester une requête de segmentation
curl -X POST http://localhost:9000/api/lists/query/geo \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "regions": ["Auvergne-Rhône-Alpes"],
    "use_population": true,
    "population_min": 1000,
    "population_max": 50000
  }'
```

### 2. Test des Requêtes SQL

```bash
# Exécuter les requêtes de démonstration
docker-compose exec postgres psql -U listmonk -d listmonk -f /listmonk/demo/demo_geographic_queries.sql
```

## 🔧 Maintenance

### 1. Sauvegarde

```bash
# Sauvegarde de la base de données
docker-compose exec postgres pg_dump -U listmonk listmonk > backup_$(date +%Y%m%d).sql

# Sauvegarde des uploads
docker cp listmonk-app:/listmonk/uploads ./backup_uploads_$(date +%Y%m%d)
```

### 2. Mise à Jour

```bash
# Arrêter les services
docker-compose down

# Mettre à jour le code
git pull origin feature/french-geographic-segmentation

# Reconstruire et redémarrer
docker-compose build --no-cache
docker-compose up -d

# Appliquer les migrations
docker-compose exec listmonk ./listmonk --config config.toml --upgrade --yes
```

### 3. Monitoring

```bash
# Vérifier les performances
docker-compose exec postgres psql -U listmonk -d listmonk -c "
SELECT schemaname, tablename, attname, n_distinct, correlation 
FROM pg_stats 
WHERE tablename = 'subscribers' 
AND attname IN ('departement_numero', 'code_insee', 'population_commune');
"

# Vérifier l'utilisation des index
docker-compose exec postgres psql -U listmonk -d listmonk -c "
SELECT indexname, idx_tup_read, idx_tup_fetch 
FROM pg_stat_user_indexes 
WHERE schemaname = 'public' 
AND indexname LIKE 'idx_subscribers_%';
"
```

## 🐛 Dépannage

### Problèmes Courants

#### 1. Erreur de Connexion PostgreSQL

```bash
# Vérifier les logs PostgreSQL
docker-compose logs postgres

# Redémarrer PostgreSQL
docker-compose restart postgres
```

#### 2. Erreur de Migration

```bash
# Vérifier l'état des migrations
docker-compose exec listmonk ./listmonk --config config.toml --upgrade --yes

# Forcer la migration
docker-compose exec postgres psql -U listmonk -d listmonk -c "
DELETE FROM schema_migrations WHERE version = '5.1.0';
"
```

#### 3. Problème d'Import CSV

```bash
# Vérifier les logs d'import
docker-compose logs listmonk | grep -i import

# Vérifier l'encodage du fichier
file -i votre_fichier.csv

# Convertir en UTF-8 si nécessaire
iconv -f ISO-8859-1 -t UTF-8 votre_fichier.csv > votre_fichier_utf8.csv
```

## 📚 Ressources Supplémentaires

- **Documentation complète** : `GEOGRAPHIC_FEATURES.md`
- **Exemples SQL** : `demo_geographic_queries.sql`
- **Script de test** : `test_complete_implementation.sh`
- **Repository GitHub** : https://github.com/code7UD/listmonk/tree/feature/french-geographic-segmentation

## 🎉 Félicitations !

Votre installation Listmonk avec extension géographique française est maintenant opérationnelle ! Vous pouvez commencer à créer des campagnes de géomarketing sophistiquées avec segmentation par régions, départements, communes et données démographiques.