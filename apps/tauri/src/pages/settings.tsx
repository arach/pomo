import { useEffect } from 'react';
import { WindowWrapper } from '../components/WindowWrapper';
import { SettingsPanel } from '../components/SettingsPanel';

function SettingsPage() {
  useEffect(() => {
    // Set up any settings-specific listeners or initialization
  }, []);
  
  return (
    <WindowWrapper>
      <SettingsPanel isStandalone={true} />
    </WindowWrapper>
  );
}

export default SettingsPage;