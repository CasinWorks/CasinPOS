import React, { useState } from 'react';
import { X, Delete, CheckCircle2, DollarSign, Calculator, ArrowRight, Banknote } from 'lucide-react';

interface CashCalculatorModalProps {
  totalPayable: number;
  onClose: () => void;
  onConfirmPayment: (cashReceived: number, changeGiven: number) => void;
}

export const CashCalculatorModal: React.FC<CashCalculatorModalProps> = ({
  totalPayable,
  onClose,
  onConfirmPayment,
}) => {
  const [cashInput, setCashInput] = useState<string>('');

  const cashReceived = parseFloat(cashInput) || 0;
  const changeGiven = cashReceived - totalPayable;
  const isSufficient = cashReceived >= totalPayable;

  // Preset bill buttons in Philippine Pesos (₱)
  const presetBills = [
    { label: 'Exact', amount: totalPayable },
    { label: '₱100', amount: 100 },
    { label: '₱200', amount: 200 },
    { label: '₱500', amount: 500 },
    { label: '₱1,000', amount: 1000 },
    { label: '₱2,000', amount: 2000 },
  ];

  const handleKeypadPress = (val: string) => {
    if (val === 'C') {
      setCashInput('');
    } else if (val === 'DEL') {
      setCashInput((prev) => prev.slice(0, -1));
    } else if (val === '.') {
      if (!cashInput.includes('.')) {
        setCashInput((prev) => (prev === '' ? '0.' : prev + '.'));
      }
    } else {
      setCashInput((prev) => prev + val);
    }
  };

  const handlePresetSelect = (amount: number) => {
    setCashInput(amount.toFixed(0));
  };

  const handleConfirm = () => {
    if (!isSufficient) return;
    onConfirmPayment(cashReceived, changeGiven);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs animate-in fade-in duration-200 select-none">
      <div className="bg-white rounded-3xl max-w-md w-full overflow-hidden shadow-2xl border border-slate-100 flex flex-col relative">
        {/* Modal Header */}
        <div className="p-4 bg-gradient-to-r from-slate-900 via-slate-800 to-slate-900 text-white flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-xl bg-amber-400 text-slate-950 font-black flex items-center justify-center">
              <Banknote className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-xs font-bold tracking-tight">Cash Payment Calculator</h3>
              <p className="text-[10px] text-slate-300">Register Cash Received & Calculate Change</p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="w-7 h-7 rounded-full bg-white/10 hover:bg-white/20 text-white flex items-center justify-center transition-colors cursor-pointer"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        <div className="p-5 space-y-4">
          {/* Order Total vs Cash Received Readout */}
          <div className="grid grid-cols-2 gap-3">
            <div className="bg-slate-100 p-3 rounded-2xl border border-slate-200">
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                Total Payable
              </span>
              <span className="text-lg font-black text-slate-900 mt-0.5 block">
                ₱{totalPayable.toFixed(2)}
              </span>
            </div>

            <div
              className={`p-3 rounded-2xl border transition-all ${
                cashInput && !isSufficient
                  ? 'bg-rose-50 border-rose-300'
                  : 'bg-emerald-50 border-emerald-200'
              }`}
            >
              <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider block">
                Cash Tendered
              </span>
              <div className="flex items-center justify-between mt-0.5">
                <span className="text-lg font-black text-slate-900">
                  ₱{cashInput ? parseFloat(cashInput).toFixed(2) : '0.00'}
                </span>
              </div>
            </div>
          </div>

          {/* Change Display Card */}
          <div
            className={`p-4 rounded-2xl border flex items-center justify-between transition-all ${
              isSufficient && cashReceived > 0
                ? 'bg-emerald-500 text-white border-emerald-600 shadow-md'
                : 'bg-slate-100 border-slate-200 text-slate-400'
            }`}
          >
            <div>
              <span className="text-[10px] font-extrabold uppercase tracking-widest opacity-80 block">
                Change to Return to Customer
              </span>
              <span className="text-2xl font-black mt-0.5 block">
                {isSufficient ? `₱${changeGiven.toFixed(2)}` : '₱0.00 (Insufficient Cash)'}
              </span>
            </div>

            {isSufficient && (
              <div className="w-10 h-10 rounded-2xl bg-white/20 backdrop-blur-xs flex items-center justify-center text-white">
                <CheckCircle2 className="w-6 h-6" />
              </div>
            )}
          </div>

          {/* Quick Cash Presets */}
          <div>
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block mb-1.5">
              Quick Cash Denominations
            </span>
            <div className="grid grid-cols-3 gap-2">
              {presetBills.map((bill, idx) => (
                <button
                  key={idx}
                  onClick={() => handlePresetSelect(bill.amount)}
                  className="py-2 px-3 rounded-xl bg-slate-100 hover:bg-slate-200 active:bg-slate-300 text-slate-800 text-xs font-bold transition-all border border-slate-200/80 cursor-pointer text-center"
                >
                  {bill.label}
                </button>
              ))}
            </div>
          </div>

          {/* Numeric Keypad */}
          <div>
            <div className="grid grid-cols-3 gap-2">
              {['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', 'DEL'].map((key) => (
                <button
                  key={key}
                  onClick={() => handleKeypadPress(key)}
                  className={`py-3 rounded-2xl text-sm font-extrabold transition-all border cursor-pointer active:scale-95 ${
                    key === 'DEL'
                      ? 'bg-rose-50 text-rose-600 border-rose-200 hover:bg-rose-100 flex items-center justify-center'
                      : 'bg-slate-50 hover:bg-slate-100 text-slate-900 border-slate-200'
                  }`}
                >
                  {key === 'DEL' ? <Delete className="w-4 h-4" /> : key}
                </button>
              ))}
            </div>
          </div>

          {/* Confirm Button */}
          <button
            onClick={handleConfirm}
            disabled={!isSufficient}
            className={`w-full py-3.5 rounded-2xl font-black text-xs transition-all shadow-md flex items-center justify-center gap-2 ${
              isSufficient
                ? 'bg-slate-900 hover:bg-slate-800 text-white cursor-pointer active:scale-95'
                : 'bg-slate-200 text-slate-400 cursor-not-allowed'
            }`}
          >
            <span>Confirm Cash Payment & Print Receipt</span>
            <ArrowRight className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  );
};
