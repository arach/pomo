export interface WatchFaceConfig {
  id: string;
  name: string;
  description: string;
  author?: string;
  version?: string;
  progressBar?: WatchFaceProgressBar;
  theme: WatchFaceTheme;
  layout: WatchFaceLayout;
  components: WatchFaceComponent[];
}

export interface WatchFaceProgressBar {
  hidden?: boolean;
  height?: string;
  background?: string;
  color?: string;
  gradient?: string;
  glow?: string;
}

export interface WatchFaceTheme {
  // Legacy support
  background?: string;
  primaryColor?: string;
  secondaryColor?: string;
  textColor?: string;
  accentColor?: string;
  fontFamily?: string;
  
  // New structure
  colors?: {
    background?: string;
    foreground?: string;
    accent?: string;
    success?: string;
    warning?: string;
    error?: string;
    muted?: string;
    // Allow any additional custom colors
    [key: string]: string | undefined;
  };
  fonts?: {
    primary?: string;
    accent?: string;
  };
  customStyles?: Record<string, any>;
}

export interface WatchFaceLayout {
  type: 'circular' | 'rectangular' | 'custom';
  size?: {
    width: number | string;
    height: number | string;
  };
  padding?: number;
}

export interface WatchFaceComponent {
  type: 'time' | 'progress' | 'status' | 'controls' | 'custom';
  id: string;
  position?: {
    x?: number | string;
    y?: number | string;
  };
  style?: Record<string, any>;
  props?: Record<string, any>;
  properties?: Record<string, any>;
}

export interface WatchFaceProps {
  duration: number;
  remaining: number;
  isRunning: boolean;
  isPaused: boolean;
  progress: number;
  onStart: () => void;
  onPause: () => void;
  onStop: () => void;
  onReset: () => void;
  isCollapsed?: boolean;
  sessionName?: string | null;
}