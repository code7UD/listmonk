-- ========================================================================
-- DÉMONSTRATION DES FONCTIONNALITÉS GÉOGRAPHIQUES LISTMONK
-- ========================================================================

\echo '🗺️  DÉMONSTRATION DES FONCTIONNALITÉS GÉOGRAPHIQUES LISTMONK'
\echo '======================================================================'

-- 1. Statistiques globales
\echo ''
\echo '📊 1. STATISTIQUES GLOBALES'
\echo '------------------------------'

SELECT 
    COUNT(*) as total_subscribers,
    COUNT(DISTINCT departement_numero) as departements_count,
    COUNT(DISTINCT nom_commune) as communes_count,
    COUNT(DISTINCT csp) as csp_count
FROM subscribers 
WHERE status = 'enabled' AND code_insee IS NOT NULL;

-- 2. Répartition par région
\echo ''
\echo '🏛️  2. RÉPARTITION PAR RÉGION'
\echo '------------------------------'

SELECT 
    drm.region_nom, 
    COUNT(*) as count_subscribers
FROM subscribers s 
LEFT JOIN departement_region_mapping drm ON s.departement_numero = drm.departement_numero 
WHERE s.status = 'enabled' AND s.code_insee IS NOT NULL
GROUP BY drm.region_nom 
ORDER BY count_subscribers DESC;

-- 3. Répartition par département
\echo ''
\echo '🏢 3. RÉPARTITION PAR DÉPARTEMENT'
\echo '------------------------------'

SELECT 
    drm.departement_nom, 
    s.departement_numero, 
    COUNT(*) as count_subscribers
FROM subscribers s 
LEFT JOIN departement_region_mapping drm ON s.departement_numero = drm.departement_numero 
WHERE s.status = 'enabled' AND s.code_insee IS NOT NULL
GROUP BY drm.departement_nom, s.departement_numero 
ORDER BY count_subscribers DESC;

-- 4. Répartition par CSP
\echo ''
\echo '👥 4. RÉPARTITION PAR CSP'
\echo '------------------------------'

SELECT 
    csp, 
    COUNT(*) as count_subscribers
FROM subscribers 
WHERE status = 'enabled' AND csp IS NOT NULL AND csp != ''
GROUP BY csp 
ORDER BY count_subscribers DESC;

-- 5. Statistiques de population
\echo ''
\echo '🏘️  5. STATISTIQUES DE POPULATION'
\echo '------------------------------'

SELECT 
    MIN(population_commune) as min_pop,
    MAX(population_commune) as max_pop,
    AVG(population_commune)::int as avg_pop,
    SUM(population_commune) as total_pop
FROM subscribers 
WHERE status = 'enabled' AND population_commune > 0;

-- 6. Exemples de requêtes de segmentation
\echo ''
\echo '🎯 6. EXEMPLES DE SEGMENTATION GÉOGRAPHIQUE'
\echo '---------------------------------------------'

\echo ''
\echo '   a) Abonnés en Auvergne-Rhône-Alpes:'

SELECT 
    s.email, 
    s.nom_commune, 
    s.population_commune
FROM subscribers s 
LEFT JOIN departement_region_mapping drm ON s.departement_numero = drm.departement_numero 
WHERE s.status = 'enabled' AND drm.region_nom = 'Auvergne-Rhône-Alpes';

\echo ''
\echo '   b) Abonnés dans des communes de 10k-50k habitants:'

SELECT 
    s.email, 
    s.nom_commune, 
    s.population_commune, 
    drm.region_nom
FROM subscribers s 
LEFT JOIN departement_region_mapping drm ON s.departement_numero = drm.departement_numero 
WHERE s.status = 'enabled' 
AND s.population_commune >= 10000 
AND s.population_commune <= 50000
ORDER BY s.population_commune DESC;

\echo ''
\echo '   c) Cadres et professions intellectuelles supérieures:'

SELECT 
    s.email, 
    s.nom_commune, 
    drm.region_nom
FROM subscribers s 
LEFT JOIN departement_region_mapping drm ON s.departement_numero = drm.departement_numero 
WHERE s.status = 'enabled' 
AND s.csp = 'Cadres et professions intellectuelles supérieures';

\echo ''
\echo '   d) Requête complexe - Cadres en Île-de-France dans grandes villes:'

SELECT 
    s.email, 
    s.nom_commune, 
    s.population_commune, 
    s.csp
FROM subscribers s 
LEFT JOIN departement_region_mapping drm ON s.departement_numero = drm.departement_numero 
WHERE s.status = 'enabled' 
AND drm.region_nom = 'Île-de-France'
AND s.csp LIKE '%Cadres%'
AND s.population_commune > 40000;

-- 7. Simulation de campagnes ciblées
\echo ''
\echo '📧 7. SIMULATION DE CAMPAGNES CIBLÉES'
\echo '-----------------------------------'

\echo ''
\echo '   Campagne Régionale Sud:'
SELECT COUNT(*) as destinataires FROM subscribers s 
LEFT JOIN departement_region_mapping drm ON s.departement_numero = drm.departement_numero 
WHERE s.status = 'enabled' 
AND drm.region_nom IN ('Provence-Alpes-Côte d''Azur', 'Occitanie');

\echo ''
\echo '   Campagne Grandes Métropoles:'
SELECT COUNT(*) as destinataires FROM subscribers s 
WHERE s.status = 'enabled' 
AND s.population_commune > 100000;

\echo ''
\echo '   Campagne CSP Cadres:'
SELECT COUNT(*) as destinataires FROM subscribers s 
WHERE s.status = 'enabled' 
AND s.csp LIKE '%Cadres%';

\echo ''
\echo '   Campagne Villes Moyennes Rhône-Alpes:'
SELECT COUNT(*) as destinataires FROM subscribers s 
LEFT JOIN departement_region_mapping drm ON s.departement_numero = drm.departement_numero 
WHERE s.status = 'enabled' 
AND drm.region_nom = 'Auvergne-Rhône-Alpes'
AND s.population_commune BETWEEN 20000 AND 100000;

\echo ''
\echo '✅ Démonstration terminée avec succès!'
\echo ''
\echo '💡 FONCTIONNALITÉS DISPONIBLES:'
\echo '   • Segmentation par région française'
\echo '   • Segmentation par département'
\echo '   • Segmentation par commune'
\echo '   • Filtrage par population communale'
\echo '   • Filtrage par CSP (Catégorie Socio-Professionnelle)'
\echo '   • Combinaison de critères multiples'
\echo '   • API REST pour intégration frontend'
\echo '   • Import CSV avec données géographiques'