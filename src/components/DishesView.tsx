import React, { useState } from 'react';
import { DishItem, Category } from '../types';
import { Search, ChevronLeft, ChevronRight, UtensilsCrossed, Coffee, Sandwich, Soup, Cookie } from 'lucide-react';

interface DishesViewProps {
  dishes: DishItem[];
  selectedCategory: Category;
  onSelectCategory: (cat: Category) => void;
  onSelectDish: (dish: DishItem) => void;
  onViewAllPopular?: () => void;
}

export const DishesView: React.FC<DishesViewProps> = ({
  dishes,
  selectedCategory,
  onSelectCategory,
  onSelectDish,
  onViewAllPopular,
}) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [popularScrollIndex, setPopularScrollIndex] = useState(0);

  // Category Configuration matching the reference photo
  const categoryPills: { id: Category; label: string; bg: string; text: string; icon: React.ReactNode }[] = [
    {
      id: 'Breakfast',
      label: 'Breakfast',
      bg: 'bg-[#fdeed9]',
      text: 'text-amber-900',
      icon: <Coffee className="w-3.5 h-3.5 text-amber-800" />,
    },
    {
      id: 'Lunch',
      label: 'Lunch',
      bg: 'bg-[#f0f0f0]',
      text: 'text-slate-800',
      icon: <UtensilsCrossed className="w-3.5 h-3.5 text-slate-800" />,
    },
    {
      id: 'Pastry',
      label: 'Pastry',
      bg: 'bg-[#fce4ec]',
      text: 'text-pink-900',
      icon: <Sandwich className="w-3.5 h-3.5 text-pink-800" />,
    },
    {
      id: 'Soups',
      label: 'Soups',
      bg: 'bg-[#e8f5e9]',
      text: 'text-emerald-900',
      icon: <Soup className="w-3.5 h-3.5 text-emerald-800" />,
    },
    {
      id: 'Bowls',
      label: 'Bowls',
      bg: 'bg-[#e8eaf6]',
      text: 'text-indigo-900',
      icon: <UtensilsCrossed className="w-3.5 h-3.5 text-indigo-800" />,
    },
    {
      id: 'Burgers',
      label: 'Burgers',
      bg: 'bg-[#ffe0b2]',
      text: 'text-orange-900',
      icon: <UtensilsCrossed className="w-3.5 h-3.5 text-orange-800" />,
    },
    {
      id: 'Desserts',
      label: 'Desserts',
      bg: 'bg-[#f3e5f5]',
      text: 'text-purple-900',
      icon: <Cookie className="w-3.5 h-3.5 text-purple-800" />,
    },
  ];

  // Filter dishes by search and category
  const filteredDishes = dishes.filter((dish) => {
    const matchesSearch =
      dish.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      dish.category.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesCategory = selectedCategory === 'All' || dish.category === selectedCategory;
    return matchesSearch && matchesCategory;
  });

  const popularDishes = dishes.filter((d) => d.popular);

  const handlePopularNext = () => {
    if (popularScrollIndex < popularDishes.length - 2) {
      setPopularScrollIndex((prev) => prev + 1);
    }
  };

  const handlePopularPrev = () => {
    if (popularScrollIndex > 0) {
      setPopularScrollIndex((prev) => prev - 1);
    }
  };

  return (
    <div className="flex-1 bg-white p-5 overflow-y-auto space-y-6">
      {/* 1. Top Search Bar */}
      <div className="relative w-full">
        <Search className="w-4 h-4 text-slate-400 absolute left-4 top-1/2 -translate-y-1/2" />
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="Search dish name or ingredient"
          className="w-full bg-[#f1f1f1]/90 hover:bg-[#f1f1f1] focus:bg-white focus:ring-2 focus:ring-slate-900 focus:outline-none pl-11 pr-4 py-3 rounded-2xl text-xs font-medium text-slate-800 placeholder:text-slate-400 transition-all border border-transparent focus:border-slate-300 shadow-xs"
        />
      </div>

      {/* 2. Category Filter Pills */}
      <div className="flex items-center gap-2.5 overflow-x-auto pb-1 scrollbar-none">
        {categoryPills.map((pill) => {
          const isSelected = selectedCategory === pill.id;

          return (
            <button
              key={pill.id}
              onClick={() => onSelectCategory(isSelected ? 'All' : pill.id)}
              className={`px-4 py-2.5 rounded-2xl text-xs font-bold transition-all flex items-center gap-2 shrink-0 active:scale-95 cursor-pointer ${
                isSelected
                  ? 'bg-slate-900 text-white shadow-md'
                  : `${pill.bg} ${pill.text} hover:opacity-90`
              }`}
            >
              <span className={isSelected ? 'text-white' : ''}>{pill.icon}</span>
              <span>{pill.label}</span>
            </button>
          );
        })}
      </div>

      {/* 3. Section: Popular (Carousel matching photo) */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-extrabold text-slate-900 tracking-tight">Popular</h3>
          <button
            onClick={onViewAllPopular}
            className="text-xs font-bold text-slate-400 hover:text-slate-700 transition-colors"
          >
            View All
          </button>
        </div>

        {/* Carousel Container with Overlay Left/Right Arrow Buttons */}
        <div className="relative group">
          {/* Left Arrow Button */}
          {popularScrollIndex > 0 && (
            <button
              onClick={handlePopularPrev}
              className="absolute left-1 top-1/2 -translate-y-1/2 z-10 w-9 h-9 rounded-full bg-white/90 hover:bg-white text-slate-800 shadow-lg flex items-center justify-center border border-slate-200 transition-all active:scale-90"
            >
              <ChevronLeft className="w-5 h-5" />
            </button>
          )}

          {/* Right Arrow Button */}
          {popularScrollIndex < popularDishes.length - 2 && (
            <button
              onClick={handlePopularNext}
              className="absolute right-1 top-1/2 -translate-y-1/2 z-10 w-9 h-9 rounded-full bg-white/90 hover:bg-white text-slate-800 shadow-lg flex items-center justify-center border border-slate-200 transition-all active:scale-90"
            >
              <ChevronRight className="w-5 h-5" />
            </button>
          )}

          {/* Popular Cards Grid */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3.5">
            {popularDishes.slice(popularScrollIndex, popularScrollIndex + 4).map((dish) => (
              <div
                key={dish.id}
                onClick={() => onSelectDish(dish)}
                className="bg-[#f8f9fa] hover:bg-[#f1f3f5] rounded-3xl p-3 transition-all cursor-pointer border border-slate-100 flex flex-col justify-between group active:scale-[0.98]"
              >
                <div>
                  <div className="overflow-hidden rounded-2xl mb-2.5 h-32 w-full">
                    <img
                      src={dish.image}
                      alt={dish.name}
                      className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                    />
                  </div>

                  <h4 className="text-xs font-bold text-slate-900 line-clamp-2 leading-snug mb-1">
                    {dish.name}
                  </h4>
                </div>

                <div className="flex items-center justify-between text-[11px] mt-2 pt-2 border-t border-slate-200/50">
                  <span className="font-extrabold text-slate-900">
                    €{dish.price.toFixed(2)}
                  </span>
                  <span className="text-slate-400 font-medium text-[10px]">
                    {dish.weight}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* 4. Section: Selected Category / Main Dishes List */}
      <div className="space-y-3 pt-2">
        <h3 className="text-sm font-extrabold text-slate-900 tracking-tight">
          {selectedCategory === 'All' ? 'Lunch' : selectedCategory}
        </h3>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {filteredDishes.length === 0 ? (
            <div className="col-span-2 py-10 text-center text-xs text-slate-400">
              No dishes found matching your search.
            </div>
          ) : (
            filteredDishes.map((dish) => (
              <div
                key={dish.id}
                onClick={() => onSelectDish(dish)}
                className="bg-[#f8f9fa] hover:bg-[#f1f3f5] rounded-3xl p-3.5 transition-all cursor-pointer border border-slate-100 flex gap-3 group active:scale-[0.98]"
              >
                <img
                  src={dish.image}
                  alt={dish.name}
                  className="w-28 h-28 rounded-2xl object-cover shrink-0 group-hover:scale-105 transition-transform duration-300"
                />

                <div className="flex flex-col justify-between flex-1 py-0.5">
                  <div>
                    <h4 className="text-xs font-bold text-slate-900 leading-tight mb-1.5 line-clamp-2">
                      {dish.name}
                    </h4>
                    {dish.description && (
                      <p className="text-[10px] text-slate-500 line-clamp-2 leading-relaxed">
                        {dish.description}
                      </p>
                    )}
                  </div>

                  <div className="flex items-center justify-between text-xs mt-2 pt-2 border-t border-slate-200/50">
                    <span className="font-extrabold text-slate-900">
                      ₱{dish.price.toFixed(2)}
                    </span>
                    <span className="text-slate-400 font-medium text-[10px]">
                      {dish.weight}
                    </span>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
};
