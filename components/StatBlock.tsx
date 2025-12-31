import React from 'react';

interface StatBlockProps {
  label: string;
  value: number;
  bonus?: number; // New prop for external bonuses (Patron)
  min?: number;
  max?: number;
  onChange: (val: number) => void;
  isAttribute?: boolean; // Changes styling slightly
  description?: string;
}

export const StatBlock: React.FC<StatBlockProps> = ({ 
  label, 
  value, 
  bonus = 0,
  min = 0, 
  max = 5, 
  onChange, 
  isAttribute = false,
  description
}) => {
  const totalValue = value + bonus;
  const hasBonus = bonus > 0;

  return (
    <div className={`flex items-center justify-between p-2 rounded border ${isAttribute ? 'bg-amber-50 border-amber-200' : 'bg-white border-stone-200'} mb-2`}>
      <div className="flex flex-col">
        <span className={`font-serif ${isAttribute ? 'font-bold text-amber-900 text-lg' : 'font-semibold text-stone-700'}`}>
          {label}
        </span>
        {description && <span className="text-xs text-stone-500 italic">{description}</span>}
      </div>
      
      <div className="flex items-center space-x-2">
        <button 
          onClick={() => onChange(Math.max(min, value - 1))}
          className="w-8 h-8 rounded-full bg-stone-200 hover:bg-stone-300 text-stone-700 font-bold flex items-center justify-center transition-colors"
          tabIndex={-1}
        >
          -
        </button>
        
        <div className="flex flex-col items-center w-8">
           <span className={`text-center font-bold ${
             isAttribute 
               ? 'text-2xl text-amber-800' 
               : hasBonus ? 'text-xl text-green-600' : 'text-xl text-stone-800'
           }`}>
            {totalValue}
          </span>
        </div>

        <button 
          onClick={() => onChange(Math.min(max, value + 1))}
          className="w-8 h-8 rounded-full bg-amber-200 hover:bg-amber-300 text-amber-900 font-bold flex items-center justify-center transition-colors"
          tabIndex={-1}
        >
          +
        </button>
      </div>
    </div>
  );
};