import { WatchFaceConfig, WatchFaceProps } from '../../types/watchface';
// Shared components
import { ProgressRing } from './shared/ProgressRing';
import { TimeDisplay } from './shared/TimeDisplay';
import { StatusDisplay } from './shared/StatusDisplay';
import { ControlButtons } from './shared/ControlButtons';
import { ClickableTimeWrapper } from './shared/ClickableTimeWrapper';

// Terminal watchface components
import { TerminalProgress } from './watchfaces/terminal/TerminalProgress';
import { TerminalHeader } from './watchfaces/terminal/TerminalHeader';
import { TerminalCursor } from './watchfaces/terminal/TerminalCursor';
import { TerminalBootMessages } from './watchfaces/terminal/TerminalBootMessages';
import { TerminalControls } from './watchfaces/terminal/TerminalControls';

// Retro Digital watchface components
import { DigitalDisplay } from './watchfaces/retro-digital/DigitalDisplay';
import { RetroProgress } from './watchfaces/retro-digital/RetroProgress';
import { LCDProgress } from './watchfaces/retro-digital/LCDProgress';

// Minimal watchface components
import { MinimalProgress } from './watchfaces/minimal/MinimalProgress';
import { MinimalProgressDot } from './watchfaces/minimal/MinimalProgressDot';
import { MinimalCompact } from './watchfaces/minimal/MinimalCompact';

// Neon watchface components
import { NeonRing } from './watchfaces/neon/NeonRing';
import { NeonProgress } from './watchfaces/neon/NeonProgress';

// Chronograph watchface components
import { ChronographFace } from './watchfaces/chronograph/ChronographFace';
import { ChronographMarkings } from './watchfaces/chronograph/ChronographMarkings';
import { ChronographSweep } from './watchfaces/chronograph/ChronographSweep';

// Default watchface components
import { DefaultProgress } from './watchfaces/default/DefaultProgress';

// Unused components (for now)
import { NpmLoader } from './unused/NpmLoader';
import { TopProgressBar } from './unused/TopProgressBar';

interface WatchFaceRendererProps extends WatchFaceProps {
  config: WatchFaceConfig;
  onTimeClick?: () => void;
}

export function WatchFaceRenderer({ config, onTimeClick, ...props }: WatchFaceRendererProps) {
  const { theme, layout, components } = config;
  
  const formatTime = (seconds: number): string => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };
  
  // Inject custom styles if defined
  if (theme.customStyles?.['@import']) {
    const styleId = `watchface-${config.id}-styles`;
    let styleElement = document.getElementById(styleId);
    if (!styleElement) {
      styleElement = document.createElement('style');
      styleElement.id = styleId;
      styleElement.textContent = theme.customStyles['@import'];
      document.head.appendChild(styleElement);
    }
  }

  const renderComponent = (component: any) => {
    switch (component.type) {
      case 'progress':
        if (component.id === 'top-progress') {
          return (
            <TopProgressBar
              key={component.id}
              progress={props.progress}
              style={component.style}
            />
          );
        }
        return (
          <ProgressRing
            key={component.id}
            progress={props.progress}
            style={component.style}
            theme={theme}
            showElapsed={component.props?.showElapsed}
          />
        );
      
      case 'time':
        return (
          <ClickableTimeWrapper 
            key={component.id}
            onClick={onTimeClick}
            isRunning={props.isRunning}
          >
            <TimeDisplay
              remaining={props.remaining}
              style={component.style}
              position={component.position}
            />
          </ClickableTimeWrapper>
        );
      
      case 'status':
        return (
          <StatusDisplay
            key={component.id}
            isRunning={props.isRunning}
            isPaused={props.isPaused}
            remaining={props.remaining}
            style={component.style}
            format={component.props?.format}
            position={component.position}
          />
        );
      
      case 'controls':
        return (
          <ControlButtons
            key={component.id}
            {...props}
            style={component.style}
            buttonStyle={component.props?.buttonStyle}
            showLabels={component.props?.showLabels}
            size={component.props?.size}
            position={component.position}
          />
        );
      
      case 'custom':
        switch (component.properties?.component || component.id) {
          case 'ascii-progress':
            return (
              <TerminalProgress
                key={component.id}
                progress={props.progress}
                style={component.style}
                {...component.props}
              />
            );
          
          case 'terminal-header':
            // Replace {duration} placeholder with actual duration in minutes
            let headerText = component.props?.text || '';
            if (headerText.includes('{duration}')) {
              const durationMinutes = Math.floor(props.duration / 60);
              headerText = headerText.replace('{duration}', `${durationMinutes}m`);
            }
            return (
              <TerminalHeader
                key={component.id}
                text={headerText}
                style={component.style}
              />
            );
          
          case 'digital-display':
            return (
              <ClickableTimeWrapper 
                key={component.id}
                onClick={onTimeClick}
                isRunning={props.isRunning}
              >
                <DigitalDisplay
                  value={formatTime(props.remaining)}
                  style={component.style}
                />
              </ClickableTimeWrapper>
            );
          
          case 'retro-progress':
            return (
              <RetroProgress
                key={component.id}
                progress={props.progress}
                style={component.properties?.style}
              />
            );
          
          case 'minimal-progress':
            return (
              <MinimalProgress
                key={component.id}
                progress={props.progress}
                style={component.properties?.style}
              />
            );
          
          case 'lcd-progress':
            return (
              <LCDProgress
                key={component.id}
                progress={props.progress}
                style={component.properties?.style}
              />
            );
          
          case 'minimal-progress-dot':
            return (
              <MinimalProgressDot
                key={component.id}
                progress={props.progress}
                isRunning={props.isRunning}
                isPaused={props.isPaused}
                style={component.properties?.style}
              />
            );
          
          case 'minimal-compact':
            return (
              <MinimalCompact
                key={component.id}
                remaining={props.remaining}
                progress={props.progress}
                isRunning={props.isRunning}
                isPaused={props.isPaused}
                onStart={props.onStart}
                onPause={props.onPause}
                onStop={props.onStop}
              />
            );
          
          case 'neon-progress':
            return (
              <NeonProgress
                key={component.id}
                progress={props.progress}
                style={component.properties?.style}
              />
            );
          
          case 'neon-ring':
            return (
              <NeonRing
                key={component.id}
                radius={component.properties?.radius || 100}
                style={component.properties?.style}
              />
            );
          
          case 'chronograph-face':
            return (
              <ChronographFace
                key={component.id}
                style={component.properties?.style}
              />
            );
          
          case 'chronograph-markings':
            return (
              <ChronographMarkings
                key={component.id}
                style={component.properties?.style}
              />
            );
          
          case 'chronograph-sweep':
            return (
              <ChronographSweep
                key={component.id}
                progress={props.progress}
                style={component.properties?.style}
              />
            );
          
          case 'default-progress':
            return (
              <DefaultProgress
                key={component.id}
                progress={props.progress}
                style={component.properties?.style}
              />
            );
          
          case 'npm-loader':
            return (
              <NpmLoader
                key={component.id}
                progress={props.progress}
                isRunning={props.isRunning && !props.isPaused}
                style={component.properties?.style}
                reverse={component.properties?.reverse !== false}
              />
            );
          
          case 'terminal-cursor':
            return (
              <TerminalCursor
                key={component.id}
                style={component.properties?.style}
                position={component.position}
              />
            );
          
          case 'terminal-boot':
            return (
              <TerminalBootMessages
                key={component.id}
                isRunning={props.isRunning}
                style={component.properties?.style}
                position={component.position}
              />
            );
          
          case 'terminal-controls':
            return (
              <TerminalControls
                key={component.id}
                isRunning={props.isRunning}
                isPaused={props.isPaused}
                onStart={props.onStart}
                onPause={props.onPause}
                onStop={props.onStop}
                style={component.properties?.style}
              />
            );
          
          default:
            return null;
        }
      
      default:
        return null;
    }
  };

  // Always fill the entire window space
  const containerStyle: React.CSSProperties = {
    width: '100%',
    height: '100%',
    padding: layout.padding,
    background: theme.colors?.background || theme.background,
    color: theme.colors?.foreground || theme.textColor,
    fontFamily: theme.fonts?.primary || theme.fontFamily,
    position: 'relative',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    ...getCustomStyles(theme.customStyles),
    ...theme.customStyles?.['.container']
  };

  // Content container for the actual watchface elements
  const contentStyle: React.CSSProperties = {
    width: typeof layout.size?.width === 'string' ? layout.size.width : (layout.size?.width || 'auto'),
    height: typeof layout.size?.height === 'string' ? layout.size.height : (layout.size?.height || 'auto'),
    position: 'relative',
    display: 'flex',
    alignItems: layout.type === 'rectangular' ? 'flex-start' : 'center',
    justifyContent: layout.type === 'rectangular' ? 'flex-start' : 'center'
  };

  const className = theme.customStyles?.scanlines ? 'watch-face-container scanlines' : 'watch-face-container';
  
  // Separate edge-positioned components from regular components
  const edgeComponents = components.filter(comp => {
    // Components positioned at bottom edge (footers, bottom controls, etc)
    if (comp.position?.y === 'bottom') return true;
    // Components with explicit edge positioning in style
    if (comp.style?.bottom && typeof comp.style.bottom === 'string' && 
        (comp.style.bottom.includes('-') || parseInt(comp.style.bottom) < 50)) return true;
    return false;
  });
  const regularComponents = components.filter(comp => 
    !edgeComponents.includes(comp)
  );
  
  return (
    <div className={className} style={containerStyle}>
      <div style={contentStyle}>
        {layout.type === 'circular' && (
          <div className="flex flex-col items-center justify-center h-full relative">
            {regularComponents.map(renderComponent)}
          </div>
        )}
        
        {layout.type === 'rectangular' && (
          <div className="flex flex-col h-full w-full items-start justify-start">
            {regularComponents.map(renderComponent)}
          </div>
        )}
      </div>
      
      {/* Render edge-positioned components outside the padded content */}
      {edgeComponents.map(renderComponent)}
    </div>
  );
}

function getCustomStyles(customStyles?: Record<string, any>) {
  if (!customStyles) return {};
  
  const styles: React.CSSProperties = {};
  
  if (customStyles.scanlines) {
    styles.backgroundImage = `
      repeating-linear-gradient(
        0deg,
        rgba(0, 255, 0, 0.03),
        rgba(0, 255, 0, 0.03) 1px,
        transparent 1px,
        transparent 2px
      )
    `;
  }
  
  if (customStyles.glow) {
    styles.filter = 'contrast(1.1)';
  }
  
  return styles;
}