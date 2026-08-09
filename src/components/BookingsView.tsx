import React from 'react';
import { Booking } from '../types';
import { Calendar, Phone, Users, Clock, CheckCircle2 } from 'lucide-react';

interface BookingsViewProps {
  bookings: Booking[];
}

export const BookingsView: React.FC<BookingsViewProps> = ({ bookings }) => {
  return (
    <div className="flex-1 bg-white p-5 overflow-y-auto space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-sm font-extrabold text-slate-900 tracking-tight">Table Reservations</h2>
          <p className="text-xs text-slate-400">Scheduled guest bookings for today</p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {bookings.map((booking) => (
          <div key={booking.id} className="bg-[#f8f9fa] rounded-3xl p-4 border border-slate-200/80 space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 rounded-xl bg-pink-100 text-pink-700 font-bold flex items-center justify-center text-xs">
                  <Calendar className="w-4 h-4" />
                </div>
                <div>
                  <h4 className="text-xs font-bold text-slate-900">{booking.customerName}</h4>
                  <p className="text-[10px] text-slate-400 font-medium">Table {booking.tableNumber}</p>
                </div>
              </div>

              <span className="px-2.5 py-0.5 rounded-full bg-emerald-100 text-emerald-800 font-bold text-[10px]">
                {booking.status}
              </span>
            </div>

            <div className="grid grid-cols-2 gap-2 text-xs font-medium text-slate-600 bg-white p-2.5 rounded-2xl border border-slate-100">
              <div className="flex items-center gap-1.5">
                <Clock className="w-3.5 h-3.5 text-slate-400" />
                <span>{booking.time} ({booking.date})</span>
              </div>
              <div className="flex items-center gap-1.5">
                <Users className="w-3.5 h-3.5 text-slate-400" />
                <span>{booking.guests} Guests</span>
              </div>
              <div className="col-span-2 flex items-center gap-1.5 text-slate-500 text-[11px]">
                <Phone className="w-3.5 h-3.5 text-slate-400" />
                <span>{booking.phone}</span>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};
