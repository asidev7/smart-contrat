# smart-contrat
# TRC-20 DynamicStable & Vault System

Un système complet de stablecoin sur la blockchain TRON avec mécanismes de stabilisation dynamique, oracle de prix et gestion de trésorerie.

## Aperçu

Ce projet implémente une solution de stablecoin indexé sur l'USD pour la blockchain TRON, comprenant trois contrats intelligents principaux qui travaillent ensemble :

1. **DynamicStable** - Un token TRC-20 avec des fonctionnalités de mint/burn dynamiques
2. **Vault** - Un système de gestion de liquidité qui sert d'interface entre les utilisateurs et le stablecoin
3. **PriceOracle** - Un oracle qui fournit des mises à jour du prix TRX/USD au système

## Fonctionnalités principales

### DynamicStable (Token TRC-20)
- Token TRC-20 standard avec gestion du nom, symbole et décimales
- Mécanismes de mint/burn contrôlés par le Vault et le propriétaire
- Plafond d'approvisionnement maximum configurable
- Contrôle de l'activation/désactivation des ajustements d'approvisionnement
- Transfert de propriété sécurisé en deux étapes

### Vault (Gestion de liquidité)
- Achat de tokens avec TRX ou USDT
- Vente de tokens contre TRX ou USDT
- Frais d'achat et de vente configurables (jusqu'à 5%)
- Système de collecte de frais pour l'opérateur
- Statistiques de réserve de trésorerie pour TRX et USDT
- Mécanisme de retrait d'urgence pour la sécurité des fonds
- Prix TRX/USD configurable avec protection contre les manipulations

### PriceOracle (Oracle de prix)
- Mise à jour du prix TRX/USD dans le Vault
- Système d'autorisations multi-updaters
- Vérifications de déviation maximale des prix
- Intervalles minimums entre les mises à jour
- Capacité de mise à jour forcée en cas d'urgence
- Contrôle des updaters (ajout/suppression)

## Sécurité

Plusieurs mécanismes de sécurité sont implémentés :

- Transfert de propriété en deux étapes sur tous les contrats
- Limites de déviation de prix pour prévenir les manipulations
- Intervalles minimums entre les mises à jour de prix
- Vérifications sur toutes les opérations critiques

## Installation et déploiement

### Prérequis

- TronBox ou autre environnement de développement TRON
- Un compte TRON avec suffisamment de TRX pour le déploiement
- Environnement Node.js

### Étapes de déploiement

1. Déployer le contrat DynamicStable
   ```javascript
   const token = await DynamicStable.deploy(
     "NomDuToken", 
     "SYMBOLE", 
     6, // décimales, généralement 6 pour les stablecoins
     1000000000000 // approvisionnement maximum
   );
   ```

2. Déployer le contrat Vault avec l'adresse du token
   ```javascript
   const vault = await Vault.deploy(
     token.address,
     "ADRESSE_DU_TOKEN_USDT",
     3000000 // Prix initial TRX/USD, par ex. 0.03 USD
   );
   ```

3. Déployer le contrat PriceOracle avec l'adresse du Vault
   ```javascript
   const oracle = await PriceOracle.deploy(
     vault.address,
     3000000 // Prix initial TRX/USD, identique à celui du Vault
   );
   ```

4. Configurer le Vault comme adresse autorisée à mint/burn dans le token
   ```javascript
   await token.setVaultAddress(vault.address);
   ```

## Utilisation

### Pour les utilisateurs

#### Achat de tokens
```javascript
// Avec TRX
await vault.buyTokenWithTRX({ value: 1000000000 }); // 1000 TRX

// Avec USDT
await usdtToken.approve(vault.address, 30000000); // Approuver 30 USDT
await vault.buyTokenWithUSDT(30000000); // Acheter avec 30 USDT
```

#### Vente de tokens
```javascript
// Approuver le Vault à dépenser vos tokens
await token.approve(vault.address, 30000000); // Approuver 30 tokens

// Vendre contre TRX
await vault.sellTokenForTRX(30000000);

// Vendre contre USDT
await vault.sellTokenForUSDT(30000000);
```

### Pour les administrateurs

#### Mise à jour des prix
```javascript
// Via l'Oracle (méthode recommandée)
await oracle.updatePrice(3100000); // 0.031 USD

// Mise à jour forcée en cas d'urgence
await oracle.forceUpdatePrice(3100000); // 0.031 USD
```

#### Gestion des frais
```javascript
// Définir de nouveaux frais (en points de base, 100 = 1%)
await vault.setBuyFee(50); // 0.5%
await vault.setSellFee(50); // 0.5%

// Collecte des frais
await vault.collectFees(1000000000, 5000000); // 1000 TRX et 5 USDT
```

## Événements importants

Le système émet les événements suivants pour le suivi des opérations :

- `Transfer` - Transfert standard de TRC-20
- `Approval` - Approbation standard de TRC-20
- `Minted` - Tokens créés
- `Burned` - Tokens détruits
- `TokensBought` - Achat de tokens par un utilisateur
- `TokensSold` - Vente de tokens par un utilisateur
- `PriceUpdated` - Mise à jour du prix TRX/USD
- `FeeUpdated` - Mise à jour des frais
- `FeeCollected` - Collecte des frais
- `OwnershipTransferred` - Transfert de propriété du contrat

## Licence

SPDX-License-Identifier: MIT