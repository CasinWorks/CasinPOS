import React from 'react';
import { Tablet, Maximize2, Sparkles, Moon, Sun } from 'lucide-react';

interface IPadFrameProps {
  children: React.ReactNode;
  viewMode: 'ipad' | 'fullscreen';
  onChangeViewMode: (mode: 'ipad' | 'fullscreen') => void;
  onReplayIntro: () => void;
}

export const IPadFrame: React.FC<IPadFrameProps> = ({
  children,
  viewMode,
  onChangeViewMode,
  onReplayIntro,
}) => {
  if (viewMode === 'fullscreen') {
    return (
      <div className="w-full h-screen bg-slate-900 text-slate-100 flex flex-col overflow-hidden">
        {/* Top Control Overlay */}
        <div className="bg-slate-950/90 border-b border-slate-800 px-4 py-2 flex items-center justify-between z-30 shrink-0">
          <div className="flex items-center gap-2">
            <span className="w-2.5 h-2.5 rounded-full bg-emerald-500 animate-pulse" />
            <span className="text-xs font-bold text-slate-300">FoodPos • Live POS OS</span>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={onReplayIntro}
              className="px-2.5 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold flex items-center gap-1.5 transition-colors cursor-pointer"
            >
              <Sparkles className="w-3.5 h-3.5 text-amber-400" />
              <span>Intro Animation</span>
            </button>

            <button
              onClick={() => onChangeViewMode('ipad')}
              className="px-2.5 py-1 rounded-lg bg-pink-600 hover:bg-pink-700 text-white text-xs font-bold flex items-center gap-1.5 transition-colors cursor-pointer"
            >
              <Tablet className="w-3.5 h-3.5" />
              <span>iPad Frame Mode</span>
            </button>
          </div>
        </div>

        <div className="flex-1 relative overflow-hidden bg-white text-slate-900">
          {children}
        </div>
      </div>
    );
  }

  return (
    <div className="w-full min-h-screen bg-[#111315] flex flex-col items-center justify-center p-3 sm:p-6 select-none overflow-x-hidden">
      {/* Top Floating Control Bar */}
      <div className="w-full max-w-5xl flex items-center justify-between mb-3 text-slate-400 text-xs px-2">
        <div className="flex items-center gap-2">
          <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
          <span className="font-semibold text-slate-300">FoodPos iPad Pro 12.9" Mockup</span>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={onReplayIntro}
            className="px-3 py-1.5 rounded-xl bg-slate-800/80 hover:bg-slate-800 text-slate-200 text-xs font-bold flex items-center gap-1.5 transition-colors border border-slate-700 cursor-pointer"
          >
            <Sparkles className="w-3.5 h-3.5 text-amber-400" />
            <span>Replay Fluid Ink</span>
          </button>

          <button
            onClick={() => onChangeViewMode('fullscreen')}
            className="px-3 py-1.5 rounded-xl bg-slate-800/80 hover:bg-slate-800 text-slate-200 text-xs font-bold flex items-center gap-1.5 transition-colors border border-slate-700 cursor-pointer"
          >
            <Maximize2 className="w-3.5 h-3.5" />
            <span>Fullscreen</span>
          </button>
        </div>
      </div>

      {/* iPad Outer Metal Body Frame */}
      <div className="relative w-full max-w-[1140px] aspect-[4/3] bg-gradient-to-b from-slate-200 via-slate-100 to-slate-300 p-3 sm:p-4 rounded-[40px] shadow-[0_25px_60px_-15px_rgba(0,0,0,0.8)] border border-slate-400/40 flex flex-col">
        {/* Left Camera Dot Sensor */}
        <div className="absolute left-2.5 top-1/2 -translate-y-1/2 flex flex-col items-center gap-1.5 z-20">
          <span className="w-2.5 h-2.5 rounded-full bg-slate-800 border border-slate-600 shadow-inner" />
          <span className="w-1.5 h-1.5 rounded-full bg-slate-700" />
        </div>

        {/* Interior iPad Screen Canvas */}
        <div className="w-full h-full bg-white rounded-[28px] overflow-hidden flex shadow-inner relative border border-slate-200">
          {children}
        </div>
      </div>
    </div>
  );
};
