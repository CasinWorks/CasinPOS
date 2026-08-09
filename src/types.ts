export type BusinessType = 'restaurant' | 'retail';

export type Category = 'All' | 'Breakfast' | 'Lunch' | 'Pastry' | 'Soups' | 'Bowls' | 'Burgers' | 'Desserts';

export type RetailCategory = 'All' | 'Beef' | 'Pork' | 'Chicken' | 'Deli & Sausages' | 'Marinated BBQ' | 'Seafood Packs';

export type NavTab = 'dishes' | 'floor_plan' | 'orders' | 'bookings' | 'receipts' | 'checkout' | 'inventory' | 'sales_history' | 'analytics' | 'notifications' | 'support';

export interface DishAddition {
  id: string;
  name: string;
  price: number;
}

export interface DishItem {
  id: string;
  name: string;
  category: Category | string;
  price: number; // e.g. 88 or 15.49
  weight: string; // e.g., "500 g" or "300 g"
  calories?: string;
  image: string;
  popular?: boolean;
  description?: string;
  additions?: DishAddition[];
  sku?: string;
  stock?: number;
  lowStockThreshold?: number;
}

export interface RetailProduct {
  id: string;
  sku: string;
  name: string;
  category: RetailCategory;
  price: number; // default 88 pesos
  costPrice: number;
  weight: string; // e.g., "500g Pack"
  stock: number;
  lowStockThreshold: number;
  image: string;
  description: string;
  barcode?: string;
}

export interface SelectedAddition {
  id: string;
  name: string;
  price: number;
}

export interface CartItem {
  dish: DishItem;
  quantity: number;
  selectedAdditions: SelectedAddition[];
  notes?: string;
}

export interface Order {
  id: string;
  orderNo: string;
  tableNumber?: string;
  businessType: BusinessType;
  items: {
    dishName: string;
    quantity: number;
    price: number;
    additions?: string[];
  }[];
  subtotal: number;
  tax: number;
  total: number;
  status: 'Preparing' | 'Ready' | 'Served' | 'Paid' | 'Completed';
  timestamp: string;
  customerName?: string;
  waiterName: string;
  paymentMethod?: 'Cash' | 'GCash' | 'Maya' | 'Card';
  cashReceived?: number;
  changeGiven?: number;
}

export interface Table {
  id: string;
  number: string;
  seats: number;
  section: 'Main Hall' | 'Terrace' | 'VIP Lounge';
  status: 'available' | 'occupied' | 'reserved';
  currentOrderTotal?: number;
  guestCount?: number;
}

export interface Booking {
  id: string;
  customerName: string;
  time: string;
  date: string;
  guests: number;
  tableNumber: string;
  phone: string;
  status: 'Confirmed' | 'Seated' | 'Cancelled';
}

export interface StaffProfile {
  name: string;
  role: string;
  avatar: string;
  ordersServedToday: number;
  tipsEarned: number;
}
