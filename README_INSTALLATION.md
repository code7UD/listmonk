# 🗺️ Installation Listmonk avec Extension Géographique Française

## ⚡ Installation Express (1 commande)

```bash
# Cloner, configurer et installer automatiquement
git clone https://github.com/code7UD/listmonk.git && cd listmonk && git checkout feature/french-geographic-segmentation && ./install-listmonk-geo.sh
```

## 🎯 Ce que fait le script automatique

✅ **Vérifications automatiques**
- Prérequis Docker et Docker Compose
- Branche Git correcte
- Ports disponibles

✅ **Configuration intelligente**
- Détection automatique des conflits de ports
- Création de la configuration adaptée
- Gestion des variables d'environnement

✅ **Installation complète**
- Construction des images Docker
- Démarrage des services
- Initialisation de la base de données
- Import des données géographiques françaises

✅ **Validation**
- Tests de connectivité
- Vérification des services
- Affichage des URLs d'accès

## 🌐 Accès après installation

| Service | URL par défaut | Identifiants |
|---------|----------------|--------------|
| **Listmonk** | http://localhost:9000 | admin / admin123! |
| **Adminer** | http://localhost:8080 | listmonk / [voir .env] |
| **PostgreSQL** | localhost:5432 | listmonk / [voir .env] |

*Note: Si les ports sont occupés, le script utilisera automatiquement des ports libres et vous indiquera les nouvelles URLs.*

## 🗺️ Fonctionnalités Géographiques

### Segmentation Disponible
- **13 régions** françaises métropolitaines
- **95 départements** français
- **Toutes les communes** avec codes INSEE
- **Population communale** pour chaque commune
- **Catégories socio-professionnelles** (CSP)

### API REST Géographique
- `/api/geo/regions` - Liste des régions
- `/api/geo/departements` - Départements par région
- `/api/geo/communes` - Recherche de communes
- `/api/geo/csps` - Catégories socio-professionnelles
- `/api/geo/stats` - Statistiques géographiques
- `/api/lists/query/geo` - Requêtes de segmentation

## 🔧 Commandes Utiles

```bash
# Voir les logs
docker-compose -f [fichier-compose] logs -f

# Arrêter les services
docker-compose -f [fichier-compose] down

# Redémarrer
docker-compose -f [fichier-compose] restart

# Nettoyage complet
./install-listmonk-geo.sh --clean
```

## 📊 Import de Données CSV

### Format Supporté
```csv
email,firstname,lastname,code_insee,population_commune,nom_commune,departement_numero,state,csp
marie.dupont@example.com,Marie,DUPONT,75101,50000,PARIS 1ER ARRONDISSEMENT,75,PARIS,Cadres et professions intellectuelles supérieures
```

### Procédure d'Import
1. Interface Web : http://localhost:9000 → Subscribers → Import
2. Sélectionner le fichier CSV
3. Mapper les colonnes géographiques
4. Lancer l'import avec validation

## 🆘 En cas de Problème

### Ports Occupés
Le script détecte et résout automatiquement les conflits de ports.

### Erreur de Build
```bash
# Nettoyage et réinstallation
./install-listmonk-geo.sh --clean
./install-listmonk-geo.sh
```

### Services ne Démarrent Pas
```bash
# Vérifier les logs
docker-compose -f docker-compose.simple.yml logs

# Redémarrage complet
docker-compose -f docker-compose.simple.yml down -v
./install-listmonk-geo.sh
```

### Aide
```bash
# Afficher l'aide
./install-listmonk-geo.sh --help
```

## 📚 Documentation Complète

- **[GEOGRAPHIC_FEATURES.md](GEOGRAPHIC_FEATURES.md)** - Guide des fonctionnalités géographiques
- **[TROUBLESHOOTING_DOCKER.md](TROUBLESHOOTING_DOCKER.md)** - Dépannage avancé
- **[INSTALLATION_DOCKER.md](INSTALLATION_DOCKER.md)** - Installation détaillée

## 🎉 Support

1. **Script automatique** : `./install-listmonk-geo.sh`
2. **Documentation** : Consultez les guides dans le repository
3. **Logs** : `docker-compose logs` pour diagnostiquer
4. **GitHub** : Ouvrez une issue pour les problèmes persistants

---

**🗺️ Prêt pour le géomarketing français avec Listmonk !**