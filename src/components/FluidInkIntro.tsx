import React, { useEffect, useRef, useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Play, SkipForward, Coffee, Sparkles } from 'lucide-react';

interface FluidInkIntroProps {
  onComplete: () => void;
  autoPlay?: boolean;
}

interface Particle {
  x: number;
  y: number;
  vx: number;
  vy: number;
  size: number;
  color: string;
  alpha: number;
  life: number;
  maxLife: number;
  angle: number;
  spin: number;
  targetX?: number;
  targetY?: number;
}

export const FluidInkIntro: React.FC<FluidInkIntroProps> = ({ onComplete, autoPlay = true }) => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const [phase, setPhase] = useState<'ink_flow' | 'morph_logo' | 'dissolve' | 'done'>('ink_flow');
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let animationFrameId: number;
    let startTime: number | null = null;
    const duration = 3800; // 3.8 seconds total

    // Resize canvas
    const resizeCanvas = () => {
      if (!canvas) return;
      const dpr = window.devicePixelRatio || 1;
      canvas.width = canvas.offsetWidth * dpr;
      canvas.height = canvas.offsetHeight * dpr;
      ctx.scale(dpr, dpr);
    };

    resizeCanvas();
    window.addEventListener('resize', resizeCanvas);

    const width = canvas.offsetWidth;
    const height = canvas.offsetHeight;
    const centerX = width / 2;
    const centerY = height / 2;

    // Ink drops physics particles
    const particles: Particle[] = [];
    const colors = [
      '#0f172a', // deep charcoal slate
      '#1e1b4b', // deep indigo ink
      '#312e81', // royal indigo
      '#18181b', // pure black ink
      '#4c1d95', // accent deep violet
    ];

    // Seed initial ink drop tendrils
    const numDrops = 180;
    for (let i = 0; i < numDrops; i++) {
      const angle = Math.random() * Math.PI * 2;
      const speed = 0.5 + Math.random() * 2.5;
      const dist = Math.random() * 40;

      // Target logo coordinates (Cup outline or circle)
      const logoAngle = (i / numDrops) * Math.PI * 2;
      const logoRadius = 42 + (i % 3) * 6;
      const targetX = centerX + Math.cos(logoAngle) * logoRadius;
      const targetY = centerY + Math.sin(logoAngle) * logoRadius - 10;

      particles.push({
        x: centerX + Math.cos(angle) * dist,
        y: centerY + Math.sin(angle) * dist,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        size: 12 + Math.random() * 38,
        color: colors[Math.floor(Math.random() * colors.length)],
        alpha: 0.15 + Math.random() * 0.65,
        life: 0,
        maxLife: duration,
        angle: Math.random() * Math.PI * 2,
        spin: (Math.random() - 0.5) * 0.03,
        targetX,
        targetY,
      });
    }

    const render = (time: number) => {
      if (!startTime) startTime = time;
      const elapsed = time - startTime;
      const p = Math.min(1, elapsed / duration);
      setProgress(p);

      if (elapsed < 1800) {
        setPhase('ink_flow');
      } else if (elapsed < 3000) {
        setPhase('morph_logo');
      } else if (elapsed < duration) {
        setPhase('dissolve');
      } else {
        setPhase('done');
        onComplete();
        return;
      }

      ctx.clearRect(0, 0, width, height);

      // Off-white soft studio background
      ctx.fillStyle = '#f8f9fa';
      ctx.fillRect(0, 0, width, height);

      // Soft ambient light vignette
      const bgGrad = ctx.createRadialGradient(centerX, centerY, 50, centerX, centerY, Math.max(width, height) * 0.7);
      bgGrad.addColorStop(0, 'rgba(255, 255, 255, 0.95)');
      bgGrad.addColorStop(1, 'rgba(241, 245, 249, 0.6)');
      ctx.fillStyle = bgGrad;
      ctx.fillRect(0, 0, width, height);

      // Render ink particles
      particles.forEach((part, index) => {
        part.life = elapsed;
        part.angle += part.spin;

        if (elapsed < 1800) {
          // Fluid swirl physics
          const swirlFactor = 0.02;
          const distToCenter = Math.hypot(part.x - centerX, part.y - centerY);
          const swirlAngle = Math.atan2(part.y - centerY, part.x - centerX) + Math.PI / 2;

          part.vx += Math.cos(swirlAngle) * swirlFactor + (Math.random() - 0.5) * 0.1;
          part.vy += Math.sin(swirlAngle) * swirlFactor + (Math.random() - 0.5) * 0.1;

          // Slow motion damping
          part.vx *= 0.96;
          part.vy *= 0.96;

          part.x += part.vx;
          part.y += part.vy;
        } else if (elapsed < 3000) {
          // Morph physics towards logo coordinates
          if (part.targetX !== undefined && part.targetY !== undefined) {
            const dx = part.targetX - part.x;
            const dy = part.targetY - part.y;
            part.x += dx * 0.08;
            part.y += dy * 0.08;
            part.size = part.size * 0.96 + 8 * 0.04; // Contract size into defined strokes
          }
        } else {
          // Dissolve away
          part.alpha *= 0.91;
          part.size *= 1.03;
        }

        // Draw organic fluid ink droplet
        ctx.save();
        ctx.globalAlpha = part.alpha;
        ctx.translate(part.x, part.y);
        ctx.rotate(part.angle);

        const gradient = ctx.createRadialGradient(0, 0, 0, 0, 0, part.size);
        gradient.addColorStop(0, part.color);
        gradient.addColorStop(0.7, part.color);
        gradient.addColorStop(1, 'rgba(15, 23, 42, 0)');

        ctx.fillStyle = gradient;
        ctx.beginPath();
        
        // Fluid deformed blob shape
        const radius = part.size;
        ctx.moveTo(radius, 0);
        for (let a = 0; a < Math.PI * 2; a += Math.PI / 4) {
          const r = radius * (1 + 0.18 * Math.sin(a * 3 + elapsed * 0.002));
          ctx.lineTo(Math.cos(a) * r, Math.sin(a) * r);
        }
        ctx.closePath();
        ctx.fill();

        ctx.restore();
      });

      // Gold / Deep Purple Accent Shimmer in morph phase
      if (elapsed >= 1800 && elapsed < 3200) {
        const morphP = (elapsed - 1800) / 1200;
        const goldAlpha = Math.sin(morphP * Math.PI) * 0.85;

        ctx.save();
        ctx.globalAlpha = goldAlpha;
        
        // Gold / Purple glowing halo
        const auraGrad = ctx.createRadialGradient(centerX, centerY, 20, centerX, centerY, 80);
        auraGrad.addColorStop(0, 'rgba(234, 179, 8, 0.4)'); // Gold shine
        auraGrad.addColorStop(0.5, 'rgba(236, 72, 153, 0.2)'); // Pink/Purple accent
        auraGrad.addColorStop(1, 'rgba(0,0,0,0)');

        ctx.fillStyle = auraGrad;
        ctx.beginPath();
        ctx.arc(centerX, centerY, 90, 0, Math.PI * 2);
        ctx.fill();

        ctx.restore();
      }

      animationFrameId = requestAnimationFrame(render);
    };

    animationFrameId = requestAnimationFrame(render);

    return () => {
      cancelAnimationFrame(animationFrameId);
      window.removeEventListener('resize', resizeCanvas);
    };
  }, [onComplete]);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-[#f8f9fa] overflow-hidden select-none">
      {/* Canvas Fluid Simulation */}
      <canvas ref={canvasRef} className="absolute inset-0 w-full h-full block cursor-default" />

      {/* Overlay Logo Morphing Badge */}
      <AnimatePresence>
        {(phase === 'morph_logo' || phase === 'dissolve') && (
          <motion.div
            initial={{ opacity: 0, scale: 0.8 }}
            animate={{ opacity: phase === 'dissolve' ? 0 : 1, scale: phase === 'dissolve' ? 1.15 : 1 }}
            exit={{ opacity: 0, scale: 1.2 }}
            transition={{ duration: 0.6, ease: 'easeOut' }}
            className="relative z-10 flex flex-col items-center justify-center text-center pointer-events-none"
          >
            {/* Logo Icon Badge */}
            <div className="relative flex items-center justify-center mb-3">
              <motion.div
                animate={{ rotate: 360 }}
                transition={{ duration: 12, repeat: Infinity, ease: 'linear' }}
                className="absolute w-24 h-24 rounded-full border-2 border-dashed border-amber-400/40"
              />
              <div className="w-16 h-16 rounded-2xl bg-gradient-to-tr from-pink-500 via-rose-500 to-amber-500 p-0.5 shadow-2xl shadow-pink-500/30 flex items-center justify-center">
                <div className="w-full h-full bg-slate-900 rounded-[14px] flex items-center justify-center">
                  <Coffee className="w-8 h-8 text-pink-400" />
                </div>
              </div>
              <Sparkles className="w-5 h-5 text-amber-400 absolute -top-1 -right-1 animate-pulse" />
            </div>

            {/* Wordmark Logo */}
            <motion.h1
              initial={{ y: 10, opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              transition={{ delay: 0.1 }}
              className="text-3xl font-black tracking-tight text-slate-900 flex items-center gap-1 font-serif italic"
            >
              Food<span className="not-italic font-sans text-pink-600">Pos</span>
            </motion.h1>
            <motion.p
              initial={{ opacity: 0 }}
              animate={{ opacity: 0.7 }}
              transition={{ delay: 0.2 }}
              className="text-xs tracking-widest text-slate-500 uppercase font-medium mt-1"
            >
              Cinematic Restaurant OS
            </motion.p>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Top Controller Bar */}
      <div className="absolute top-6 right-6 z-20 flex items-center gap-3">
        <button
          onClick={onComplete}
          className="px-4 py-2 rounded-full bg-slate-900/80 hover:bg-slate-900 text-white text-xs font-semibold backdrop-blur-md transition-all shadow-lg flex items-center gap-1.5 active:scale-95 cursor-pointer"
        >
          <span>Skip Intro</span>
          <SkipForward className="w-3.5 h-3.5" />
        </button>
      </div>

      {/* Bottom Progress Indicator */}
      <div className="absolute bottom-8 left-1/2 -translate-x-1/2 z-20 w-48 h-1 bg-slate-200 rounded-full overflow-hidden">
        <div
          className="h-full bg-gradient-to-r from-pink-500 via-purple-600 to-slate-900 transition-all duration-75"
          style={{ width: `${progress * 100}%` }}
        />
      </div>
    </div>
  );
};
