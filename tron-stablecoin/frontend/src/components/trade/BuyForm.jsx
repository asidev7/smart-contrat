import React, { useState, useEffect } from 'react';
import { useWallet } from '../../context/WalletContext';
import { getContract, CONTRACT_ADDRESSES, formatTRX, formatToken } from '../../utils/tronWeb';
import VAULT_ABI from '../../contracts/Vault.json';

const BuyForm = () => {
  const { account, connectWallet } = useWallet();
  const [vaultContract, setVaultContract] = useState(null);
  const [trxAmount, setTrxAmount] = useState('');
  const [tokenEstimate, setTokenEstimate] = useState('0');
  const [trxBalance, setTrxBalance] = useState('0');
  const [loading, setLoading] = useState(false);
  const [txHash, setTxHash] = useState('');
  const [error, setError] = useState('');

  // Initialisation du contrat Vault
  useEffect(() => {
    const initContract = async () => {
      if (!account) return;
      
      try {
        const contract = await getContract(CONTRACT_ADDRESSES.VAULT, VAULT_ABI);
        setVaultContract(contract);
      } catch (err) {
        console.error("Erreur d'initialisation du contrat Vault:", err);
        setError("Impossible de charger le contrat");
      }
    };
    
    initContract();
  }, [account]);

  // Récupération du solde TRX
  useEffect(() => {
    const loadTrxBalance = async () => {
      if (!account) return;
      
      try {
        const tronWeb = window.tronWeb;
        const balance = await tronWeb.trx.getBalance(account);
        setTrxBalance(balance.toString());
      } catch (err) {
        console.error("Erreur de chargement du solde TRX:", err);
      }
    };
    
    if (account) {
      loadTrxBalance();
    }
  }, [account]);

  // Estimation du montant de tokens à recevoir
  useEffect(() => {
    const estimateTokens = async () => {
      if (!vaultContract || !trxAmount || isNaN(parseFloat(trxAmount)) || parseFloat(trxAmount) <= 0) {
        setTokenEstimate('0');
        return;
      }
      
      try {
        // Dans un cas réel, vous appelleriez une fonction view du contrat
        // Ici simulation pour le prototype
        const trxPrice = 0.08; // Prix TRX en USD (à remplacer par l'Oracle)
        const trxValue = parseFloat(trxAmount);
        const usdValue = trxValue * trxPrice;
        
        // 0.5% de frais
        const fee = usdValue * 0.005;
        const netUsdValue = usdValue - fee;
        
        setTokenEstimate(netUsdValue.toFixed(2));
      } catch (err) {
        console.error("Erreur d'estimation:", err);
        setTokenEstimate('0');
      }
    };
    
    estimateTokens();
  }, [vaultContract, trxAmount]);

  // Fonction d'achat de tokens
  const handleBuy = async (e) => {
    e.preventDefault();
    
    if (!account) {
      try {
        await connectWallet();
      } catch (err) {
        setError("Veuillez connecter votre wallet pour continuer");
        return;
      }
    }
    
    if (!vaultContract) {
      setError("Contrat non initialisé");
      return;
    }
    
    if (!trxAmount || isNaN(parseFloat(trxAmount)) || parseFloat(trxAmount) <= 0) {
      setError("Veuillez entrer un montant valide");
      return;
    }
    
    const trxValue = parseFloat(trxAmount);
    const sunAmount = trxValue * 1_000_000; // Conversion en SUN (unité de TRX)
    
    if (sunAmount > Number(trxBalance)) {
      setError("Solde TRX insuffisant");
      return;
    }
    
    setLoading(true);
    setError('');
    setTxHash('');
    
    try {
      // Appel de la fonction buyTokenWithTRX du contrat Vault
      const tx = await vaultContract.buyTokenWithTRX().send({
        callValue: sunAmount.toString(),
        shouldPollResponse: true
      });
      
      setTxHash(tx);
      setTrxAmount('');
      
      // Rafraîchir le solde TRX
      const tronWeb = window.tronWeb;
      const balance = await tronWeb.trx.getBalance(account);
      setTrxBalance(balance.toString());
      
    } catch (err) {
      console.error("Erreur d'achat:", err);
      setError(err.message || "La transaction a échoué");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="bg-white rounded-lg shadow-md p-4">
      <h2 className="text-xl font-bold text-gray-800 mb-4">Acheter avec TRX</h2>
      
      <form onSubmit={handleBuy}>
        <div className="mb-4">
          <label className="block text-gray-700 text-sm font-medium mb-2">
            Montant TRX
          </label>
          <div className="relative rounded-md shadow-sm">
            <input
              type="number"
              value={trxAmount}
              onChange={(e) => setTrxAmount(e.target.value)}
              className="focus:ring-blue-500 focus:border-blue-500 block w-full pl-3 pr-12 py-2 sm:text-sm border border-gray-300 rounded-md"
              placeholder="0.0"
              min="0"
              step="0.01"
              disabled={loading}
            />
            <div className="absolute inset-y-0 right-0 flex items-center pr-3">
              <span className="text-gray-500 sm:text-sm">TRX</span>
            </div>
          </div>
          <div className="mt-1 text-sm text-gray-500">
            Solde: {formatTRX(trxBalance)} TRX
          </div>
        </div>
        
        <div className="mb-4">
          <div className="flex justify-between text-sm text-gray-600">
            <span>Vous recevrez (estimation):</span>
            <span className="font-medium">{tokenEstimate} TRST</span>
          </div>
          <div className="text-xs text-gray-500 mt-1">
            Frais inclus: 0.5%
          </div>
        </div>
        
        {error && (
          <div className="mb-4 p-2 bg-red-100 border border-red-300 text-red-800 rounded-md text-sm">
            {error}
          </div>
        )}
        
        {txHash && (
          <div className="mb-4 p-2 bg-green-100 border border-green-300 text-green-800 rounded-md text-sm">
            Transaction réussie! Hash: {txHash.slice(0, 8)}...{txHash.slice(-8)}
          </div>
        )}
        
        <button
          type="submit"
          className={`w-full bg-blue-600 text-white py-2 px-4 rounded-md ${
            loading ? 'opacity-70 cursor-not-allowed' : 'hover:bg-blue-700'
          }`}
          disabled={loading}
        >
          {loading ? (
            <span className="flex items-center justify-center">
              <svg className="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              Traitement...
            </span>
          ) : account ? (
            'Acheter des tokens'
          ) : (
            'Connecter wallet'
          )}
        </button>
      </form>
    </div>
  );
};

export default BuyForm;