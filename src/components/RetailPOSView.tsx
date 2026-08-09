import React, { useState } from 'react';
import { RetailProduct, RetailCategory } from '../types';
import { Search, Plus, AlertTriangle, PackageCheck, Barcode, Check, ShoppingBag, Flame, Sparkles } from 'lucide-react';

interface RetailPOSViewProps {
  products: RetailProduct[];
  selectedCategory: RetailCategory;
  onSelectCategory: (cat: RetailCategory) => void;
  onAddToCart: (product: RetailProduct) => void;
  onOpenAddProductModal: () => void;
  onNavigateToInventory: () => void;
}

export const RetailPOSView: React.FC<RetailPOSViewProps> = ({
  products,
  selectedCategory,
  onSelectCategory,
  onAddToCart,
  onOpenAddProductModal,
  onNavigateToInventory,
}) => {
  const [searchQuery, setSearchQuery] = useState('');

  const categories: RetailCategory[] = [
    'All',
    'Beef',
    'Pork',
    'Chicken',
    'Deli & Sausages',
    'Marinated BBQ',
    'Seafood Packs',
  ];

  const filteredProducts = products.filter((p) => {
    const matchesSearch =
      p.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      p.sku.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (p.barcode && p.barcode.includes(searchQuery));
    const matchesCat = selectedCategory === 'All' || p.category === selectedCategory;
    return matchesSearch && matchesCat;
  });

  return (
    <div className="flex-1 bg-white p-5 overflow-y-auto space-y-5 select-none">
      {/* Top Banner & Mode Info */}
      <div className="flex items-center justify-between bg-gradient-to-r from-slate-900 via-indigo-950 to-slate-900 text-white p-4 rounded-3xl shadow-sm">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-2xl bg-amber-500 text-slate-950 font-black flex items-center justify-center text-sm shadow-md">
            ₱88
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h2 className="text-sm font-extrabold tracking-tight">Packaged Meats Retail Store</h2>
              <span className="px-2 py-0.5 rounded-full bg-amber-400/20 text-amber-300 font-bold text-[10px] border border-amber-400/30 flex items-center gap-1">
                <Sparkles className="w-3 h-3" /> Flat ₱88 Variety Store
              </span>
            </div>
            <p className="text-[11px] text-slate-300 mt-0.5">
              Quick barcode/SKU checkout for frozen packs, sausages, samgyupsal & marinated cuts
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={onNavigateToInventory}
            className="px-3.5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-bold transition-all border border-slate-700 flex items-center gap-1.5 cursor-pointer active:scale-95"
          >
            <PackageCheck className="w-4 h-4 text-emerald-400" />
            <span>Store Inventory</span>
          </button>

          <button
            onClick={onOpenAddProductModal}
            className="px-3.5 py-2 rounded-xl bg-pink-600 hover:bg-pink-700 text-white text-xs font-bold transition-all shadow-md flex items-center gap-1.5 cursor-pointer active:scale-95"
          >
            <Plus className="w-4 h-4" />
            <span>Add Meat Pack</span>
          </button>
        </div>
      </div>

      {/* Search & Category Pills */}
      <div className="space-y-3">
        <div className="relative">
          <Search className="w-4 h-4 text-slate-400 absolute left-4 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Scan barcode, SKU (e.g. PM-B001) or product name..."
            className="w-full bg-[#f1f1f1]/90 hover:bg-[#f1f1f1] focus:bg-white focus:ring-2 focus:ring-slate-900 focus:outline-none pl-11 pr-4 py-3 rounded-2xl text-xs font-semibold text-slate-800 placeholder:text-slate-400 transition-all border border-transparent focus:border-slate-300 shadow-2xs"
          />
        </div>

        <div className="flex items-center gap-2 overflow-x-auto pb-1 scrollbar-none">
          {categories.map((cat) => {
            const isSelected = selectedCategory === cat;

            return (
              <button
                key={cat}
                onClick={() => onSelectCategory(cat)}
                className={`px-3.5 py-2 rounded-2xl text-xs font-bold transition-all shrink-0 cursor-pointer active:scale-95 ${
                  isSelected
                    ? 'bg-slate-900 text-white shadow-md'
                    : 'bg-[#f0f0f0] text-slate-700 hover:bg-slate-200'
                }`}
              >
                {cat}
              </button>
            );
          })}
        </div>
      </div>

      {/* Packaged Meats Grid */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {filteredProducts.length === 0 ? (
          <div className="col-span-4 py-12 text-center text-xs text-slate-400">
            No packaged meat products found matching filter.
          </div>
        ) : (
          filteredProducts.map((product) => {
            const isLowStock = product.stock <= product.lowStockThreshold;

            return (
              <div
                key={product.id}
                onClick={() => onAddToCart(product)}
                className={`bg-[#f8f9fa] hover:bg-[#f1f3f5] rounded-3xl p-3 border transition-all cursor-pointer flex flex-col justify-between group active:scale-[0.98] relative ${
                  isLowStock ? 'border-amber-300/80 bg-amber-50/20' : 'border-slate-100'
                }`}
              >
                {/* Flat Price Tag Overlay */}
                <div className="absolute top-4 left-4 z-10 px-2.5 py-1 rounded-full bg-slate-900/90 backdrop-blur-xs text-white text-xs font-black shadow-md flex items-center gap-0.5">
                  <span>₱{product.price.toFixed(0)}</span>
                </div>

                <div>
                  <div className="overflow-hidden rounded-2xl mb-2.5 h-36 w-full relative">
                    <img
                      src={product.image}
                      alt={product.name}
                      className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                    />
                  </div>

                  <div className="space-y-1">
                    <div className="flex items-center justify-between">
                      <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wide">
                        {product.sku}
                      </span>
                      <span className="text-[10px] font-bold text-slate-500 bg-slate-200/60 px-1.5 py-0.5 rounded-md">
                        {product.weight}
                      </span>
                    </div>

                    <h4 className="text-xs font-bold text-slate-900 line-clamp-2 leading-snug">
                      {product.name}
                    </h4>
                  </div>
                </div>

                <div className="pt-2.5 mt-2 border-t border-slate-200/60 flex items-center justify-between">
                  {/* Stock status */}
                  <div className="flex items-center gap-1">
                    <span
                      className={`text-[10px] font-extrabold ${
                        isLowStock ? 'text-rose-600' : 'text-emerald-700'
                      }`}
                    >
                      {product.stock} in stock
                    </span>
                    {isLowStock && (
                      <AlertTriangle className="w-3 h-3 text-amber-500 animate-pulse" />
                    )}
                  </div>

                  <button className="px-2.5 py-1 rounded-xl bg-slate-900 group-hover:bg-pink-600 text-white font-bold text-[10px] transition-colors shadow-2xs flex items-center gap-1">
                    <Plus className="w-3 h-3" /> Add
                  </button>
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};
