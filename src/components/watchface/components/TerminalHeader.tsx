interface TerminalHeaderProps {
  text?: string;
  style?: React.CSSProperties;
}

export function TerminalHeader({ text = 'POMO.EXE v1.0', style }: TerminalHeaderProps) {
  return (
    <div style={style} className="font-mono">
      {text}
    </div>
  );
}