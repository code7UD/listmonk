-- Script d'initialisation PostgreSQL minimal pour extension géographique
-- Ne modifie PAS la table subscribers (qui n'existe pas encore)
-- Crée seulement les extensions et la table de mapping

\echo 'Initialisation minimale de la base de données géographique...'

-- Créer les extensions PostgreSQL nécessaires
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Créer la table de mapping départements/régions françaises
CREATE TABLE IF NOT EXISTS departement_region_mapping (
    departement_numero VARCHAR(3) PRIMARY KEY,
    departement_nom VARCHAR(255) NOT NULL,
    region_nom VARCHAR(255) NOT NULL,
    region_code VARCHAR(3) NOT NULL
);

-- Insérer les 95 départements français avec leurs régions
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

-- Créer les index pour optimiser les requêtes
CREATE INDEX IF NOT EXISTS idx_departement_region_mapping_region ON departement_region_mapping(region_nom);
CREATE INDEX IF NOT EXISTS idx_departement_region_mapping_dept ON departement_region_mapping(departement_nom);

\echo 'Initialisation minimale terminée - 95 départements français chargés'