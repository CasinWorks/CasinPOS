import React, { useState } from 'react';
import { RetailProduct, RetailCategory } from '../types';
import { Search, Plus, AlertTriangle, ArrowUpDown, Package, DollarSign, Barcode, Check, X } from 'lucide-react';

interface RetailInventoryViewProps {
  products: RetailProduct[];
  onRestockProduct: (productId: string, delta: number) => void;
  onAddProduct: (product: RetailProduct) => void;
}

export const RetailInventoryView: React.FC<RetailInventoryViewProps> = ({
  products,
  onRestockProduct,
  onAddProduct,
}) => {
  const [selectedCategory, setSelectedCategory] = useState<RetailCategory>('All');
  const [searchQuery, setSearchQuery] = useState('');
  const [onlyLowStock, setOnlyLowStock] = useState(false);
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);

  // New product form state
  const [newName, setNewName] = useState('');
  const [newSku, setNewSku] = useState(`PM-M00${products.length + 1}`);
  const [newCategory, setNewCategory] = useState<RetailCategory>('Pork');
  const [newPrice, setNewPrice] = useState(88);
  const [newCostPrice, setNewCostPrice] = useState(60);
  const [newWeight, setNewWeight] = useState('500g Frozen Pack');
  const [newStock, setNewStock] = useState(30);

  const categories: RetailCategory[] = [
    'All',
    'Beef',
    'Pork',
    'Chicken',
    'Deli & Sausages',
    'Marinated BBQ',
    'Seafood Packs',
  ];

  // Filters
  const filtered = products.filter((p) => {
    const matchesCat = selectedCategory === 'All' || p.category === selectedCategory;
    const matchesSearch =
      p.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      p.sku.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesLowStock = !onlyLowStock || p.stock <= p.lowStockThreshold;
    return matchesCat && matchesSearch && matchesLowStock;
  });

  const totalStockCount = products.reduce((sum, p) => sum + p.stock, 0);
  const totalValuation = products.reduce((sum, p) => sum + p.stock * p.price, 0);

  const handleCreateProduct = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newName.trim()) return;

    const newProd: RetailProduct = {
      id: `meat-${Date.now()}`,
      sku: newSku || `PM-${Math.floor(100 + Math.random() * 900)}`,
      name: newName,
      category: newCategory,
      price: newPrice,
      costPrice: newCostPrice,
      weight: newWeight,
      stock: newStock,
      lowStockThreshold: 10,
      image: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&q=80&w=800',
      description: `Store packaged meat variety. Default ₱${newPrice} per pack.`,
      barcode: `48065123400${products.length + 1}`,
    };

    onAddProduct(newProd);
    setIsAddModalOpen(false);
    setNewName('');
  };

  return (
    <div className="flex-1 bg-white p-5 overflow-y-auto space-y-5 select-none">
      {/* Top Header & Inventory Stats */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="text-sm font-extrabold tracking-tight text-slate-900 flex items-center gap-2">
            <Package className="w-4 h-4 text-pink-600" />
            <span>Packaged Meats Inventory Master</span>
          </h2>
          <p className="text-xs text-slate-400">
            Track stock counts, cost prices & restock packaged meat varieties
          </p>
        </div>

        <button
          onClick={() => setIsAddModalOpen(true)}
          className="px-3.5 py-2 rounded-xl font-bold text-xs bg-slate-900 hover:bg-slate-800 text-white shadow-sm transition-all flex items-center gap-1.5 active:scale-95 cursor-pointer"
        >
          <Plus className="w-4 h-4" />
          <span>Add Meat Variety</span>
        </button>
      </div>

      {/* Inventory Valuation Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <div className="bg-[#f8f9fa] rounded-2xl p-3.5 border border-slate-200/80">
          <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
            Total Products Tracked
          </span>
          <span className="text-base font-black text-slate-900 mt-1 block">
            {products.length} Varieties
          </span>
        </div>

        <div className="bg-[#f8f9fa] rounded-2xl p-3.5 border border-slate-200/80">
          <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
            Total Units in Freezer Stock
          </span>
          <span className="text-base font-black text-slate-900 mt-1 block">
            {totalStockCount} Packs
          </span>
        </div>

        <div className="bg-[#f8f9fa] rounded-2xl p-3.5 border border-slate-200/80">
          <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
            Total Inventory Retail Value
          </span>
          <span className="text-base font-black text-pink-600 mt-1 block">
            ₱{totalValuation.toLocaleString('en-US', { minimumFractionDigits: 2 })}
          </span>
        </div>
      </div>

      {/* Filter Bar */}
      <div className="space-y-2">
        <div className="flex items-center gap-2">
          <div className="relative flex-1">
            <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search product name or SKU..."
              className="w-full pl-8 pr-3 py-2 rounded-xl text-xs font-semibold bg-[#f1f1f1] focus:bg-white border border-transparent focus:border-slate-300 text-slate-900 focus:outline-none"
            />
          </div>

          <button
            onClick={() => setOnlyLowStock(!onlyLowStock)}
            className={`px-3 py-2 rounded-xl text-xs font-bold flex items-center gap-1.5 border transition-all shrink-0 ${
              onlyLowStock
                ? 'bg-rose-500 text-white border-rose-600 shadow-xs'
                : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-50'
            }`}
          >
            <AlertTriangle className="w-3.5 h-3.5" />
            <span>Low Stock Only</span>
          </button>
        </div>

        {/* Category Pills */}
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 scrollbar-none">
          {categories.map((cat) => (
            <button
              key={cat}
              onClick={() => setSelectedCategory(cat)}
              className={`px-3 py-1.5 rounded-xl font-bold text-xs transition-all shrink-0 cursor-pointer ${
                selectedCategory === cat
                  ? 'bg-slate-900 text-white'
                  : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
              }`}
            >
              {cat}
            </button>
          ))}
        </div>
      </div>

      {/* Products Table / List */}
      <div className="space-y-2">
        {filtered.map((item) => {
          const isLow = item.stock <= item.lowStockThreshold;

          return (
            <div
              key={item.id}
              className={`p-3 rounded-2xl border transition-all flex items-center justify-between ${
                isLow ? 'bg-rose-500/5 border-rose-200' : 'bg-[#f8f9fa] border-slate-200/70'
              }`}
            >
              <div className="flex items-center gap-3 min-w-0 pr-2">
                <img
                  src={item.image}
                  alt={item.name}
                  className="w-12 h-12 rounded-xl object-cover border border-slate-200 shrink-0"
                />

                <div className="min-w-0">
                  <div className="flex items-center gap-2">
                    <h4 className="text-xs font-bold text-slate-900 truncate">{item.name}</h4>
                    <span className="text-[9px] px-1.5 py-0.5 rounded bg-slate-200 text-slate-600 font-bold shrink-0">
                      {item.category}
                    </span>
                  </div>

                  <div className="flex items-center gap-2 text-[10px] text-slate-400 mt-0.5 font-medium">
                    <span>SKU: {item.sku}</span>
                    <span>•</span>
                    <span>Cost: ₱{item.costPrice}</span>
                    <span>•</span>
                    <span className="font-bold text-pink-600">Price: ₱{item.price}</span>
                  </div>
                </div>
              </div>

              {/* Stock adjustment */}
              <div className="flex items-center gap-3 shrink-0">
                <div className="text-right">
                  <div className="flex items-center justify-end gap-1">
                    <span
                      className={`text-xs font-black ${
                        isLow ? 'text-rose-600' : 'text-slate-900'
                      }`}
                    >
                      {item.stock} in freezer
                    </span>
                    {isLow && <AlertTriangle className="w-3.5 h-3.5 text-rose-500 animate-bounce" />}
                  </div>
                  <p className="text-[9px] text-slate-400">Alert @ ≤{item.lowStockThreshold}</p>
                </div>

                <div className="flex items-center gap-1">
                  <button
                    onClick={() => onRestockProduct(item.id, -1)}
                    className="w-7 h-7 rounded-lg bg-slate-200 hover:bg-slate-300 text-slate-800 font-bold text-xs flex items-center justify-center transition-colors cursor-pointer"
                  >
                    -
                  </button>
                  <button
                    onClick={() => onRestockProduct(item.id, 10)}
                    className="px-2.5 py-1 rounded-lg bg-slate-900 hover:bg-slate-800 text-white font-bold text-[10px] shadow-xs transition-all active:scale-95 cursor-pointer"
                  >
                    +10 Restock
                  </button>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* Add Product Modal */}
      {isAddModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 backdrop-blur-xs p-4">
          <div className="bg-white rounded-3xl p-6 max-w-md w-full shadow-2xl border border-slate-100 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-sm font-extrabold text-slate-900">Add New Packaged Meat</h3>
              <button
                onClick={() => setIsAddModalOpen(false)}
                className="text-slate-400 hover:text-slate-600 p-1"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleCreateProduct} className="space-y-3 text-xs">
              <div>
                <label className="block text-[10px] font-bold text-slate-400 uppercase mb-1">
                  Product Name
                </label>
                <input
                  type="text"
                  required
                  value={newName}
                  onChange={(e) => setNewName(e.target.value)}
                  placeholder="e.g. Premium Beef Marinated Bulgogi"
                  className="w-full p-2.5 rounded-xl border border-slate-200 font-semibold focus:outline-none focus:ring-1 focus:ring-slate-900"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-[10px] font-bold text-slate-400 uppercase mb-1">
                    SKU Code
                  </label>
                  <input
                    type="text"
                    value={newSku}
                    onChange={(e) => setNewSku(e.target.value)}
                    className="w-full p-2.5 rounded-xl border border-slate-200 font-semibold"
                  />
                </div>

                <div>
                  <label className="block text-[10px] font-bold text-slate-400 uppercase mb-1">
                    Category Variety
                  </label>
                  <select
                    value={newCategory}
                    onChange={(e) => setNewCategory(e.target.value as RetailCategory)}
                    className="w-full p-2.5 rounded-xl border border-slate-200 font-semibold"
                  >
                    <option value="Beef">Beef</option>
                    <option value="Pork">Pork</option>
                    <option value="Chicken">Chicken</option>
                    <option value="Deli & Sausages">Deli & Sausages</option>
                    <option value="Marinated BBQ">Marinated BBQ</option>
                    <option value="Seafood Packs">Seafood Packs</option>
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-3 gap-3">
                <div>
                  <label className="block text-[10px] font-bold text-slate-400 uppercase mb-1">
                    Retail Price (₱)
                  </label>
                  <input
                    type="number"
                    value={newPrice}
                    onChange={(e) => setNewPrice(Number(e.target.value))}
                    className="w-full p-2.5 rounded-xl border border-slate-200 font-semibold"
                  />
                </div>

                <div>
                  <label className="block text-[10px] font-bold text-slate-400 uppercase mb-1">
                    Cost Price (₱)
                  </label>
                  <input
                    type="number"
                    value={newCostPrice}
                    onChange={(e) => setNewCostPrice(Number(e.target.value))}
                    className="w-full p-2.5 rounded-xl border border-slate-200 font-semibold"
                  />
                </div>

                <div>
                  <label className="block text-[10px] font-bold text-slate-400 uppercase mb-1">
                    Initial Stock
                  </label>
                  <input
                    type="number"
                    value={newStock}
                    onChange={(e) => setNewStock(Number(e.target.value))}
                    className="w-full p-2.5 rounded-xl border border-slate-200 font-semibold"
                  />
                </div>
              </div>

              <div>
                <label className="block text-[10px] font-bold text-slate-400 uppercase mb-1">
                  Pack Weight / Label
                </label>
                <input
                  type="text"
                  value={newWeight}
                  onChange={(e) => setNewWeight(e.target.value)}
                  placeholder="e.g. 500g Frozen Pack"
                  className="w-full p-2.5 rounded-xl border border-slate-200 font-semibold"
                />
              </div>

              <div className="pt-2 flex justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setIsAddModalOpen(false)}
                  className="px-4 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-xl bg-slate-900 hover:bg-slate-800 text-white font-bold text-xs shadow-md"
                >
                  Save Product
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
