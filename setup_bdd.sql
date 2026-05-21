-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Hôte : mysql
-- Généré le : mer. 20 mai 2026 à 11:35
-- Version du serveur : 8.0.46
-- Version de PHP : 8.3.26

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de données : `app_db`
--

-- --------------------------------------------------------

--
-- Structure de la table `factures`
--

CREATE TABLE `factures` (
  `id` int NOT NULL,
  `name` text NOT NULL,
  `path` text NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `historique_vente`
--

CREATE TABLE `historique_vente` (
  `id` int NOT NULL,
  `nom_tpe` varchar(50) NOT NULL,
  `datetime` datetime NOT NULL,
  `status` tinyint NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `limites`
--

CREATE TABLE `limites` (
  `code_article` varchar(20) NOT NULL,
  `sup` int DEFAULT NULL,
  `inf` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `logs`
--

CREATE TABLE `logs` (
  `id` int NOT NULL,
  `datetime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `detail` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Structure de la table `stock`
--

CREATE TABLE `stock` (
  `code_article` varchar(20) NOT NULL,
  `designation` text NOT NULL,
  `quantite` float NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Déclencheurs `stock`
--
DELIMITER $$
CREATE TRIGGER `clamp_quantite_before_update` BEFORE UPDATE ON `stock` FOR EACH ROW BEGIN
    IF NEW.quantite < 0 THEN
        SET NEW.quantite = 0;
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Structure de la table `tpe_code_article`
--

CREATE TABLE `tpe_code_article` (
  `code_article` varchar(20) NOT NULL,
  `nom_tpe` varchar(50) NOT NULL,
  `type` enum('Viennoiseries','Snacks','Confiseries','Boissons','Glaces','Divers') NOT NULL,
  `debit_factor` float NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Index pour les tables déchargées
--

--
-- Index pour la table `factures`
--
ALTER TABLE `factures`
  ADD PRIMARY KEY (`id`);

--
-- Index pour la table `historique_vente`
--
ALTER TABLE `historique_vente`
  ADD PRIMARY KEY (`id`);

--
-- Index pour la table `limites`
--
ALTER TABLE `limites`
  ADD PRIMARY KEY (`code_article`);

--
-- Index pour la table `logs`
--
ALTER TABLE `logs`
  ADD PRIMARY KEY (`id`);

--
-- Index pour la table `stock`
--
ALTER TABLE `stock`
  ADD PRIMARY KEY (`code_article`);

--
-- Index pour la table `tpe_code_article`
--
ALTER TABLE `tpe_code_article`
  ADD PRIMARY KEY (`code_article`) USING BTREE,
  ADD UNIQUE KEY `nom_tpe` (`nom_tpe`);

--
-- AUTO_INCREMENT pour les tables déchargées
--

--
-- AUTO_INCREMENT pour la table `factures`
--
ALTER TABLE `factures`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT pour la table `historique_vente`
--
ALTER TABLE `historique_vente`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT pour la table `logs`
--
ALTER TABLE `logs`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- Contraintes pour les tables déchargées
--

--
-- Contraintes pour la table `limites`
--
ALTER TABLE `limites`
  ADD CONSTRAINT `code_article_limites` FOREIGN KEY (`code_article`) REFERENCES `stock` (`code_article`) ON DELETE RESTRICT ON UPDATE RESTRICT;

--
-- Contraintes pour la table `tpe_code_article`
--
ALTER TABLE `tpe_code_article`
  ADD CONSTRAINT `code_article` FOREIGN KEY (`code_article`) REFERENCES `stock` (`code_article`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
