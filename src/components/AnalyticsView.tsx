import React, { useState, useMemo } from 'react';
import { Order, RetailProduct, DishItem } from '../types';
import {
  TrendingUp,
  BarChart3,
  Calendar,
  ShoppingBag,
  Banknote,
  Sparkles,
  Award,
  PackageCheck,
  CreditCard,
  Layers,
  ArrowUpRight,
  Filter,
} from 'lucide-react';
import {
  ResponsiveContainer,
  AreaChart,
  Area,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  PieChart,
  Pie,
  Cell,
  CartesianGrid,
} from 'recharts';

interface AnalyticsViewProps {
  orders: Order[];
  retailProducts: RetailProduct[];
  dishes: DishItem[];
}

export const AnalyticsView: React.FC<AnalyticsViewProps> = ({
  orders,
  retailProducts,
  dishes,
}) => {
  const [timeframe, setTimeframe] = useState<'day' | 'week' | 'month'>('day');

  // Compute aggregate stats based on timeframe
  const stats = useMemo(() => {
    // Top products aggregation
    const productSalesMap: Record<string, { name: string; quantity: number; revenue: number; category: string }> = {};

    let totalRevenue = 0;
    let totalOrdersCount = orders.length;
    let totalItemsSold = 0;
    let cashPaymentsTotal = 0;
    let digitalPaymentsTotal = 0;

    orders.forEach((ord) => {
      totalRevenue += ord.total;

      if (ord.paymentMethod === 'Cash') {
        cashPaymentsTotal += ord.total;
      } else {
        digitalPaymentsTotal += ord.total;
      }

      ord.items.forEach((item) => {
        totalItemsSold += item.quantity;
        const key = item.dishName;
        if (!productSalesMap[key]) {
          productSalesMap[key] = {
            name: key,
            quantity: 0,
            revenue: 0,
            category: ord.businessType === 'retail' ? 'Packaged Meat' : 'Restaurant Dish',
          };
        }
        productSalesMap[key].quantity += item.quantity;
        productSalesMap[key].revenue += item.price * item.quantity;
      });
    });

    const topProducts = Object.values(productSalesMap).sort((a, b) => b.quantity - a.quantity);
    const avgOrderValue = totalOrdersCount > 0 ? totalRevenue / totalOrdersCount : 0;

    return {
      totalRevenue,
      totalOrdersCount,
      totalItemsSold,
      avgOrderValue,
      cashPaymentsTotal,
      digitalPaymentsTotal,
      topProducts,
    };
  }, [orders]);

  // Mock time-series chart data tailored to current selected timeframe (Day, Week, Month)
  const chartData = useMemo(() => {
    if (timeframe === 'day') {
      return [
        { time: '08:00', Revenue: 880, Orders: 10 },
        { time: '10:00', Revenue: 1760, Orders: 20 },
        { time: '12:00', Revenue: 3520, Orders: 40 },
        { time: '14:00', Revenue: 2640, Orders: 30 },
        { time: '16:00', Revenue: 4400, Orders: 50 },
        { time: '18:00', Revenue: 5280, Orders: 60 },
        { time: '20:00', Revenue: 3080, Orders: 35 },
      ];
    } else if (timeframe === 'week') {
      return [
        { time: 'Mon', Revenue: 12500, Orders: 142 },
        { time: 'Tue', Revenue: 14200, Orders: 161 },
        { time: 'Wed', Revenue: 15800, Orders: 179 },
        { time: 'Thu', Revenue: 18400, Orders: 209 },
        { time: 'Fri', Revenue: 24600, Orders: 280 },
        { time: 'Sat', Revenue: 29800, Orders: 338 },
        { time: 'Sun', Revenue: 26500, Orders: 301 },
      ];
    } else {
      return [
        { time: 'Week 1', Revenue: 88400, Orders: 1004 },
        { time: 'Week 2', Revenue: 96200, Orders: 1093 },
        { time: 'Week 3', Revenue: 112000, Orders: 1272 },
        { time: 'Week 4', Revenue: 128500, Orders: 1460 },
      ];
    }
  }, [timeframe]);

  const paymentBreakdown = [
    { name: 'Cash', value: stats.cashPaymentsTotal || 4500, color: '#f59e0b' },
    { name: 'GCash / E-Wallet', value: stats.digitalPaymentsTotal || 6200, color: '#06b6d4' },
    { name: 'Card', value: 2400, color: '#ec4899' },
  ];

  return (
    <div className="flex-1 bg-white p-5 overflow-y-auto space-y-5 select-none">
      {/* Top Header & Timeframe Switcher */}
      <div className="flex flex-wrap items-center justify-between gap-3 bg-gradient-to-r from-slate-900 via-indigo-950 to-slate-900 text-white p-4 rounded-3xl shadow-sm">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-2xl bg-amber-400 text-slate-950 font-black flex items-center justify-center">
            <TrendingUp className="w-5 h-5" />
          </div>
          <div>
            <h2 className="text-sm font-extrabold tracking-tight">Sales Analytics & Best Sellers</h2>
            <p className="text-[11px] text-slate-300">
              Track store performance, cash flow, and top-moving products
            </p>
          </div>
        </div>

        {/* Timeframe Selector Pills */}
        <div className="bg-slate-800/80 p-1 rounded-2xl flex items-center gap-1 border border-slate-700">
          {(['day', 'week', 'month'] as const).map((tf) => {
            const isSelected = timeframe === tf;
            const labels = { day: 'Daily Today', week: 'This Week', month: 'This Month' };

            return (
              <button
                key={tf}
                onClick={() => setTimeframe(tf)}
                className={`px-3 py-1.5 rounded-xl text-xs font-extrabold transition-all cursor-pointer ${
                  isSelected
                    ? 'bg-amber-400 text-slate-950 shadow-sm'
                    : 'text-slate-300 hover:text-white'
                }`}
              >
                {labels[tf]}
              </button>
            );
          })}
        </div>
      </div>

      {/* KPI Cards Grid */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="bg-[#f8f9fa] rounded-3xl p-4 border border-slate-200/80">
          <div className="flex items-center justify-between">
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">
              Total Revenue
            </span>
            <div className="p-1.5 rounded-xl bg-emerald-100 text-emerald-700">
              <Banknote className="w-3.5 h-3.5" />
            </div>
          </div>
          <span className="text-lg font-black text-slate-900 mt-2 block">
            ₱{stats.totalRevenue > 0 ? stats.totalRevenue.toFixed(2) : '18,480.00'}
          </span>
          <span className="text-[10px] font-bold text-emerald-600 flex items-center gap-0.5 mt-1">
            <ArrowUpRight className="w-3 h-3" /> +14.2% vs previous {timeframe}
          </span>
        </div>

        <div className="bg-[#f8f9fa] rounded-3xl p-4 border border-slate-200/80">
          <div className="flex items-center justify-between">
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">
              Packs / Orders Sold
            </span>
            <div className="p-1.5 rounded-xl bg-pink-100 text-pink-700">
              <ShoppingBag className="w-3.5 h-3.5" />
            </div>
          </div>
          <span className="text-lg font-black text-slate-900 mt-2 block">
            {stats.totalItemsSold > 0 ? stats.totalItemsSold : 210} Items
          </span>
          <span className="text-[10px] font-bold text-slate-500 mt-1 block">
            {stats.totalOrdersCount > 0 ? stats.totalOrdersCount : 42} checkout receipts
          </span>
        </div>

        <div className="bg-[#f8f9fa] rounded-3xl p-4 border border-slate-200/80">
          <div className="flex items-center justify-between">
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">
              Avg Basket Size
            </span>
            <div className="p-1.5 rounded-xl bg-indigo-100 text-indigo-700">
              <BarChart3 className="w-3.5 h-3.5" />
            </div>
          </div>
          <span className="text-lg font-black text-slate-900 mt-2 block">
            ₱{stats.avgOrderValue > 0 ? stats.avgOrderValue.toFixed(2) : '440.00'}
          </span>
          <span className="text-[10px] font-bold text-slate-500 mt-1 block">
            ~5 packs per purchase
          </span>
        </div>

        <div className="bg-[#f8f9fa] rounded-3xl p-4 border border-slate-200/80">
          <div className="flex items-center justify-between">
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">
              Top Category
            </span>
            <div className="p-1.5 rounded-xl bg-amber-100 text-amber-700">
              <Award className="w-3.5 h-3.5" />
            </div>
          </div>
          <span className="text-sm font-extrabold text-slate-900 mt-2 block truncate">
            Pork Samgyupsal
          </span>
          <span className="text-[10px] font-bold text-amber-600 mt-1 block">
            Flat ₱88 Leader
          </span>
        </div>
      </div>

      {/* Revenue Trend Area Chart & Payment Pie Chart */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Main Revenue Area Chart */}
        <div className="lg:col-span-2 bg-[#f8f9fa] rounded-3xl p-4 border border-slate-200/80 space-y-3">
          <div className="flex items-center justify-between">
            <h3 className="text-xs font-extrabold text-slate-900 flex items-center gap-1.5">
              <TrendingUp className="w-4 h-4 text-emerald-600" />
              <span>Revenue Overview ({timeframe.toUpperCase()})</span>
            </h3>
            <span className="text-[10px] font-extrabold text-slate-500 bg-white px-2 py-1 rounded-xl border border-slate-200">
              Currency: ₱ (PHP)
            </span>
          </div>

          <div className="h-56 w-full pt-2">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chartData}>
                <defs>
                  <linearGradient id="colorRev" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#db2777" stopOpacity={0.3} />
                    <stop offset="95%" stopColor="#db2777" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e2e8f0" />
                <XAxis dataKey="time" tick={{ fontSize: 10, fill: '#64748b' }} axisLine={false} />
                <YAxis tick={{ fontSize: 10, fill: '#64748b' }} axisLine={false} />
                <Tooltip
                  contentStyle={{
                    backgroundColor: '#0f172a',
                    borderRadius: '12px',
                    color: '#fff',
                    fontSize: '11px',
                    border: 'none',
                  }}
                  formatter={(value: any) => [`₱${value}`, 'Revenue']}
                />
                <Area
                  type="monotone"
                  dataKey="Revenue"
                  stroke="#db2777"
                  strokeWidth={3}
                  fillOpacity={1}
                  fill="url(#colorRev)"
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Payment Methods Distribution */}
        <div className="bg-[#f8f9fa] rounded-3xl p-4 border border-slate-200/80 flex flex-col justify-between space-y-3">
          <div>
            <h3 className="text-xs font-extrabold text-slate-900 flex items-center gap-1.5">
              <CreditCard className="w-4 h-4 text-amber-500" />
              <span>Payment Methods</span>
            </h3>
            <p className="text-[10px] text-slate-400 mt-0.5">Cash vs E-Wallet Digital Ratio</p>
          </div>

          <div className="h-40 w-full relative flex items-center justify-center">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={paymentBreakdown}
                  cx="50%"
                  cy="50%"
                  innerRadius={35}
                  outerRadius={60}
                  paddingAngle={5}
                  dataKey="value"
                >
                  {paymentBreakdown.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip
                  contentStyle={{
                    backgroundColor: '#0f172a',
                    borderRadius: '12px',
                    color: '#fff',
                    fontSize: '11px',
                  }}
                  formatter={(value: any) => [`₱${value}`, 'Amount']}
                />
              </PieChart>
            </ResponsiveContainer>
          </div>

          <div className="space-y-1.5 pt-2 border-t border-slate-200/60">
            {paymentBreakdown.map((item) => (
              <div key={item.name} className="flex items-center justify-between text-[11px]">
                <div className="flex items-center gap-2">
                  <span
                    className="w-2.5 h-2.5 rounded-full"
                    style={{ backgroundColor: item.color }}
                  />
                  <span className="font-semibold text-slate-700">{item.name}</span>
                </div>
                <span className="font-extrabold text-slate-900">₱{item.value.toFixed(0)}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Top Selling Products Leaderboard */}
      <div className="bg-[#f8f9fa] rounded-3xl p-4 border border-slate-200/80 space-y-3">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-xs font-extrabold text-slate-900 flex items-center gap-1.5">
              <Award className="w-4 h-4 text-pink-600" />
              <span>Which Products Sell Most (Best Sellers)</span>
            </h3>
            <p className="text-[10px] text-slate-400">
              Ranked by quantity sold & total store revenue generated
            </p>
          </div>
        </div>

        <div className="space-y-2">
          {stats.topProducts.length === 0 ? (
            /* Fallback default best sellers if no orders yet */
            [
              {
                name: 'Thin Sliced Pork Samgyupsal',
                quantity: 128,
                revenue: 11264,
                category: 'Pork',
              },
              {
                name: 'USDA Choice Beef Samgyup Slices',
                quantity: 94,
                revenue: 8272,
                category: 'Beef',
              },
              {
                name: 'Sweet Soy Marinated Pork Bulpogi',
                quantity: 76,
                revenue: 6688,
                category: 'Marinated BBQ',
              },
              {
                name: 'Garlic Hungarian Smoked Sausage',
                quantity: 58,
                revenue: 5104,
                category: 'Deli & Sausages',
              },
              {
                name: 'Sunrise Mediterranean Bowl',
                quantity: 42,
                revenue: 3696,
                category: 'Restaurant',
              },
            ].map((prod, rank) => (
              <div
                key={rank}
                className="bg-white rounded-2xl p-3 border border-slate-200/70 flex items-center justify-between"
              >
                <div className="flex items-center gap-3">
                  <div
                    className={`w-7 h-7 rounded-xl flex items-center justify-center font-extrabold text-xs ${
                      rank === 0
                        ? 'bg-amber-400 text-slate-950 shadow-xs'
                        : rank === 1
                        ? 'bg-slate-300 text-slate-800'
                        : 'bg-slate-100 text-slate-600'
                    }`}
                  >
                    #{rank + 1}
                  </div>

                  <div>
                    <h4 className="text-xs font-bold text-slate-900">{prod.name}</h4>
                    <span className="text-[10px] text-slate-400 font-medium">
                      {prod.category} • Flat ₱88 Pack
                    </span>
                  </div>
                </div>

                <div className="flex items-center gap-5 text-right">
                  <div>
                    <span className="text-xs font-black text-slate-900">
                      {prod.quantity} Packs Sold
                    </span>
                    <p className="text-[10px] text-slate-400">Total ₱{prod.revenue}</p>
                  </div>

                  <div className="w-20 bg-slate-100 h-2 rounded-full overflow-hidden hidden sm:block">
                    <div
                      className="bg-pink-600 h-full rounded-full"
                      style={{ width: `${Math.max(20, 100 - rank * 18)}%` }}
                    />
                  </div>
                </div>
              </div>
            ))
          ) : (
            stats.topProducts.map((prod, rank) => (
              <div
                key={rank}
                className="bg-white rounded-2xl p-3 border border-slate-200/70 flex items-center justify-between"
              >
                <div className="flex items-center gap-3">
                  <div
                    className={`w-7 h-7 rounded-xl flex items-center justify-center font-extrabold text-xs ${
                      rank === 0
                        ? 'bg-amber-400 text-slate-950'
                        : rank === 1
                        ? 'bg-slate-300 text-slate-800'
                        : 'bg-slate-100 text-slate-600'
                    }`}
                  >
                    #{rank + 1}
                  </div>

                  <div>
                    <h4 className="text-xs font-bold text-slate-900">{prod.name}</h4>
                    <span className="text-[10px] text-slate-400 font-medium">{prod.category}</span>
                  </div>
                </div>

                <div className="flex items-center gap-5 text-right">
                  <div>
                    <span className="text-xs font-black text-slate-900">
                      {prod.quantity} Units Sold
                    </span>
                    <p className="text-[10px] text-pink-600 font-bold">
                      ₱{prod.revenue.toFixed(2)}
                    </p>
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
