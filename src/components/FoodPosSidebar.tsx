import React from 'react';
import { NavTab, StaffProfile, BusinessType } from '../types';
import {
  Coffee,
  LayoutGrid,
  UtensilsCrossed,
  Bookmark,
  Calendar,
  Receipt,
  Bell,
  HelpCircle,
  Sparkles,
  ShoppingBag,
  PackageCheck,
  Store,
  TrendingUp,
} from 'lucide-react';

interface FoodPosSidebarProps {
  businessType: BusinessType;
  onChangeBusinessType: (type: BusinessType) => void;
  activeTab: NavTab;
  onSelectTab: (tab: NavTab) => void;
  staffProfile: StaffProfile;
  onOpenProfileModal?: () => void;
  onReplayIntro?: () => void;
  orderCount?: number;
}

export const FoodPosSidebar: React.FC<FoodPosSidebarProps> = ({
  businessType,
  onChangeBusinessType,
  activeTab,
  onSelectTab,
  staffProfile,
  onOpenProfileModal,
  onReplayIntro,
  orderCount = 3,
}) => {
  // Navigation items based on business mode
  const restaurantNavItems: { id: NavTab; label: string; icon: React.ReactNode }[] = [
    { id: 'floor_plan', label: 'Floor plan', icon: <LayoutGrid className="w-4 h-4" /> },
    { id: 'dishes', label: 'Dishes Menu', icon: <UtensilsCrossed className="w-4 h-4" /> },
    { id: 'orders', label: 'Active Orders', icon: <Bookmark className="w-4 h-4" /> },
    { id: 'bookings', label: 'Table Bookings', icon: <Calendar className="w-4 h-4" /> },
    { id: 'receipts', label: 'Receipts', icon: <Receipt className="w-4 h-4" /> },
    { id: 'analytics', label: 'Sales Statistics', icon: <TrendingUp className="w-4 h-4" /> },
  ];

  const retailNavItems: { id: NavTab; label: string; icon: React.ReactNode }[] = [
    { id: 'checkout', label: 'Meats POS (₱88)', icon: <ShoppingBag className="w-4 h-4" /> },
    { id: 'inventory', label: 'Store Inventory', icon: <PackageCheck className="w-4 h-4" /> },
    { id: 'orders', label: 'Sales History', icon: <Bookmark className="w-4 h-4" /> },
    { id: 'receipts', label: 'Receipts Audit', icon: <Receipt className="w-4 h-4" /> },
    { id: 'analytics', label: 'Sales Statistics', icon: <TrendingUp className="w-4 h-4" /> },
  ];

  const mainNavItems = businessType === 'restaurant' ? restaurantNavItems : retailNavItems;

  const otherNavItems: { id: NavTab; label: string; icon: React.ReactNode }[] = [
    { id: 'notifications', label: 'Notifications', icon: <Bell className="w-4 h-4" /> },
    { id: 'support', label: 'Support', icon: <HelpCircle className="w-4 h-4" /> },
  ];

  return (
    <aside className="w-60 shrink-0 bg-[#f8f9fa] border-r border-slate-200/80 p-4 flex flex-col justify-between h-full select-none">
      {/* Top Brand Logo, Business Switcher & Navigation */}
      <div className="space-y-4">
        {/* Brand Header & Intro trigger */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <div
              className={`w-9 h-9 rounded-xl text-white flex items-center justify-center shadow-sm shrink-0 transition-colors ${
                businessType === 'restaurant' ? 'bg-pink-500' : 'bg-slate-900'
              }`}
            >
              {businessType === 'restaurant' ? (
                <Coffee className="w-5 h-5 fill-current" />
              ) : (
                <Store className="w-5 h-5" />
              )}
            </div>
            <span className="text-xl font-extrabold tracking-tight text-slate-900 font-serif italic">
              {businessType === 'restaurant' ? 'Food' : 'Meat'}
              <span className="not-italic font-sans text-slate-900">Pos</span>
            </span>
          </div>

          {onReplayIntro && (
            <button
              onClick={onReplayIntro}
              title="Replay Liquid Ink Intro"
              className="p-1.5 rounded-lg text-slate-400 hover:text-slate-700 hover:bg-slate-200/60 transition-colors cursor-pointer"
            >
              <Sparkles className="w-4 h-4 text-pink-500" />
            </button>
          )}
        </div>

        {/* Business Mode Switcher Switch / Toggle Pill */}
        <div className="bg-slate-200/70 p-1 rounded-2xl flex items-center gap-1 border border-slate-300/50">
          <button
            onClick={() => {
              onChangeBusinessType('restaurant');
              onSelectTab('dishes');
            }}
            className={`flex-1 py-1.5 rounded-xl text-[11px] font-bold transition-all flex items-center justify-center gap-1 cursor-pointer ${
              businessType === 'restaurant'
                ? 'bg-white text-slate-900 shadow-sm'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <UtensilsCrossed className="w-3 h-3" />
            <span>Restaurant</span>
          </button>

          <button
            onClick={() => {
              onChangeBusinessType('retail');
              onSelectTab('checkout');
            }}
            className={`flex-1 py-1.5 rounded-xl text-[11px] font-bold transition-all flex items-center justify-center gap-1 cursor-pointer ${
              businessType === 'retail'
                ? 'bg-slate-900 text-amber-300 shadow-sm'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <Store className="w-3 h-3" />
            <span>Retail (₱88)</span>
          </button>
        </div>

        {/* Active Business Mode Label Badge */}
        <div className="px-2.5 py-1 rounded-xl bg-slate-100 border border-slate-200 text-[10px] text-slate-500 font-semibold flex items-center justify-between">
          <span>Active Store:</span>
          <span className="font-extrabold text-slate-900">
            {businessType === 'restaurant' ? 'Dine-In Restaurant' : 'Packaged Meats Store'}
          </span>
        </div>

        {/* Main Menu Links */}
        <nav className="space-y-1">
          {mainNavItems.map((item) => {
            const isActive = activeTab === item.id;

            return (
              <button
                key={item.id}
                onClick={() => onSelectTab(item.id)}
                className={`w-full flex items-center gap-3 px-3.5 py-2.5 rounded-2xl text-xs font-bold transition-all text-left cursor-pointer ${
                  isActive
                    ? 'bg-slate-900 text-white shadow-md shadow-slate-900/10'
                    : 'text-slate-600 hover:text-slate-900 hover:bg-slate-200/50 font-medium'
                }`}
              >
                <span className={isActive ? 'text-white' : 'text-slate-500'}>{item.icon}</span>
                <span className="flex-1">{item.label}</span>
                {item.id === 'orders' && orderCount > 0 && (
                  <span
                    className={`px-1.5 py-0.5 rounded-full text-[10px] font-bold ${
                      isActive ? 'bg-pink-500 text-white' : 'bg-slate-200 text-slate-700'
                    }`}
                  >
                    {orderCount}
                  </span>
                )}
              </button>
            );
          })}
        </nav>

        {/* Section: Other */}
        <div className="pt-2 border-t border-slate-200/60 space-y-1">
          <p className="px-3.5 text-[10px] font-bold tracking-wider text-slate-400 uppercase mb-1">
            System
          </p>
          {otherNavItems.map((item) => {
            const isActive = activeTab === item.id;

            return (
              <button
                key={item.id}
                onClick={() => onSelectTab(item.id)}
                className={`w-full flex items-center gap-3 px-3.5 py-2.5 rounded-2xl text-xs transition-all text-left cursor-pointer ${
                  isActive
                    ? 'bg-slate-900 text-white font-bold shadow-md'
                    : 'text-slate-600 hover:text-slate-900 hover:bg-slate-200/50 font-medium'
                }`}
              >
                <span className={isActive ? 'text-white' : 'text-slate-500'}>{item.icon}</span>
                <span>{item.label}</span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Staff Profile Card at Bottom */}
      <div className="bg-slate-100/90 rounded-2xl p-3 border border-slate-200/70 text-center space-y-2">
        <div className="relative inline-block">
          <img
            src={staffProfile.avatar}
            alt={staffProfile.name}
            className="w-12 h-12 rounded-2xl object-cover border-2 border-white shadow-sm mx-auto"
          />
          <span className="w-3 h-3 rounded-full bg-emerald-500 border-2 border-white absolute bottom-0 right-0" />
        </div>

        <div>
          <h4 className="text-xs font-bold text-slate-900">{staffProfile.name}</h4>
          <p className="text-[10px] text-slate-500 font-medium">{staffProfile.role}</p>
        </div>

        <button
          onClick={onOpenProfileModal}
          className="w-full py-1.5 rounded-xl bg-slate-900 hover:bg-slate-800 text-white text-[10px] font-bold transition-all shadow-xs active:scale-95 cursor-pointer"
        >
          Manage Profile
        </button>
      </div>
    </aside>
  );
};
