import React from "react";
import ReactDOM from "react-dom/client";
import { WindowWrapper } from "./components/WindowWrapper";
import { CustomTitleBar } from "./components/CustomTitleBar";
import { SettingsPanel } from "./components/SettingsPanel";
import "./index.css";

function SettingsApp() {
  return (
    <WindowWrapper>
      <CustomTitleBar title="Settings" showCollapseButton={false} />
      <div className="flex-1 overflow-hidden">
        <SettingsPanel isStandalone={true} />
      </div>
    </WindowWrapper>
  );
}

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  <React.StrictMode>
    <SettingsApp />
  </React.StrictMode>
);