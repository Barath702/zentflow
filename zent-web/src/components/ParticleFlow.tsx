import { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useZent } from '@/context/ZentContext';

interface Particle {
  id: string;
  x: number;
  y: number;
  delay: number;
}

const ParticleFlow = () => {
  const { activeAnimations } = useZent();
  const [particles, setParticles] = useState<Particle[]>([]);

  useEffect(() => {
    if (activeAnimations.length === 0) {
      setParticles([]);
      return;
    }

    const interval = setInterval(() => {
      const newParticles: Particle[] = activeAnimations.flatMap(anim => 
        Array.from({ length: 3 }, (_, i) => ({
          id: `${anim.transferId}-${Date.now()}-${i}`,
          x: Math.random() * 40 - 20,
          y: Math.random() * 40 - 20,
          delay: i * 0.15,
        }))
      );
      setParticles(prev => [...prev.slice(-30), ...newParticles]);
    }, 300);

    return () => clearInterval(interval);
  }, [activeAnimations]);

  if (activeAnimations.length === 0) return null;

  return (
    <div className="absolute inset-0 pointer-events-none overflow-hidden z-20">
      <AnimatePresence>
        {particles.map(p => (
          <motion.div
            key={p.id}
            initial={{ 
              x: '50%', 
              y: '30%', 
              scale: 0, 
              opacity: 1 
            }}
            animate={{ 
              x: `calc(50% + ${p.x}px)`,
              y: '70%', 
              scale: [0, 1.5, 0.5],
              opacity: [0, 1, 0],
            }}
            exit={{ opacity: 0 }}
            transition={{ 
              duration: 1.2, 
              delay: p.delay,
              ease: 'easeInOut',
            }}
            className="absolute w-2 h-2 rounded-full gradient-primary"
            style={{ filter: 'blur(0.5px)' }}
          />
        ))}
      </AnimatePresence>

    </div>
  );
};

export default ParticleFlow;
