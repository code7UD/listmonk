#!/bin/bash

# Script de correction du problème de configuration Listmonk

echo "🔧 CORRECTION PROBLÈME CONFIGURATION LISTMONK"
echo "=============================================="

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

# Étape 1: Créer le fichier config.toml
print_status "Création du fichier config.toml..."
cat > config.toml << 'EOF'
[app]
address = "0.0.0.0:9000"
admin_username = "admin"
admin_password = "admin123"

[db]
host = "postgres"
port = 5432
user = "listmonk"
password = "listmonk_secure_password"
database = "listmonk"
ssl_mode = "disable"
max_open = 25
max_idle = 25
max_lifetime = "300s"

[smtp]
[[smtp.host]]
enabled = false
host = "localhost"
port = 587
auth_protocol = "plain"
username = ""
password = ""
hello_hostname = ""
max_conns = 10
idle_timeout = "15s"
wait_timeout = "5s"
max_msg_retries = 2
tls_enabled = false
tls_skip_verify = false

[upload]
provider = "filesystem"
filesystem.upload_path = "uploads"
filesystem.upload_uri = "/uploads"

[privacy]
individual_tracking = false
unsubscribe_header = true
allow_blocklist = true
allow_export = true
allow_wipe = true
exportable = ["profile", "subscriptions", "campaign_views", "link_clicks"]

[security]
enable_captcha = false

[admin]
username = "admin"
password = "admin123"
EOF

print_success "Fichier config.toml créé"

# Étape 2: Arrêter les services
print_status "Arrêt des services..."
docker compose -f docker-compose.step1.yml down 2>/dev/null || true

# Étape 3: Créer un docker-compose avec montage du config
print_status "Création de la configuration Docker avec config.toml..."
cat > docker-compose.working.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:17-alpine
    container_name: listmonk-postgres
    environment:
      POSTGRES_DB: listmonk
      POSTGRES_USER: listmonk
      POSTGRES_PASSWORD: listmonk_secure_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U listmonk -d listmonk"]
      interval: 10s
      timeout: 5s
      retries: 10
    restart: unless-stopped

  listmonk:
    build:
      context: .
      dockerfile: Dockerfile.geo.fixed
    container_name: listmonk-app
    volumes:
      - listmonk_uploads:/listmonk/uploads
      - ./config.toml:/listmonk/config.toml:ro
    ports:
      - "9000:9000"
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped

  adminer:
    image: adminer:4.8.1
    container_name: listmonk-adminer
    environment:
      ADMINER_DEFAULT_SERVER: postgres
    ports:
      - "8083:8080"
    depends_on:
      - postgres
    restart: unless-stopped

volumes:
  postgres_data:
    driver: local
  listmonk_uploads:
    driver: local
EOF

# Étape 4: Démarrer avec la nouvelle configuration
print_status "Démarrage avec config.toml..."
docker compose -f docker-compose.working.yml up -d

# Étape 5: Attendre PostgreSQL
print_status "Attente de PostgreSQL..."
sleep 15

# Étape 6: Vérifier que les extensions géographiques sont toujours là
print_status "Vérification des extensions géographiques..."
if docker compose -f docker-compose.working.yml exec -T postgres psql -U listmonk -d listmonk -c "SELECT COUNT(*) FROM departement_region_mapping;" &>/dev/null; then
    dept_count=$(docker compose -f docker-compose.working.yml exec -T postgres psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM departement_region_mapping;" | tr -d ' ')
    print_success "Extensions géographiques présentes : $dept_count départements"
else
    print_error "Extensions géographiques manquantes, réinstallation..."
    
    # Réinstaller les extensions géographiques
    cat > /tmp/geo-extensions.sql << 'EOFGEO'
-- Extensions PostgreSQL
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Ajouter les colonnes géographiques à la table subscribers existante
DO $$
BEGIN
    -- Ajouter les colonnes géographiques si elles n'existent pas
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='code_insee') THEN
        ALTER TABLE subscribers ADD COLUMN code_insee VARCHAR(10);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='population_commune') THEN
        ALTER TABLE subscribers ADD COLUMN population_commune INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='date_naissance') THEN
        ALTER TABLE subscribers ADD COLUMN date_naissance DATE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='csp') THEN
        ALTER TABLE subscribers ADD COLUMN csp VARCHAR(100);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='siren') THEN
        ALTER TABLE subscribers ADD COLUMN siren VARCHAR(20);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='siret') THEN
        ALTER TABLE subscribers ADD COLUMN siret VARCHAR(20);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='telecopie') THEN
        ALTER TABLE subscribers ADD COLUMN telecopie VARCHAR(20);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='nom_commune') THEN
        ALTER TABLE subscribers ADD COLUMN nom_commune VARCHAR(255);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='departement_numero') THEN
        ALTER TABLE subscribers ADD COLUMN departement_numero VARCHAR(3);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='phone') THEN
        ALTER TABLE subscribers ADD COLUMN phone VARCHAR(50);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='website') THEN
        ALTER TABLE subscribers ADD COLUMN website VARCHAR(255);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='address1') THEN
        ALTER TABLE subscribers ADD COLUMN address1 TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='city') THEN
        ALTER TABLE subscribers ADD COLUMN city VARCHAR(255);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='state') THEN
        ALTER TABLE subscribers ADD COLUMN state VARCHAR(255);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='zipcode') THEN
        ALTER TABLE subscribers ADD COLUMN zipcode VARCHAR(10);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='country') THEN
        ALTER TABLE subscribers ADD COLUMN country VARCHAR(100);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='title') THEN
        ALTER TABLE subscribers ADD COLUMN title VARCHAR(10);
    END IF;
END $$;

-- Créer les index pour les requêtes géographiques
CREATE INDEX IF NOT EXISTS idx_subscribers_departement ON subscribers(departement_numero);
CREATE INDEX IF NOT EXISTS idx_subscribers_code_insee ON subscribers(code_insee);
CREATE INDEX IF NOT EXISTS idx_subscribers_population ON subscribers(population_commune);
CREATE INDEX IF NOT EXISTS idx_subscribers_csp ON subscribers(csp);
CREATE INDEX IF NOT EXISTS idx_subscribers_nom_commune ON subscribers(nom_commune);
CREATE INDEX IF NOT EXISTS idx_subscribers_state ON subscribers(state);

-- Créer la table de mapping départements vers régions
CREATE TABLE IF NOT EXISTS departement_region_mapping (
    departement_numero VARCHAR(3) PRIMARY KEY,
    departement_nom VARCHAR(255) NOT NULL,
    region_nom VARCHAR(255) NOT NULL,
    region_code VARCHAR(3) NOT NULL
);

-- Insérer le mapping complet départements/régions français
INSERT INTO departement_region_mapping (departement_numero, departement_nom, region_nom, region_code) VALUES
('01', 'Ain', 'Auvergne-Rhône-Alpes', '84'),
('02', 'Aisne', 'Hauts-de-France', '32'),
('03', 'Allier', 'Auvergne-Rhône-Alpes', '84'),
('04', 'Alpes-de-Haute-Provence', 'Provence-Alpes-Côte d''Azur', '93'),
('05', 'Hautes-Alpes', 'Provence-Alpes-Côte d''Azur', '93'),
('06', 'Alpes-Maritimes', 'Provence-Alpes-Côte d''Azur', '93'),
('07', 'Ardèche', 'Auvergne-Rhône-Alpes', '84'),
('08', 'Ardennes', 'Grand Est', '44'),
('09', 'Ariège', 'Occitanie', '76'),
('10', 'Aube', 'Grand Est', '44'),
('11', 'Aude', 'Occitanie', '76'),
('12', 'Aveyron', 'Occitanie', '76'),
('13', 'Bouches-du-Rhône', 'Provence-Alpes-Côte d''Azur', '93'),
('14', 'Calvados', 'Normandie', '28'),
('15', 'Cantal', 'Auvergne-Rhône-Alpes', '84'),
('16', 'Charente', 'Nouvelle-Aquitaine', '75'),
('17', 'Charente-Maritime', 'Nouvelle-Aquitaine', '75'),
('18', 'Cher', 'Centre-Val de Loire', '24'),
('19', 'Corrèze', 'Nouvelle-Aquitaine', '75'),
('21', 'Côte-d''Or', 'Bourgogne-Franche-Comté', '27'),
('22', 'Côtes-d''Armor', 'Bretagne', '53'),
('23', 'Creuse', 'Nouvelle-Aquitaine', '75'),
('24', 'Dordogne', 'Nouvelle-Aquitaine', '75'),
('25', 'Doubs', 'Bourgogne-Franche-Comté', '27'),
('26', 'Drôme', 'Auvergne-Rhône-Alpes', '84'),
('27', 'Eure', 'Normandie', '28'),
('28', 'Eure-et-Loir', 'Centre-Val de Loire', '24'),
('29', 'Finistère', 'Bretagne', '53'),
('30', 'Gard', 'Occitanie', '76'),
('31', 'Haute-Garonne', 'Occitanie', '76'),
('32', 'Gers', 'Occitanie', '76'),
('33', 'Gironde', 'Nouvelle-Aquitaine', '75'),
('34', 'Hérault', 'Occitanie', '76'),
('35', 'Ille-et-Vilaine', 'Bretagne', '53'),
('36', 'Indre', 'Centre-Val de Loire', '24'),
('37', 'Indre-et-Loire', 'Centre-Val de Loire', '24'),
('38', 'Isère', 'Auvergne-Rhône-Alpes', '84'),
('39', 'Jura', 'Bourgogne-Franche-Comté', '27'),
('40', 'Landes', 'Nouvelle-Aquitaine', '75'),
('41', 'Loir-et-Cher', 'Centre-Val de Loire', '24'),
('42', 'Loire', 'Auvergne-Rhône-Alpes', '84'),
('43', 'Haute-Loire', 'Auvergne-Rhône-Alpes', '84'),
('44', 'Loire-Atlantique', 'Pays de la Loire', '52'),
('45', 'Loiret', 'Centre-Val de Loire', '24'),
('46', 'Lot', 'Occitanie', '76'),
('47', 'Lot-et-Garonne', 'Nouvelle-Aquitaine', '75'),
('48', 'Lozère', 'Occitanie', '76'),
('49', 'Maine-et-Loire', 'Pays de la Loire', '52'),
('50', 'Manche', 'Normandie', '28'),
('51', 'Marne', 'Grand Est', '44'),
('52', 'Haute-Marne', 'Grand Est', '44'),
('53', 'Mayenne', 'Pays de la Loire', '52'),
('54', 'Meurthe-et-Moselle', 'Grand Est', '44'),
('55', 'Meuse', 'Grand Est', '44'),
('56', 'Morbihan', 'Bretagne', '53'),
('57', 'Moselle', 'Grand Est', '44'),
('58', 'Nièvre', 'Bourgogne-Franche-Comté', '27'),
('59', 'Nord', 'Hauts-de-France', '32'),
('60', 'Oise', 'Hauts-de-France', '32'),
('61', 'Orne', 'Normandie', '28'),
('62', 'Pas-de-Calais', 'Hauts-de-France', '32'),
('63', 'Puy-de-Dôme', 'Auvergne-Rhône-Alpes', '84'),
('64', 'Pyrénées-Atlantiques', 'Nouvelle-Aquitaine', '75'),
('65', 'Hautes-Pyrénées', 'Occitanie', '76'),
('66', 'Pyrénées-Orientales', 'Occitanie', '76'),
('67', 'Bas-Rhin', 'Grand Est', '44'),
('68', 'Haut-Rhin', 'Grand Est', '44'),
('69', 'Rhône', 'Auvergne-Rhône-Alpes', '84'),
('70', 'Haute-Saône', 'Bourgogne-Franche-Comté', '27'),
('71', 'Saône-et-Loire', 'Bourgogne-Franche-Comté', '27'),
('72', 'Sarthe', 'Pays de la Loire', '52'),
('73', 'Savoie', 'Auvergne-Rhône-Alpes', '84'),
('74', 'Haute-Savoie', 'Auvergne-Rhône-Alpes', '84'),
('75', 'Paris', 'Île-de-France', '11'),
('76', 'Seine-Maritime', 'Normandie', '28'),
('77', 'Seine-et-Marne', 'Île-de-France', '11'),
('78', 'Yvelines', 'Île-de-France', '11'),
('79', 'Deux-Sèvres', 'Nouvelle-Aquitaine', '75'),
('80', 'Somme', 'Hauts-de-France', '32'),
('81', 'Tarn', 'Occitanie', '76'),
('82', 'Tarn-et-Garonne', 'Occitanie', '76'),
('83', 'Var', 'Provence-Alpes-Côte d''Azur', '93'),
('84', 'Vaucluse', 'Provence-Alpes-Côte d''Azur', '93'),
('85', 'Vendée', 'Pays de la Loire', '52'),
('86', 'Vienne', 'Nouvelle-Aquitaine', '75'),
('87', 'Haute-Vienne', 'Nouvelle-Aquitaine', '75'),
('88', 'Vosges', 'Grand Est', '44'),
('89', 'Yonne', 'Bourgogne-Franche-Comté', '27'),
('90', 'Territoire de Belfort', 'Bourgogne-Franche-Comté', '27'),
('91', 'Essonne', 'Île-de-France', '11'),
('92', 'Hauts-de-Seine', 'Île-de-France', '11'),
('93', 'Seine-Saint-Denis', 'Île-de-France', '11'),
('94', 'Val-de-Marne', 'Île-de-France', '11'),
('95', 'Val-d''Oise', 'Île-de-France', '11')
ON CONFLICT (departement_numero) DO NOTHING;

-- Index sur la table de mapping
CREATE INDEX IF NOT EXISTS idx_departement_region_mapping_region ON departement_region_mapping(region_nom);
EOFGEO

    # Exécuter le script SQL
    docker compose -f docker-compose.working.yml exec -T postgres psql -U listmonk -d listmonk -f - < /tmp/geo-extensions.sql
    rm -f /tmp/geo-extensions.sql
    
    dept_count=$(docker compose -f docker-compose.working.yml exec -T postgres psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM departement_region_mapping;" | tr -d ' ')
    print_success "Extensions géographiques réinstallées : $dept_count départements"
fi

# Étape 7: Attendre que Listmonk démarre
print_status "Attente de Listmonk..."
sleep 20

# Étape 8: Vérifier l'accès
print_status "Vérification de l'accès..."
if curl -f http://localhost:9000 &>/dev/null; then
    print_success "Listmonk est accessible !"
else
    print_status "Listmonk démarre encore... (peut prendre quelques minutes)"
fi

echo ""
echo "🎉 CORRECTION TERMINÉE !"
echo "======================="
echo ""
print_success "Configuration corrigée avec config.toml"
echo ""
echo "📋 INFORMATIONS D'ACCÈS :"
echo "-------------------------"
echo "🌐 Interface Listmonk : http://localhost:9000"
echo "👤 Nom d'utilisateur  : admin"
echo "🔑 Mot de passe       : admin123"
echo ""
echo "🗄️ Interface Adminer : http://localhost:8083"
echo "   Serveur: postgres"
echo "   Utilisateur: listmonk"
echo "   Mot de passe: listmonk_secure_password"
echo ""
echo "🔧 COMMANDES UTILES :"
echo "--------------------"
echo "# Voir les logs Listmonk"
echo "docker compose -f docker-compose.working.yml logs -f listmonk"
echo ""
echo "# Redémarrer Listmonk"
echo "docker compose -f docker-compose.working.yml restart listmonk"
echo ""
echo "# Statut des services"
echo "docker compose -f docker-compose.working.yml ps"
echo ""
echo "🎯 Si Listmonk n'est pas encore accessible, attendez 2-3 minutes"
echo "   puis vérifiez http://localhost:9000"
echo ""