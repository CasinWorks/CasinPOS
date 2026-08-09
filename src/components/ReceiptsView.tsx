import React from 'react';
import { Order } from '../types';
import { Receipt, Printer, CheckCircle2, CreditCard } from 'lucide-react';

interface ReceiptsViewProps {
  orders: Order[];
}

export const ReceiptsView: React.FC<ReceiptsViewProps> = ({ orders }) => {
  return (
    <div className="flex-1 bg-white p-5 overflow-y-auto space-y-5 select-none">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-sm font-extrabold text-slate-900 tracking-tight">
            Receipts & Sales Audit
          </h2>
          <p className="text-xs text-slate-400">Completed transactions & payment history</p>
        </div>
      </div>

      <div className="space-y-3">
        {orders.length === 0 ? (
          <div className="py-12 text-center text-xs text-slate-400">
            No completed receipt transactions recorded yet.
          </div>
        ) : (
          orders.map((ord) => (
            <div
              key={ord.id}
              className="bg-[#f8f9fa] rounded-3xl p-4 border border-slate-200/80 flex items-center justify-between"
            >
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-2xl bg-slate-900 text-amber-300 flex items-center justify-center font-bold shadow-xs">
                  <Receipt className="w-5 h-5" />
                </div>

                <div>
                  <div className="flex items-center gap-2">
                    <h4 className="text-xs font-bold text-slate-900">{ord.orderNo}</h4>
                    {ord.paymentMethod && (
                      <span className="text-[9px] px-2 py-0.5 rounded-full bg-slate-200 text-slate-700 font-extrabold">
                        {ord.paymentMethod}
                      </span>
                    )}
                  </div>
                  <p className="text-[10px] text-slate-400 font-medium mt-0.5">
                    {ord.businessType === 'restaurant'
                      ? `Table ${ord.tableNumber}`
                      : ord.tableNumber || 'Walk-in Customer'}{' '}
                    • {ord.timestamp} • {ord.items.length} item(s)
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-4">
                <div className="text-right">
                  <span className="text-xs font-black text-slate-900">
                    ₱{ord.total.toFixed(2)}
                  </span>
                  <p className="text-[10px] text-emerald-600 font-bold flex items-center justify-end gap-1">
                    <CheckCircle2 className="w-3 h-3" /> Paid
                  </p>
                </div>

                <button
                  onClick={() =>
                    alert(`Receipt ${ord.orderNo} sent to thermal Bluetooth receipt printer!`)
                  }
                  className="p-2 rounded-xl bg-white hover:bg-slate-100 text-slate-700 border border-slate-200 shadow-2xs transition-all cursor-pointer"
                  title="Print Thermal Receipt"
                >
                  <Printer className="w-4 h-4" />
                </button>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
};
