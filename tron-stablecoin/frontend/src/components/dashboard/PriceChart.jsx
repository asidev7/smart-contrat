import React, { useState, useEffect } from 'react';
import { 
  LineChart, Line, XAxis, YAxis, CartesianGrid, 
  Tooltip, Legend, ResponsiveContainer 
} from 'recharts';
import axios from 'axios';

const PriceChart = () => {
  const [priceData, setPriceData] = useState([]);
  const [timeframe, setTimeframe] = useState('day'); // day, week, month
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Fonction pour charger les données du prix
  const fetchPriceData = async () => {
    setLoading(true);
    setError(null);
    
    try {
      // En production, remplacez par votre API de prix réelle
      // Ici juste un exemple avec des données simulées
      let apiUrl = `/api/price-history?timeframe=${timeframe}`;
      
      // Dans cet exemple, on simule un appel API
      // const response = await axios.get(apiUrl);
      // const data = response.data;
      
      // Données simulées pour le développement
      const currentDate = new Date();
      const data = [];
      
      // Générer des données selon le timeframe
      let points = timeframe === 'day' ? 24 : timeframe === 'week' ? 7 : 30;
      
      for (let i = 0; i < points; i++) {
        const date = new Date(currentDate);
        
        if (timeframe === 'day') {
          date.setHours(currentDate.getHours() - (points - i));
        } else if (timeframe === 'week') {
          date.setDate(currentDate.getDate() - (points - i));
        } else {
          date.setDate(currentDate.getDate() - (points - i));
        }
        
        // Prix fluctuant légèrement autour de 1$
        const price = 1 + (Math.random() * 0.1 - 0.05);
        
        data.push({
          timestamp: date.toISOString(),
          price: price.toFixed(4),
          label: timeframe === 'day' 
            ? date.getHours() + 'h' 
            : date.getDate() + '/' + (date.getMonth() + 1)
        });
      }
      
      setPriceData(data);
    } catch (err) {
      console.error("Erreur de chargement des données:", err);
      setError("Impossible de charger l'historique des prix");
    } finally {
      setLoading(false);
    }
  };

  // Charger les données au chargement et changement de timeframe
  useEffect(() => {
    fetchPriceData();
  }, [timeframe]);

  return (
    <div className="bg-white rounded-lg shadow-md p-4">
      <div className="flex justify-between items-center mb-4">
        <h2 className="text-xl font-bold text-gray-800">Prix du Token</h2>
        <div className="flex space-x-2">
          <button 
            onClick={() => setTimeframe('day')}
            className={`px-3 py-1 rounded-md ${
              timeframe === 'day' 
                ? 'bg-blue-600 text-white' 
                : 'bg-gray-100 text-gray-600'
            }`}
          >
            24h
          </button>
          <button 
            onClick={() => setTimeframe('week')}
            className={`px-3 py-1 rounded-md ${
              timeframe === 'week' 
                ? 'bg-blue-600 text-white' 
                : 'bg-gray-100 text-gray-600'
            }`}
          >
            7j
          </button>
          <button 
            onClick={() => setTimeframe('month')}
            className={`px-3 py-1 rounded-md ${
              timeframe === 'month' 
                ? 'bg-blue-600 text-white' 
                : 'bg-gray-100 text-gray-600'
            }`}
          >
            30j
          </button>
        </div>
      </div>
      
      {loading ? (
        <div className="flex justify-center items-center h-64">
          <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-blue-500"></div>
        </div>
      ) : error ? (
        <div className="flex justify-center items-center h-64 text-red-500">
          {error}
        </div>
      ) : (
        <div className="h-64">
          <ResponsiveContainer width="100%" height="100%">
            <LineChart
              data={priceData}
              margin={{ top: 5, right: 30, left: 20, bottom: 5 }}
            >
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis 
                dataKey="label" 
                tick={{ fontSize: 12 }}
              />
              <YAxis 
                domain={[0.9, 1.1]} 
                tick={{ fontSize: 12 }}
                tickFormatter={(tick) => `$${tick.toFixed(2)}`}
              />
              <Tooltip 
                formatter={(value) => [`$${value}`, 'Prix']}
                labelFormatter={(label) => `Temps: ${label}`}
              />
              <Legend />
              <Line
                type="monotone"
                dataKey="price"
                stroke="#0068FF"
                activeDot={{ r: 8 }}
                name="Prix"
                strokeWidth={2}
              />
            </LineChart>
          </ResponsiveContainer>
        </div>
      )}
      
      <div className="mt-2 text-center">
        <span className="text-sm text-gray-500">
          Dernière mise à jour: {new Date().toLocaleTimeString()}
        </span>
      </div>
    </div>
  );
};

export default PriceChart;