import React, { useState } from 'react';
import { CartItem, BusinessType } from '../types';
import { ShoppingBag, X, Trash2, Plus, Minus, ArrowRight, CheckCircle2, CreditCard, Wallet, Banknote, Calculator } from 'lucide-react';
import { CashCalculatorModal } from './CashCalculatorModal';

interface CartTrayProps {
  businessType: BusinessType;
  cart: CartItem[];
  onUpdateQuantity: (index: number, delta: number) => void;
  onRemoveItem: (index: number) => void;
  onClearCart: () => void;
  onCompleteOrder: (
    tableNo: string,
    paymentMethod?: 'Cash' | 'GCash' | 'Maya' | 'Card',
    cashReceived?: number,
    changeGiven?: number
  ) => void;
}

export const CartTray: React.FC<CartTrayProps> = ({
  businessType,
  cart,
  onUpdateQuantity,
  onRemoveItem,
  onClearCart,
  onCompleteOrder,
}) => {
  const [selectedTable, setSelectedTable] = useState('01');
  const [paymentMethod, setPaymentMethod] = useState<'Cash' | 'GCash' | 'Maya' | 'Card'>('Cash');
  const [isSuccessModalOpen, setIsSuccessModalOpen] = useState(false);
  const [isCashCalcOpen, setIsCashCalcOpen] = useState(false);
  const [lastChange, setLastChange] = useState<number | null>(null);

  const currency = '₱';

  const subtotal = cart.reduce((sum, item) => {
    const additionsCost = item.selectedAdditions.reduce((aSum, a) => aSum + a.price, 0);
    return sum + (item.dish.price + additionsCost) * item.quantity;
  }, 0);

  const tax = subtotal * 0.1; // 10% VAT
  const total = subtotal + tax;

  const handleCheckoutClick = () => {
    if (cart.length === 0) return;

    if (paymentMethod === 'Cash') {
      setIsCashCalcOpen(true);
    } else {
      finalizeOrder('Digital', total, 0);
    }
  };

  const finalizeOrder = (method: 'Cash' | 'GCash' | 'Maya' | 'Card' | 'Digital', received?: number, change?: number) => {
    setLastChange(change ?? 0);
    setIsSuccessModalOpen(true);
    setTimeout(() => {
      onCompleteOrder(
        businessType === 'restaurant' ? selectedTable : 'Retail Counter',
        paymentMethod,
        received,
        change
      );
      setIsSuccessModalOpen(false);
      setLastChange(null);
    }, 1500);
  };

  const handleConfirmCashPayment = (cashReceived: number, changeGiven: number) => {
    setIsCashCalcOpen(false);
    finalizeOrder('Cash', cashReceived, changeGiven);
  };

  return (
    <aside className="w-72 shrink-0 bg-[#f8f9fa] border-l border-slate-200/80 p-4 flex flex-col justify-between h-full select-none">
      <div>
        {/* Header */}
        <div className="flex items-center justify-between pb-3 border-b border-slate-200/80 mb-3">
          <div className="flex items-center gap-2">
            <div
              className={`w-8 h-8 rounded-xl text-white flex items-center justify-center ${
                businessType === 'retail' ? 'bg-pink-600' : 'bg-slate-900'
              }`}
            >
              <ShoppingBag className="w-4 h-4" />
            </div>
            <div>
              <h3 className="text-xs font-bold text-slate-900">
                {businessType === 'restaurant' ? 'Current Order' : 'Retail Cart (₱88)'}
              </h3>
              <p className="text-[10px] text-slate-400">{cart.length} item(s) selected</p>
            </div>
          </div>

          {cart.length > 0 && (
            <button
              onClick={onClearCart}
              className="text-[10px] text-rose-600 hover:text-rose-700 font-bold cursor-pointer"
            >
              Clear
            </button>
          )}
        </div>

        {/* Table Selector for Restaurant OR Payment Method for Retail */}
        {businessType === 'restaurant' ? (
          <div className="mb-3 space-y-2">
            <div>
              <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
                Table Assignment
              </label>
              <select
                value={selectedTable}
                onChange={(e) => setSelectedTable(e.target.value)}
                className="w-full bg-white border border-slate-200 text-slate-900 rounded-xl px-3 py-1.5 text-xs font-bold focus:outline-none focus:ring-1 focus:ring-slate-900"
              >
                <option value="01">Table 01 (Main Hall)</option>
                <option value="02">Table 02 (Main Hall)</option>
                <option value="03">Table 03 (Main Hall)</option>
                <option value="04">Table 04 (Main Hall)</option>
                <option value="06">Table 06 (Terrace)</option>
                <option value="07">Table 07 (VIP Lounge)</option>
              </select>
            </div>

            <div>
              <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
                Payment Mode
              </label>
              <div className="grid grid-cols-2 gap-1.5">
                {(['Cash', 'GCash', 'Maya', 'Card'] as const).map((method) => {
                  const isSelected = paymentMethod === method;
                  return (
                    <button
                      key={method}
                      type="button"
                      onClick={() => setPaymentMethod(method)}
                      className={`px-2 py-1.5 rounded-xl text-[10px] font-extrabold transition-all border cursor-pointer ${
                        isSelected
                          ? 'bg-slate-900 text-amber-300 border-slate-900 shadow-2xs'
                          : 'bg-white text-slate-700 border-slate-200 hover:bg-slate-100'
                      }`}
                    >
                      {method}
                    </button>
                  );
                })}
              </div>
            </div>
          </div>
        ) : (
          <div className="mb-3 space-y-2">
            <div className="flex items-center justify-between">
              <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                Payment Method
              </label>

              {paymentMethod === 'Cash' && total > 0 && (
                <button
                  onClick={() => setIsCashCalcOpen(true)}
                  className="text-[10px] text-amber-600 font-extrabold flex items-center gap-1 hover:underline cursor-pointer"
                >
                  <Calculator className="w-3 h-3" />
                  <span>Cash Calc</span>
                </button>
              )}
            </div>

            <div className="grid grid-cols-2 gap-1.5">
              {(['Cash', 'GCash', 'Maya', 'Card'] as const).map((method) => {
                const isSelected = paymentMethod === method;
                return (
                  <button
                    key={method}
                    type="button"
                    onClick={() => setPaymentMethod(method)}
                    className={`px-2 py-1.5 rounded-xl text-[10px] font-extrabold transition-all border cursor-pointer ${
                      isSelected
                        ? 'bg-slate-900 text-amber-300 border-slate-900 shadow-2xs'
                        : 'bg-white text-slate-700 border-slate-200 hover:bg-slate-100'
                    }`}
                  >
                    {method}
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {/* Cart Items List */}
        <div className="space-y-2.5 max-h-[320px] overflow-y-auto pr-1">
          {cart.length === 0 ? (
            <div className="py-12 text-center text-slate-400">
              <ShoppingBag className="w-8 h-8 stroke-1 mx-auto mb-2 opacity-50" />
              <p className="text-xs font-medium">Cart is currently empty</p>
              <p className="text-[10px] text-slate-400 mt-0.5">
                {businessType === 'retail'
                  ? 'Tap packaged meats to add to cart'
                  : 'Select dishes from menu to order'}
              </p>
            </div>
          ) : (
            cart.map((item, idx) => {
              const itemAdditionsCost = item.selectedAdditions.reduce((sum, a) => sum + a.price, 0);
              const itemTotal = (item.dish.price + itemAdditionsCost) * item.quantity;

              return (
                <div
                  key={idx}
                  className="bg-white rounded-2xl p-2.5 border border-slate-200/70 shadow-2xs space-y-2"
                >
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0 flex-1">
                      <h4 className="text-xs font-bold text-slate-900 truncate">
                        {item.dish.name}
                      </h4>
                      <p className="text-[10px] text-slate-500 font-semibold">
                        {currency}{item.dish.price.toFixed(2)}
                      </p>

                      {/* Additions list if any */}
                      {item.selectedAdditions.length > 0 && (
                        <div className="mt-1 space-y-0.5">
                          {item.selectedAdditions.map((a) => (
                            <p key={a.id} className="text-[9px] text-slate-400 italic">
                              + {a.name} ({currency}{a.price.toFixed(2)})
                            </p>
                          ))}
                        </div>
                      )}
                    </div>

                    <button
                      onClick={() => onRemoveItem(idx)}
                      className="text-slate-300 hover:text-rose-500 transition-colors p-0.5 cursor-pointer"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>

                  <div className="flex items-center justify-between pt-1 border-t border-slate-100">
                    <div className="flex items-center gap-1.5 bg-slate-100 px-1.5 py-0.5 rounded-lg">
                      <button
                        onClick={() => onUpdateQuantity(idx, -1)}
                        className="w-5 h-5 rounded text-slate-700 hover:bg-slate-200 font-bold text-[10px] flex items-center justify-center cursor-pointer"
                      >
                        <Minus className="w-2.5 h-2.5" />
                      </button>
                      <span className="text-[11px] font-bold text-slate-900 w-4 text-center">
                        {item.quantity}
                      </span>
                      <button
                        onClick={() => onUpdateQuantity(idx, 1)}
                        className="w-5 h-5 rounded text-slate-700 hover:bg-slate-200 font-bold text-[10px] flex items-center justify-center cursor-pointer"
                      >
                        <Plus className="w-2.5 h-2.5" />
                      </button>
                    </div>

                    <span className="text-xs font-extrabold text-slate-900">
                      {currency}{itemTotal.toFixed(2)}
                    </span>
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>

      {/* Cart Summary & Order Action */}
      <div className="pt-3 border-t border-slate-200/80 space-y-3">
        <div className="space-y-1 text-xs">
          <div className="flex justify-between text-slate-500 text-[11px]">
            <span>Subtotal</span>
            <span>{currency}{subtotal.toFixed(2)}</span>
          </div>
          <div className="flex justify-between text-slate-500 text-[11px]">
            <span>Tax (10% VAT)</span>
            <span>{currency}{tax.toFixed(2)}</span>
          </div>
          <div className="flex justify-between font-black text-slate-900 text-sm pt-1 border-t border-slate-200/60">
            <span>Total Payable</span>
            <span className="text-pink-600">{currency}{total.toFixed(2)}</span>
          </div>
        </div>

        <button
          onClick={handleCheckoutClick}
          disabled={cart.length === 0}
          className={`w-full py-3 rounded-2xl font-bold text-xs shadow-md transition-all flex items-center justify-center gap-2 ${
            cart.length > 0
              ? 'bg-slate-900 hover:bg-slate-800 text-white cursor-pointer active:scale-95'
              : 'bg-slate-200 text-slate-400 cursor-not-allowed'
          }`}
        >
          <span>
            {paymentMethod === 'Cash'
              ? `Pay Cash & Calc Change (₱${total.toFixed(2)})`
              : `Complete Order (${paymentMethod})`}
          </span>
          <ArrowRight className="w-4 h-4" />
        </button>
      </div>

      {/* Cash Calculator Modal */}
      {isCashCalcOpen && (
        <CashCalculatorModal
          totalPayable={total}
          onClose={() => setIsCashCalcOpen(false)}
          onConfirmPayment={handleConfirmCashPayment}
        />
      )}

      {/* Success Modal Notification */}
      {isSuccessModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 backdrop-blur-xs">
          <div className="bg-white rounded-3xl p-6 text-center space-y-3 shadow-2xl max-w-xs animate-in zoom-in-95 border border-slate-100">
            <div className="w-12 h-12 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center mx-auto">
              <CheckCircle2 className="w-7 h-7" />
            </div>
            <h4 className="text-sm font-bold text-slate-900">
              {businessType === 'restaurant' ? 'Order Sent & Paid!' : 'Purchase Complete!'}
            </h4>
            <p className="text-xs text-slate-500">
              Paid via {paymentMethod} • Receipt Printed
            </p>
            {paymentMethod === 'Cash' && lastChange !== null && lastChange > 0 && (
              <div className="p-2.5 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs font-black">
                Return Change: ₱{lastChange.toFixed(2)}
              </div>
            )}
          </div>
        </div>
      )}
    </aside>
  );
};
