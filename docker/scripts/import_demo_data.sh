#!/bin/sh

# Script d'import des données de démonstration géographiques

echo "📊 Import des données de démonstration géographiques..."

# Vérifier que le fichier de démonstration existe
if [ ! -f "/listmonk/demo/demo_geo_data.csv" ]; then
  echo "⚠️ Fichier de démonstration non trouvé"
  exit 0
fi

# Attendre que la base soit prête
sleep 5

# Créer une liste de test si elle n'existe pas
echo "📝 Création de la liste de démonstration..."
PGPASSWORD=$LISTMONK_DB_PASSWORD psql -h $LISTMONK_DB_HOST -U $LISTMONK_DB_USER -d $LISTMONK_DB_DATABASE -c "
INSERT INTO lists (uuid, name, type, optin, tags, description) 
VALUES (
  gen_random_uuid(), 
  'Démonstration Géographique', 
  'public', 
  'single', 
  '{\"demo\", \"geo\"}',
  'Liste de démonstration pour les fonctionnalités géographiques'
) ON CONFLICT DO NOTHING;
" 2>/dev/null

# Insérer quelques abonnés de démonstration directement
echo "👥 Insertion d'abonnés de démonstration..."
PGPASSWORD=$LISTMONK_DB_PASSWORD psql -h $LISTMONK_DB_HOST -U $LISTMONK_DB_USER -d $LISTMONK_DB_DATABASE -c "
INSERT INTO subscribers (uuid, email, name, status, code_insee, population_commune, nom_commune, departement_numero, state, csp) VALUES 
(gen_random_uuid(), 'demo.paris@example.com', 'Démo Paris', 'enabled', '75101', 50000, 'PARIS 1ER ARRONDISSEMENT', '75', 'PARIS', 'Cadres et professions intellectuelles supérieures'),
(gen_random_uuid(), 'demo.lyon@example.com', 'Démo Lyon', 'enabled', '69381', 120000, 'LYON 1ER ARRONDISSEMENT', '69', 'RHÔNE', 'Professions intermédiaires'),
(gen_random_uuid(), 'demo.marseille@example.com', 'Démo Marseille', 'enabled', '13201', 150000, 'MARSEILLE 1ER ARRONDISSEMENT', '13', 'BOUCHES-DU-RHÔNE', 'Employés'),
(gen_random_uuid(), 'demo.toulouse@example.com', 'Démo Toulouse', 'enabled', '31555', 80000, 'TOULOUSE', '31', 'HAUTE-GARONNE', 'Artisans commerçants et chefs d''entreprise'),
(gen_random_uuid(), 'demo.nantes@example.com', 'Démo Nantes', 'enabled', '44109', 60000, 'NANTES', '44', 'LOIRE-ATLANTIQUE', 'Cadres et professions intellectuelles supérieures')
ON CONFLICT (email) DO NOTHING;
" 2>/dev/null

if [ $? -eq 0 ]; then
  echo "✅ Données de démonstration importées avec succès"
else
  echo "⚠️ Erreur lors de l'import des données de démonstration"
fi

echo "📈 Statistiques des données importées:"
PGPASSWORD=$LISTMONK_DB_PASSWORD psql -h $LISTMONK_DB_HOST -U $LISTMONK_DB_USER -d $LISTMONK_DB_DATABASE -c "
SELECT 
  COUNT(*) as total_abonnes,
  COUNT(DISTINCT departement_numero) as departements,
  COUNT(DISTINCT nom_commune) as communes
FROM subscribers 
WHERE code_insee IS NOT NULL;
" 2>/dev/null