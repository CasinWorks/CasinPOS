import React from 'react';
import { Order } from '../types';
import { Bookmark, Clock, CheckCircle2, ChefHat, Check } from 'lucide-react';

interface OrdersViewProps {
  orders: Order[];
  onUpdateOrderStatus: (orderId: string, status: Order['status']) => void;
}

export const OrdersView: React.FC<OrdersViewProps> = ({ orders, onUpdateOrderStatus }) => {
  const getStatusBadge = (status: Order['status']) => {
    switch (status) {
      case 'Preparing':
        return (
          <span className="px-2.5 py-1 rounded-full bg-amber-100 text-amber-800 font-bold text-[10px] flex items-center gap-1">
            <ChefHat className="w-3 h-3 text-amber-600 animate-spin" /> Preparing
          </span>
        );
      case 'Ready':
        return (
          <span className="px-2.5 py-1 rounded-full bg-indigo-100 text-indigo-800 font-bold text-[10px] flex items-center gap-1">
            <Clock className="w-3 h-3 text-indigo-600" /> Ready to Serve
          </span>
        );
      case 'Served':
        return (
          <span className="px-2.5 py-1 rounded-full bg-emerald-100 text-emerald-800 font-bold text-[10px] flex items-center gap-1">
            <CheckCircle2 className="w-3 h-3 text-emerald-600" /> Served
          </span>
        );
      case 'Paid':
        return (
          <span className="px-2.5 py-1 rounded-full bg-slate-100 text-slate-800 font-bold text-[10px] flex items-center gap-1">
            <Check className="w-3 h-3 text-slate-600" /> Paid
          </span>
        );
      default:
        return (
          <span className="px-2.5 py-1 rounded-full bg-slate-100 text-slate-800 font-bold text-[10px]">
            {status}
          </span>
        );
    }
  };

  return (
    <div className="flex-1 bg-white p-5 overflow-y-auto space-y-5 select-none">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-sm font-extrabold text-slate-900 tracking-tight">
            Orders & Kitchen Activity Log
          </h2>
          <p className="text-xs text-slate-400">Track current preparation and transaction status</p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {orders.length === 0 ? (
          <div className="col-span-2 py-12 text-center text-xs text-slate-400">
            No active orders or transaction history in this store view.
          </div>
        ) : (
          orders.map((ord) => (
            <div
              key={ord.id}
              className="bg-[#f8f9fa] rounded-3xl p-4 border border-slate-200/80 space-y-3"
            >
              <div className="flex items-center justify-between">
                <div>
                  <span className="text-xs font-extrabold text-slate-900">{ord.orderNo}</span>
                  <p className="text-[10px] text-slate-400 font-medium mt-0.5">
                    {ord.businessType === 'restaurant'
                      ? `Table ${ord.tableNumber}`
                      : ord.tableNumber || 'Retail Counter'}{' '}
                    • {ord.timestamp}
                  </p>
                </div>
                {getStatusBadge(ord.status)}
              </div>

              {/* Item list */}
              <div className="bg-white rounded-2xl p-3 space-y-1.5 border border-slate-100 text-xs">
                {ord.items.map((item, idx) => (
                  <div key={idx} className="flex items-center justify-between">
                    <span className="font-semibold text-slate-800">
                      {item.quantity}x {item.dishName}
                    </span>
                    <span className="font-bold text-slate-900">
                      ₱{(item.price * item.quantity).toFixed(2)}
                    </span>
                  </div>
                ))}
              </div>

              <div className="flex items-center justify-between pt-1">
                <span className="text-xs font-extrabold text-slate-900">
                  Total: ₱{ord.total.toFixed(2)}
                </span>

                <div className="flex items-center gap-2">
                  {ord.status === 'Preparing' && (
                    <button
                      onClick={() => onUpdateOrderStatus(ord.id, 'Ready')}
                      className="px-3 py-1.5 rounded-xl bg-slate-900 text-white font-bold text-[10px] hover:bg-slate-800 cursor-pointer"
                    >
                      Mark Ready
                    </button>
                  )}
                  {ord.status === 'Ready' && (
                    <button
                      onClick={() => onUpdateOrderStatus(ord.id, 'Served')}
                      className="px-3 py-1.5 rounded-xl bg-emerald-600 text-white font-bold text-[10px] hover:bg-emerald-700 cursor-pointer"
                    >
                      Mark Served
                    </button>
                  )}
                </div>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
};
