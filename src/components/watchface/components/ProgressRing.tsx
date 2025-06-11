interface ProgressRingProps {
  progress: number;
  style?: any;
  theme: any;
  showElapsed?: boolean;
}

export function ProgressRing({ progress, style, theme, showElapsed }: ProgressRingProps) {
  const radius = style?.radius || 66;
  const strokeWidth = style?.strokeWidth || 6;
  const circumference = 2 * Math.PI * radius;
  
  // If showElapsed is true, we want the ring to fill up as time passes
  // Otherwise, it empties (default countdown behavior)
  const displayProgress = showElapsed ? progress : (100 - progress);
  const offset = circumference * (1 - displayProgress / 100);

  return (
    <div className="relative w-full h-full">
      {style?.gradient && (
        <div className="absolute inset-0 rounded-full bg-gradient-to-br from-primary/20 to-primary/5 blur-xl" />
      )}
      <svg className="absolute inset-0 w-full h-full transform -rotate-90 z-10">
        {style?.gradient && (
          <defs>
            <linearGradient id="progressGradient" x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" stopColor={theme.primaryColor} />
              <stop offset="100%" stopColor={theme.accentColor} />
            </linearGradient>
          </defs>
        )}
      
      <circle
        cx="50%"
        cy="50%"
        r={radius}
        stroke={theme.secondaryColor}
        strokeWidth={strokeWidth}
        fill="none"
      />
      
      <circle
        cx="50%"
        cy="50%"
        r={radius}
        stroke={style?.gradient ? "url(#progressGradient)" : theme.primaryColor}
        strokeWidth={strokeWidth}
        fill="none"
        strokeDasharray={circumference}
        strokeDashoffset={offset}
        strokeLinecap="round"
        className="transition-all duration-1000 ease-linear"
      />
    </svg>
    </div>
  );
}