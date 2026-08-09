import React, { useState } from 'react';
import {
  NavTab,
  Category,
  RetailCategory,
  DishItem,
  RetailProduct,
  CartItem,
  SelectedAddition,
  Order,
  Table,
  BusinessType,
} from './types';
import {
  INITIAL_DISHES,
  INITIAL_RETAIL_MEATS,
  INITIAL_TABLES,
  INITIAL_ORDERS,
  INITIAL_BOOKINGS,
  STAFF_PROFILE,
} from './mockData';

import { FluidInkIntro } from './components/FluidInkIntro';
import { IPadFrame } from './components/IPadFrame';
import { FoodPosSidebar } from './components/FoodPosSidebar';
import { DishesView } from './components/DishesView';
import { DishDetailModal } from './components/DishDetailModal';
import { RetailPOSView } from './components/RetailPOSView';
import { RetailInventoryView } from './components/RetailInventoryView';
import { CartTray } from './components/CartTray';
import { FloorPlanView } from './components/FloorPlanView';
import { OrdersView } from './components/OrdersView';
import { BookingsView } from './components/BookingsView';
import { ReceiptsView } from './components/ReceiptsView';
import { AnalyticsView } from './components/AnalyticsView';

export function App() {
  const [showIntroAnimation, setShowIntroAnimation] = useState(true);
  const [viewMode, setViewMode] = useState<'ipad' | 'fullscreen'>('ipad');
  
  // Multi-Business State
  const [businessType, setBusinessType] = useState<BusinessType>('restaurant');
  const [activeTab, setActiveTab] = useState<NavTab>('dishes');

  // Restaurant State
  const [selectedCategory, setSelectedCategory] = useState<Category>('Lunch');
  const [selectedDishForDetail, setSelectedDishForDetail] = useState<DishItem | null>(null);
  const [dishes] = useState<DishItem[]>(INITIAL_DISHES);
  const [tables, setTables] = useState<Table[]>(INITIAL_TABLES);
  const [bookings] = useState(INITIAL_BOOKINGS);

  // Retail State (Packaged Meats Store - Flat ₱88 Variety)
  const [retailProducts, setRetailProducts] = useState<RetailProduct[]>(INITIAL_RETAIL_MEATS);
  const [selectedRetailCategory, setSelectedRetailCategory] = useState<RetailCategory>('All');
  const [isAddProductModalOpen, setIsAddProductModalOpen] = useState(false);

  // Shared Orders & Cart State
  const [orders, setOrders] = useState<Order[]>(INITIAL_ORDERS);
  const [cart, setCart] = useState<CartItem[]>([]);

  // Cart Operations
  const handleAddToCart = (dish: DishItem, quantity: number, selectedAdditions: SelectedAddition[]) => {
    setCart((prev) => [...prev, { dish, quantity, selectedAdditions }]);
  };

  const handleAddRetailToCart = (product: RetailProduct) => {
    // Convert RetailProduct to DishItem structure
    const convertedDish: DishItem = {
      id: product.id,
      name: product.name,
      category: product.category,
      price: product.price,
      weight: product.weight,
      image: product.image,
      description: product.description,
      sku: product.sku,
    };

    setCart((prev) => {
      // Check if product already exists in cart
      const existingIdx = prev.findIndex((c) => c.dish.id === product.id);
      if (existingIdx >= 0) {
        const updated = [...prev];
        updated[existingIdx].quantity += 1;
        return updated;
      }
      return [...prev, { dish: convertedDish, quantity: 1, selectedAdditions: [] }];
    });
  };

  const handleUpdateCartQuantity = (index: number, delta: number) => {
    setCart((prev) => {
      const updated = [...prev];
      const newQty = updated[index].quantity + delta;
      if (newQty <= 0) {
        return updated.filter((_, i) => i !== index);
      } else {
        updated[index] = { ...updated[index], quantity: newQty };
        return updated;
      }
    });
  };

  const handleRemoveCartItem = (index: number) => {
    setCart((prev) => prev.filter((_, i) => i !== index));
  };

  const handleClearCart = () => {
    setCart([]);
  };

  // Complete Checkout for Restaurant or Retail
  const handleCompleteOrder = (
    tableOrCounter: string,
    paymentMethod: 'Cash' | 'GCash' | 'Maya' | 'Card' = 'Cash',
    cashReceived?: number,
    changeGiven?: number
  ) => {
    if (cart.length === 0) return;

    const subtotal = cart.reduce((sum, item) => {
      const additionsCost = item.selectedAdditions.reduce((aSum, a) => aSum + a.price, 0);
      return sum + (item.dish.price + additionsCost) * item.quantity;
    }, 0);
    const tax = subtotal * 0.1;
    const total = subtotal + tax;

    const prefix = businessType === 'restaurant' ? '#FP' : '#MP';

    const newOrder: Order = {
      id: `ord-${Date.now()}`,
      orderNo: `${prefix}-${Math.floor(1000 + Math.random() * 9000)}`,
      businessType,
      tableNumber: tableOrCounter,
      items: cart.map((c) => ({
        dishName: c.dish.name,
        quantity: c.quantity,
        price: c.dish.price,
        additions: c.selectedAdditions.map((a) => a.name),
      })),
      subtotal,
      tax,
      total,
      status: 'Paid',
      timestamp: 'Just now',
      waiterName: STAFF_PROFILE.name,
      paymentMethod,
      cashReceived,
      changeGiven,
    };

    setOrders((prev) => [newOrder, ...prev]);

    // Deduct stock for retail products purchased
    if (businessType === 'retail') {
      cart.forEach((item) => {
        setRetailProducts((prevProds) =>
          prevProds.map((p) =>
            p.id === item.dish.id
              ? { ...p, stock: Math.max(0, p.stock - item.quantity) }
              : p
          )
        );
      });
    } else {
      // Update restaurant table status to occupied
      setTables((prev) =>
        prev.map((t) =>
          t.number === tableOrCounter
            ? {
                ...t,
                status: 'occupied',
                currentOrderTotal: total,
                guestCount: t.guestCount || 2,
              }
            : t
        )
      );
    }

    setCart([]);
  };

  const handleUpdateOrderStatus = (orderId: string, status: Order['status']) => {
    setOrders((prev) =>
      prev.map((o) => (o.id === orderId ? { ...o, status } : o))
    );
  };

  // Inventory Management Handlers
  const handleRestockRetailProduct = (productId: string, delta: number) => {
    setRetailProducts((prev) =>
      prev.map((p) =>
        p.id === productId
          ? { ...p, stock: Math.max(0, p.stock + delta) }
          : p
      )
    );
  };

  const handleAddRetailProduct = (newProd: RetailProduct) => {
    setRetailProducts((prev) => [newProd, ...prev]);
  };

  return (
    <>
      {/* 1. Cinematic Fluid Ink Intro Animation */}
      {showIntroAnimation && (
        <FluidInkIntro onComplete={() => setShowIntroAnimation(false)} />
      )}

      {/* 2. Main iPad Frame & Dashboard OS */}
      <IPadFrame
        viewMode={viewMode}
        onChangeViewMode={setViewMode}
        onReplayIntro={() => setShowIntroAnimation(true)}
      >
        <div className="w-full h-full flex overflow-hidden bg-white text-slate-900 font-sans">
          {/* Left Sidebar with Business Switcher */}
          <FoodPosSidebar
            businessType={businessType}
            onChangeBusinessType={(type) => {
              setBusinessType(type);
              setCart([]); // Clear cart when switching business mode
            }}
            activeTab={activeTab}
            onSelectTab={setActiveTab}
            staffProfile={STAFF_PROFILE}
            onReplayIntro={() => setShowIntroAnimation(true)}
            orderCount={orders.filter((o) => o.status !== 'Paid').length}
          />

          {/* Main Dashboard Views depending on business mode & tab */}
          {/* RESTAURANT VIEWS */}
          {businessType === 'restaurant' && activeTab === 'dishes' && (
            <DishesView
              dishes={dishes}
              selectedCategory={selectedCategory}
              onSelectCategory={setSelectedCategory}
              onSelectDish={(dish) => setSelectedDishForDetail(dish)}
              onViewAllPopular={() => setSelectedCategory('All')}
            />
          )}

          {businessType === 'restaurant' && activeTab === 'floor_plan' && (
            <FloorPlanView
              tables={tables}
              onSelectTable={(table) => {
                setActiveTab('dishes');
              }}
            />
          )}

          {businessType === 'restaurant' && activeTab === 'bookings' && (
            <BookingsView bookings={bookings} />
          )}

          {/* RETAIL MEATS VIEWS */}
          {businessType === 'retail' && (activeTab === 'checkout' || activeTab === 'dishes') && (
            <RetailPOSView
              products={retailProducts}
              selectedCategory={selectedRetailCategory}
              onSelectCategory={setSelectedRetailCategory}
              onAddToCart={handleAddRetailToCart}
              onOpenAddProductModal={() => setIsAddProductModalOpen(true)}
              onNavigateToInventory={() => setActiveTab('inventory')}
            />
          )}

          {businessType === 'retail' && activeTab === 'inventory' && (
            <RetailInventoryView
              products={retailProducts}
              onRestockProduct={handleRestockRetailProduct}
              onAddProduct={handleAddRetailProduct}
            />
          )}

          {/* SHARED VIEWS */}
          {activeTab === 'orders' && (
            <OrdersView
              orders={orders.filter((o) => o.businessType === businessType)}
              onUpdateOrderStatus={handleUpdateOrderStatus}
            />
          )}

          {activeTab === 'receipts' && (
            <ReceiptsView orders={orders.filter((o) => o.businessType === businessType)} />
          )}

          {activeTab === 'analytics' && (
            <AnalyticsView
              orders={orders}
              retailProducts={retailProducts}
              dishes={dishes}
            />
          )}

          {/* Right Active Order / Cart Tray */}
          <CartTray
            businessType={businessType}
            cart={cart}
            onUpdateQuantity={handleUpdateCartQuantity}
            onRemoveItem={handleRemoveCartItem}
            onClearCart={handleClearCart}
            onCompleteOrder={handleCompleteOrder}
          />
        </div>
      </IPadFrame>

      {/* Dish Detail Modal overlay (for Restaurant Mode) */}
      {selectedDishForDetail && (
        <DishDetailModal
          dish={selectedDishForDetail}
          onClose={() => setSelectedDishForDetail(null)}
          onAddToCart={handleAddToCart}
        />
      )}
    </>
  );
}

export default App;
