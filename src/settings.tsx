import React from "react";
import ReactDOM from "react-dom/client";
import { WindowWrapper } from "./components/WindowWrapper";
import { SettingsPanel } from "./components/SettingsPanel";
import "./index.css";

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  <React.StrictMode>
    <WindowWrapper>
      <SettingsPanel isStandalone={true} />
    </WindowWrapper>
  </React.StrictMode>
);