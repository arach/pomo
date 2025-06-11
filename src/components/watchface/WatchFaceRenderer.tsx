import { WatchFaceConfig, WatchFaceProps } from '../../types/watchface';
import { ProgressRing } from './components/ProgressRing';
import { TimeDisplay } from './components/TimeDisplay';
import { StatusDisplay } from './components/StatusDisplay';
import { ControlButtons } from './components/ControlButtons';
import { TerminalProgress } from './components/TerminalProgress';
import { TerminalHeader } from './components/TerminalHeader';
import { DigitalDisplay } from './components/DigitalDisplay';
import { RetroProgress } from './components/RetroProgress';
import { MinimalProgress } from './components/MinimalProgress';
import { NeonRing } from './components/NeonRing';
import { ChronographFace } from './components/ChronographFace';
import { ChronographMarkings } from './components/ChronographMarkings';
import { NpmLoader } from './components/NpmLoader';
import { TerminalCursor } from './components/TerminalCursor';
import { TerminalBootMessages } from './components/TerminalBootMessages';

interface WatchFaceRendererProps extends WatchFaceProps {
  config: WatchFaceConfig;
}

export function WatchFaceRenderer({ config, ...props }: WatchFaceRendererProps) {
  const { theme, layout, components } = config;
  
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
          <TimeDisplay
            key={component.id}
            remaining={props.remaining}
            style={component.style}
            position={component.position}
          />
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
            return (
              <TerminalHeader
                key={component.id}
                text={component.props?.text}
                style={component.style}
              />
            );
          
          case 'digital-display':
            return (
              <DigitalDisplay
                key={component.id}
                style={component.properties?.style}
              />
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
  
  return (
    <div className={className} style={containerStyle}>
      <div style={contentStyle}>
        {layout.type === 'circular' && (
          <div className="flex flex-col items-center justify-center h-full relative">
            {components.map(renderComponent)}
          </div>
        )}
        
        {layout.type === 'rectangular' && (
          <div className="flex flex-col h-full w-full items-start justify-start">
            {components.map(renderComponent)}
          </div>
        )}
      </div>
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