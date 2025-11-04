#!/bin/bash

echo "🔍 DIAGNOSTIC - Problème Test SQL"
echo "=================================="

echo ""
echo "1. Vérification du script de test actuel :"
echo "-------------------------------------------"
grep -n "Extension table subscribers" test-build-local.sh || echo "✅ Pas de référence à 'Extension table subscribers'"
grep -n "ALTER TABLE subscribers" test-build-local.sh || echo "✅ Pas de référence à 'ALTER TABLE subscribers'"

echo ""
echo "2. Vérification du fichier SQL :"
echo "--------------------------------"
echo "Table departement_region_mapping :"
grep -q "CREATE TABLE.*departement_region_mapping" docker/init-scripts/01-init-geo.sql && echo "✅ Trouvée" || echo "❌ Manquante"

echo "Départements français :"
grep -q "('01', 'Ain'" docker/init-scripts/01-init-geo.sql && echo "✅ Trouvés" || echo "❌ Manquants"

echo "Extension uuid-ossp :"
grep -q "CREATE EXTENSION.*uuid-ossp" docker/init-scripts/01-init-geo.sql && echo "✅ Trouvée" || echo "❌ Manquante"

echo "Nombre de départements :"
dept_count=$(grep -c "^('.*'," docker/init-scripts/01-init-geo.sql 2>/dev/null || echo "0")
echo "$dept_count départements trouvés"

echo ""
echo "3. Test des commandes individuelles :"
echo "-------------------------------------"

echo "Test 1 - Table mapping :"
if grep -q "CREATE TABLE.*departement_region_mapping" docker/init-scripts/01-init-geo.sql; then
    echo "✅ SUCCÈS"
else
    echo "❌ ÉCHEC"
fi

echo "Test 2 - Départements :"
if grep -q "('01', 'Ain'" docker/init-scripts/01-init-geo.sql; then
    echo "✅ SUCCÈS"
else
    echo "❌ ÉCHEC"
fi

echo "Test 3 - Extensions :"
if grep -q "CREATE EXTENSION.*uuid-ossp" docker/init-scripts/01-init-geo.sql; then
    echo "✅ SUCCÈS"
else
    echo "❌ ÉCHEC"
fi

echo ""
echo "4. Contenu du fichier SQL (premières lignes) :"
echo "----------------------------------------------"
head -20 docker/init-scripts/01-init-geo.sql

echo ""
echo "5. Version du repository :"
echo "-------------------------"
git log --oneline -5

echo ""
echo "6. Statut des fichiers :"
echo "------------------------"
git status --porcelain

echo ""
echo "🎯 SOLUTION RECOMMANDÉE :"
echo "========================"
echo "Si le test échoue encore, utilisez :"
echo "./test-build-local-fixed.sh"
echo ""
echo "Ou mettez à jour le repository :"
echo "git pull origin feature/french-geographic-segmentation"
echo ""