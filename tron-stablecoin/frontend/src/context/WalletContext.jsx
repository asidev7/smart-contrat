import React, { createContext, useState, useEffect, useContext } from 'react';
import { initTronWeb, getAccount } from '../utils/tronWeb';

// Création du contexte
const WalletContext = createContext(null);

// Provider pour envelopper l'application
export const WalletProvider = ({ children }) => {
  const [account, setAccount] = useState(null);
  const [tronWeb, setTronWeb] = useState(null);
  const [isConnecting, setIsConnecting] = useState(false);
  const [error, setError] = useState(null);

  // Fonction pour connecter le wallet
  const connectWallet = async () => {
    if (isConnecting) return;
    
    try {
      setIsConnecting(true);
      setError(null);
      
      // Initialise TronWeb et demande connexion
      const tronWebInstance = await initTronWeb();
      setTronWeb(tronWebInstance);
      
      // Récupère l'adresse
      const userAddress = await getAccount();
      setAccount(userAddress);
      
      // Écoute les changements de compte
      window.addEventListener('message', handleTronLinkMessage);
      
      setIsConnecting(false);
      return userAddress;
    } catch (err) {
      console.error("Erreur de connexion wallet:", err);
      setError(err.message || "Erreur de connexion au wallet");
      setIsConnecting(false);
      throw err;
    }
  };

  // Fonction pour déconnecter le wallet
  const disconnectWallet = () => {
    setAccount(null);
    window.removeEventListener('message', handleTronLinkMessage);
  };

  // Gérer les événements TronLink
  const handleTronLinkMessage = (e) => {
    if (e.data.message && e.data.message.action === "accountsChanged") {
      // Mise à jour du compte en cas de changement
      if (e.data.message.data.address) {
        setAccount(e.data.message.data.address);
      } else {
        setAccount(null);
      }
    }
    
    // Si déconnexion détectée
    if (e.data.message && e.data.message.action === "disconnect") {
      setAccount(null);
    }
  };

  // Tenter une connexion automatique au chargement
  useEffect(() => {
    const autoConnect = async () => {
      if (window.tronWeb && window.tronLink && window.tronLink.ready) {
        try {
          await connectWallet();
        } catch (err) {
          console.log("Auto-connexion échouée:", err);
        }
      }
    };
    
    autoConnect();
    
    // Nettoyage à la destruction du composant
    return () => {
      window.removeEventListener('message', handleTronLinkMessage);
    };
  }, []);

  // Valeurs exposées par le contexte
  const value = {
    account,
    tronWeb,
    isConnecting,
    error,
    connectWallet,
    disconnectWallet
  };

  return (
    <WalletContext.Provider value={value}>
      {children}
    </WalletContext.Provider>
  );
};

// Hook personnalisé pour utiliser le contexte
export const useWallet = () => {
  const context = useContext(WalletContext);
  if (!context) {
    throw new Error("useWallet doit être utilisé à l'intérieur d'un WalletProvider");
  }
  return context;
};