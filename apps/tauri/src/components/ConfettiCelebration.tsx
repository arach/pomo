import { useEffect, useState } from 'react';

interface ConfettiParticle {
  id: number;
  x: number;
  y: number;
  vx: number;
  vy: number;
  rotation: number;
  rotationSpeed: number;
  color: string;
  size: number;
  shape: 'circle' | 'square' | 'triangle';
}

interface ConfettiCelebrationProps {
  isActive: boolean;
  duration?: number;
}

const COLORS = [
  '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FECA57',
  '#FF9FF3', '#54A0FF', '#5F27CD', '#00D2D3', '#FF9F43'
];

const SHAPES = ['circle', 'square', 'triangle'] as const;

export function ConfettiCelebration({ isActive, duration = 3000 }: ConfettiCelebrationProps) {
  const [particles, setParticles] = useState<ConfettiParticle[]>([]);
  const [isAnimating, setIsAnimating] = useState(false);

  useEffect(() => {
    if (!isActive) {
      setIsAnimating(false);
      setParticles([]);
      return;
    }

    setIsAnimating(true);
    
    // Create initial burst of particles
    const initialParticles: ConfettiParticle[] = [];
    const particleCount = 100;
    
    for (let i = 0; i < particleCount; i++) {
      initialParticles.push({
        id: i,
        x: Math.random() * window.innerWidth,
        y: -20,
        vx: (Math.random() - 0.5) * 8,
        vy: Math.random() * 3 + 2,
        rotation: Math.random() * 360,
        rotationSpeed: (Math.random() - 0.5) * 8,
        color: COLORS[Math.floor(Math.random() * COLORS.length)],
        size: Math.random() * 8 + 4,
        shape: SHAPES[Math.floor(Math.random() * SHAPES.length)]
      });
    }
    
    setParticles(initialParticles);

    // Animation loop
    let animationFrame: number;
    let startTime = Date.now();
    
    const animate = () => {
      const now = Date.now();
      const elapsed = now - startTime;
      
      if (elapsed > duration) {
        setIsAnimating(false);
        setParticles([]);
        return;
      }
      
      setParticles(prevParticles => 
        prevParticles
          .map(particle => ({
            ...particle,
            x: particle.x + particle.vx,
            y: particle.y + particle.vy,
            rotation: particle.rotation + particle.rotationSpeed,
            vy: particle.vy + 0.1, // gravity
          }))
          .filter(particle => particle.y < window.innerHeight + 50) // Remove particles that fall off screen
      );
      
      animationFrame = requestAnimationFrame(animate);
    };
    
    animationFrame = requestAnimationFrame(animate);
    
    return () => {
      if (animationFrame) {
        cancelAnimationFrame(animationFrame);
      }
    };
  }, [isActive, duration]);

  if (!isAnimating || particles.length === 0) {
    return null;
  }

  return (
    <div className="fixed inset-0 pointer-events-none z-[9999] overflow-hidden">
      {particles.map(particle => (
        <div
          key={particle.id}
          className="absolute"
          style={{
            left: `${particle.x}px`,
            top: `${particle.y}px`,
            transform: `rotate(${particle.rotation}deg)`,
            transition: 'none',
          }}
        >
          {particle.shape === 'circle' && (
            <div
              className="rounded-full"
              style={{
                width: `${particle.size}px`,
                height: `${particle.size}px`,
                backgroundColor: particle.color,
              }}
            />
          )}
          {particle.shape === 'square' && (
            <div
              style={{
                width: `${particle.size}px`,
                height: `${particle.size}px`,
                backgroundColor: particle.color,
              }}
            />
          )}
          {particle.shape === 'triangle' && (
            <div
              style={{
                width: 0,
                height: 0,
                borderLeft: `${particle.size/2}px solid transparent`,
                borderRight: `${particle.size/2}px solid transparent`,
                borderBottom: `${particle.size}px solid ${particle.color}`,
              }}
            />
          )}
        </div>
      ))}
      
      {/* Celebration text overlay */}
      <div className="absolute inset-0 flex items-center justify-center">
        <div className="text-center animate-bounce">
          <div className="text-6xl mb-4">🎉</div>
          <div className="text-2xl font-bold text-white drop-shadow-lg">
            Great Work!
          </div>
          <div className="text-lg text-white/80 drop-shadow-md">
            Pomodoro Complete!
          </div>
        </div>
      </div>
    </div>
  );
}
