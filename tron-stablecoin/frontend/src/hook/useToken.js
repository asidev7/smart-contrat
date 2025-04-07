import { useState, useEffect, useCallback } from 'react';
import { getContract, CONTRACT_ADDRESSES } from '../utils/tronWeb';
import TOKEN_ABI from '../contracts/StableToken.json';

const useToken = () => {
  const [tokenContract, setTokenContract] = useState(null);
  const [totalSupply, setTotalSupply] = useState('0');
  const [userBalance, setUserBalance] = useState('0');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Initialiser le contrat token
  useEffect(() => {
    const initContract = async () => {
      try {
        setLoading(true);
        const contract = await getContract(CONTRACT_ADDRESSES.TOKEN, TOKEN_ABI);
        setTokenContract(contract);
        setLoading(false);
      } catch (err) {
        console.error("Erreur d'initialisation du contrat:", err);
        setError("Impossible de charger le contrat token");
        setLoading(false);
      }
    };

    initContract();
  }, []);

  // Rafraîchir le supply total
  const refreshTotalSupply = useCallback(async () => {
    if (!tokenContract) return;
    
    try {
      const supply = await tokenContract.totalSupply().call();
      setTotalSupply(supply.toString());
    } catch (err) {
      console.error("Erreur de chargement du supply:", err);
      setError("Impossible de charger le supply total");
    }
  }, [tokenContract]);

  // Rafraîchir le solde de l'utilisateur
  const refreshUserBalance = useCallback(async (address) => {
    if (!tokenContract || !address) return;
    
    try {
      const balance = await tokenContract.balanceOf(address).call();
      setUserBalance(balance.toString());
    } catch (err) {
      console.error("Erreur de chargement du solde:", err);
      setError("Impossible de charger votre solde");
    }
  }, [tokenContract]);

  // Approuver le contrat Vault pour dépenser les tokens
  const approveVault = useCallback(async (amount) => {
    if (!tokenContract) throw new Error("Contrat non initialisé");
    
    try {
      const tx = await tokenContract.approve(
        CONTRACT_ADDRESSES.VAULT, 
        amount
      ).send();
      
      return tx;
    } catch (err) {
      console.error("Erreur d'approbation:", err);
      throw new Error("L'approbation a échoué: " + err.message);
    }
  }, [tokenContract]);

  useEffect(() => {
    if (tokenContract) {
      refreshTotalSupply();
    }
  }, [tokenContract, refreshTotalSupply]);

  return {
    tokenContract,
    totalSupply,
    userBalance,
    refreshUserBalance,
    refreshTotalSupply,
    approveVault,
    loading,
    error
  };
};

export default useToken;