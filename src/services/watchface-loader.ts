import { WatchFaceConfig } from '../types/watchface';
import defaultConfig from '../watchfaces/default.json';
import rolodexConfig from '../watchfaces/rolodex.json';
import terminalConfig from '../watchfaces/terminal.json';
import retroDigitalConfig from '../watchfaces/retro-digital.json';
import retroLcdConfig from '../watchfaces/retro-lcd.json';
import neonConfig from '../watchfaces/neon.json';
import { invoke } from '@tauri-apps/api/core';

export class WatchFaceLoader {
  private static watchFaces: Map<string, WatchFaceConfig> = new Map();
  private static customWatchFaces: Map<string, WatchFaceConfig> = new Map();
  
  static async loadBuiltInFaces() {
    // Load built-in watch faces
    this.watchFaces.set('default', defaultConfig as WatchFaceConfig);
    this.watchFaces.set('rolodex', rolodexConfig as WatchFaceConfig);
    this.watchFaces.set('terminal', terminalConfig as WatchFaceConfig);
    this.watchFaces.set('retro-digital', retroDigitalConfig as WatchFaceConfig);
    this.watchFaces.set('retro-lcd', retroLcdConfig as WatchFaceConfig);
    this.watchFaces.set('neon', neonConfig as WatchFaceConfig);
  }
  
  static getWatchFace(id: string): WatchFaceConfig | null {
    return this.watchFaces.get(id) || this.customWatchFaces.get(id) || null;
  }
  
  static getAllWatchFaces(): WatchFaceConfig[] {
    return [
      ...Array.from(this.watchFaces.values()),
      ...Array.from(this.customWatchFaces.values())
    ];
  }
  
  static validateWatchFace(config: any): config is WatchFaceConfig {
    // Basic validation
    if (!config.id || typeof config.id !== 'string') return false;
    if (!config.name || typeof config.name !== 'string') return false;
    if (!config.version || typeof config.version !== 'string') return false;
    if (!config.theme || typeof config.theme !== 'object') return false;
    if (!config.layout || typeof config.layout !== 'object') return false;
    if (!Array.isArray(config.components)) return false;
    
    // Validate theme
    const theme = config.theme;
    if (!theme.colors || typeof theme.colors !== 'object') return false;
    if (!theme.colors.background || !theme.colors.foreground) return false;
    
    // Validate layout
    const layout = config.layout;
    if (!['circular', 'rectangular', 'custom'].includes(layout.type)) return false;
    
    // Validate components
    for (const component of config.components) {
      if (!component.type || !component.id) return false;
      if (!['progress', 'time', 'status', 'controls', 'custom'].includes(component.type)) return false;
    }
    
    return true;
  }
  
  static async loadCustomFace(config: WatchFaceConfig) {
    // Validate config
    if (!this.validateWatchFace(config)) {
      throw new Error('Invalid watch face configuration');
    }
    
    // Ensure custom faces have unique IDs
    const customId = `custom_${config.id}`;
    config.id = customId;
    
    this.customWatchFaces.set(customId, config);
  }
  
  
  static removeCustomFace(id: string): boolean {
    return this.customWatchFaces.delete(id);
  }
  
  static getCustomFaces(): WatchFaceConfig[] {
    return Array.from(this.customWatchFaces.values());
  }
  
  static async saveCustomFacesToStorage() {
    const customFaces = Array.from(this.customWatchFaces.entries());
    await invoke('save_custom_watchfaces', { watchfaces: customFaces });
  }
  
  static async loadCustomFacesFromStorage() {
    try {
      const customFaces = await invoke<Array<[string, WatchFaceConfig]>>('load_custom_watchfaces');
      for (const [id, config] of customFaces) {
        this.customWatchFaces.set(id, config);
      }
    } catch (error) {
      console.error('Failed to load custom watchfaces:', error);
    }
  }
}