import React from 'react';
import { Table } from '../types';
import { Users, DollarSign, CheckCircle2, Clock, AlertCircle } from 'lucide-react';

interface FloorPlanViewProps {
  tables: Table[];
  onSelectTable: (table: Table) => void;
}

export const FloorPlanView: React.FC<FloorPlanViewProps> = ({ tables, onSelectTable }) => {
  const getStatusBadge = (status: Table['status']) => {
    switch (status) {
      case 'available':
        return <span className="px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800 font-bold text-[10px]">Available</span>;
      case 'occupied':
        return <span className="px-2 py-0.5 rounded-full bg-pink-100 text-pink-800 font-bold text-[10px]">Occupied</span>;
      case 'reserved':
        return <span className="px-2 py-0.5 rounded-full bg-amber-100 text-amber-800 font-bold text-[10px]">Reserved</span>;
    }
  };

  const sections = ['Main Hall', 'Terrace', 'VIP Lounge'] as const;

  return (
    <div className="flex-1 bg-white p-5 overflow-y-auto space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-sm font-extrabold text-slate-900 tracking-tight">Interactive Floor Plan</h2>
          <p className="text-xs text-slate-400">Live table availability & active order monitoring</p>
        </div>

        <div className="flex items-center gap-3 text-xs font-semibold">
          <div className="flex items-center gap-1.5">
            <span className="w-2.5 h-2.5 rounded-full bg-emerald-500" />
            <span className="text-slate-600">Available</span>
          </div>
          <div className="flex items-center gap-1.5">
            <span className="w-2.5 h-2.5 rounded-full bg-pink-500" />
            <span className="text-slate-600">Occupied</span>
          </div>
          <div className="flex items-center gap-1.5">
            <span className="w-2.5 h-2.5 rounded-full bg-amber-500" />
            <span className="text-slate-600">Reserved</span>
          </div>
        </div>
      </div>

      {/* Sections Grid */}
      <div className="space-y-6">
        {sections.map((section) => {
          const sectionTables = tables.filter((t) => t.section === section);

          return (
            <div key={section} className="space-y-3">
              <h3 className="text-xs font-extrabold text-slate-400 uppercase tracking-wider">
                {section}
              </h3>

              <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                {sectionTables.map((table) => {
                  const isOccupied = table.status === 'occupied';

                  return (
                    <div
                      key={table.id}
                      onClick={() => onSelectTable(table)}
                      className={`p-4 rounded-3xl border transition-all cursor-pointer flex flex-col justify-between space-y-3 group active:scale-95 ${
                        isOccupied
                          ? 'bg-pink-50/50 border-pink-200 hover:border-pink-300'
                          : table.status === 'reserved'
                          ? 'bg-amber-50/50 border-amber-200'
                          : 'bg-[#f8f9fa] border-slate-200/80 hover:bg-slate-100'
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <span className="text-base font-extrabold text-slate-900">
                          Table {table.number}
                        </span>
                        {getStatusBadge(table.status)}
                      </div>

                      <div className="space-y-1 text-xs text-slate-500 font-medium">
                        <div className="flex items-center gap-1.5">
                          <Users className="w-3.5 h-3.5 text-slate-400" />
                          <span>{table.seats} seats</span>
                          {table.guestCount && <span>• ({table.guestCount} seated)</span>}
                        </div>

                        {table.currentOrderTotal !== undefined && (
                          <div className="flex items-center gap-1.5 text-slate-900 font-extrabold">
                            <DollarSign className="w-3.5 h-3.5 text-pink-600" />
                            <span>Active: €{table.currentOrderTotal.toFixed(2)}</span>
                          </div>
                        )}
                      </div>

                      <button
                        className={`w-full py-1.5 rounded-xl font-bold text-[10px] transition-all ${
                          isOccupied
                            ? 'bg-slate-900 text-white hover:bg-slate-800'
                            : 'bg-white border border-slate-200 text-slate-700 hover:bg-slate-50'
                        }`}
                      >
                        {isOccupied ? 'View Order' : 'Assign / Reserve'}
                      </button>
                    </div>
                  );
                })}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};
