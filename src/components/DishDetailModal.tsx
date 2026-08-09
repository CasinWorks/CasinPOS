import React, { useState } from 'react';
import { DishItem, SelectedAddition } from '../types';
import { X, Plus, Minus, Check, Flame, Weight } from 'lucide-react';

interface DishDetailModalProps {
  dish: DishItem;
  onClose: () => void;
  onAddToCart: (dish: DishItem, quantity: number, additions: SelectedAddition[]) => void;
}

export const DishDetailModal: React.FC<DishDetailModalProps> = ({
  dish,
  onClose,
  onAddToCart,
}) => {
  const [quantity, setQuantity] = useState(1);
  const [selectedAdditions, setSelectedAdditions] = useState<SelectedAddition[]>([]);

  const toggleAddition = (addition: { id: string; name: string; price: number }) => {
    setSelectedAdditions((prev) => {
      const exists = prev.some((a) => a.id === addition.id);
      if (exists) {
        return prev.filter((a) => a.id !== addition.id);
      } else {
        return [...prev, addition];
      }
    });
  };

  const additionsTotal = selectedAdditions.reduce((sum, a) => sum + a.price, 0);
  const totalPrice = (dish.price + additionsTotal) * quantity;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs animate-in fade-in duration-200">
      <div className="bg-white rounded-3xl max-w-2xl w-full overflow-hidden shadow-2xl border border-slate-100 flex flex-col md:flex-row relative">
        {/* Close Button */}
        <button
          onClick={onClose}
          className="absolute top-3 right-3 z-10 w-8 h-8 rounded-full bg-slate-100 hover:bg-slate-200 text-slate-700 flex items-center justify-center transition-colors cursor-pointer"
        >
          <X className="w-4 h-4" />
        </button>

        {/* Left Side: Dish Image */}
        <div className="md:w-1/2 relative bg-slate-100 min-h-[240px] md:min-h-[360px]">
          <img
            src={dish.image}
            alt={dish.name}
            className="w-full h-full object-cover"
          />
          {dish.popular && (
            <span className="absolute top-3 left-3 px-3 py-1 rounded-full bg-pink-500 text-white text-[10px] font-bold shadow-md tracking-wider uppercase">
              Chef Special
            </span>
          )}
        </div>

        {/* Right Side: Dish Details & Additions */}
        <div className="md:w-1/2 p-5 flex flex-col justify-between space-y-4">
          <div className="space-y-3">
            <div>
              <h3 className="text-base font-extrabold text-slate-900 leading-tight">
                {dish.name}
              </h3>
              <p className="text-lg font-black text-slate-900 mt-1">
                ₱{dish.price.toFixed(2)}
              </p>
            </div>

            {dish.description && (
              <p className="text-xs text-slate-500 leading-relaxed">
                {dish.description}
              </p>
            )}

            {/* Weight & Calories Pills */}
            <div className="flex items-center gap-2 text-[10px] text-slate-500 font-semibold">
              <span className="px-2.5 py-1 rounded-lg bg-slate-100 flex items-center gap-1">
                <Weight className="w-3 h-3 text-slate-400" />
                {dish.weight}
              </span>
              {dish.calories && (
                <span className="px-2.5 py-1 rounded-lg bg-amber-50 text-amber-800 flex items-center gap-1">
                  <Flame className="w-3 h-3 text-amber-500" />
                  {dish.calories}
                </span>
              )}
            </div>

            {/* Additions Section */}
            {dish.additions && dish.additions.length > 0 && (
              <div className="space-y-2 pt-1 border-t border-slate-100">
                <h4 className="text-xs font-bold text-slate-900">Additions</h4>
                <div className="space-y-1.5 max-h-36 overflow-y-auto pr-1">
                  {dish.additions.map((addition) => {
                    const isSelected = selectedAdditions.some((a) => a.id === addition.id);

                    return (
                      <div
                        key={addition.id}
                        onClick={() => toggleAddition(addition)}
                        className={`p-2 rounded-xl text-xs flex items-center justify-between cursor-pointer border transition-all ${
                          isSelected
                            ? 'bg-slate-900 text-white border-slate-900 font-bold'
                            : 'bg-slate-50 hover:bg-slate-100 text-slate-700 border-slate-200'
                        }`}
                      >
                        <div className="flex items-center gap-2">
                          <div
                            className={`w-4 h-4 rounded-md flex items-center justify-center border text-[10px] ${
                              isSelected
                                ? 'bg-pink-500 border-pink-500 text-white'
                                : 'bg-white border-slate-300'
                            }`}
                          >
                            {isSelected && <Check className="w-3 h-3 stroke-[3]" />}
                          </div>
                          <span>{addition.name}</span>
                        </div>
                        <span className={isSelected ? 'text-pink-300' : 'text-slate-500 font-semibold'}>
                          +₱{addition.price.toFixed(2)}
                        </span>
                      </div>
                    );
                  })}
                </div>
              </div>
            )}
          </div>

          {/* Bottom Actions: Quantity & Add to Order Button */}
          <div className="pt-3 border-t border-slate-100 flex items-center justify-between gap-3">
            {/* Quantity Selector */}
            <div className="flex items-center gap-2 bg-slate-100 p-1 rounded-xl">
              <button
                onClick={() => setQuantity((q) => Math.max(1, q - 1))}
                className="w-7 h-7 rounded-lg bg-white hover:bg-slate-200 text-slate-800 flex items-center justify-center font-bold text-xs transition-colors cursor-pointer"
              >
                <Minus className="w-3 h-3" />
              </button>
              <span className="w-6 text-center text-xs font-bold text-slate-900">{quantity}</span>
              <button
                onClick={() => setQuantity((q) => q + 1)}
                className="w-7 h-7 rounded-lg bg-white hover:bg-slate-200 text-slate-800 flex items-center justify-center font-bold text-xs transition-colors cursor-pointer"
              >
                <Plus className="w-3 h-3" />
              </button>
            </div>

            {/* Add to Order Button */}
            <button
              onClick={() => {
                onAddToCart(dish, quantity, selectedAdditions);
                onClose();
              }}
              className="flex-1 py-3 px-4 rounded-xl bg-slate-900 hover:bg-slate-800 text-white font-bold text-xs shadow-md transition-all flex items-center justify-between active:scale-95 cursor-pointer"
            >
              <span>Add to order</span>
              <span>₱{totalPrice.toFixed(2)}</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
