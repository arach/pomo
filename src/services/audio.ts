// Audio service for timer notifications

export class AudioService {
  private static audioContext: AudioContext | null = null;

  static playCompletionSound(volume: number = 0.5, soundType: string = 'default') {
    // Always use generated sounds for consistency
    this.playGeneratedSound(soundType, volume);
  }

  private static playGeneratedSound(soundType: string, volume: number = 0.5) {
    switch (soundType) {
      case 'bell':
        this.playBellSound(volume);
        break;
      case 'chime':
        this.playChimeSound(volume);
        break;
      case 'ding':
        this.playDingSound(volume);
        break;
      case 'default':
      default:
        this.playGeneratedBeep(volume);
        break;
    }
  }

  private static playBellSound(volume: number) {
    try {
      if (!this.audioContext) {
        this.audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
      }

      const ctx = this.audioContext;
      const osc1 = ctx.createOscillator();
      const osc2 = ctx.createOscillator();
      const gainNode = ctx.createGain();

      // Bell sound with two harmonics
      osc1.frequency.value = 800;
      osc2.frequency.value = 1600;
      osc1.type = 'sine';
      osc2.type = 'sine';

      osc1.connect(gainNode);
      osc2.connect(gainNode);
      gainNode.connect(ctx.destination);

      // Bell-like envelope
      gainNode.gain.setValueAtTime(0, ctx.currentTime);
      gainNode.gain.linearRampToValueAtTime(0.3 * volume, ctx.currentTime + 0.01);
      gainNode.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 1.5);

      osc1.start(ctx.currentTime);
      osc2.start(ctx.currentTime);
      osc1.stop(ctx.currentTime + 1.5);
      osc2.stop(ctx.currentTime + 1.5);
    } catch (error) {
      console.error('Failed to play bell sound:', error);
    }
  }

  private static playChimeSound(volume: number) {
    try {
      if (!this.audioContext) {
        this.audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
      }

      const ctx = this.audioContext;
      const notes = [523.25, 659.25, 783.99]; // C5, E5, G5 - major chord
      
      notes.forEach((freq, index) => {
        setTimeout(() => {
          const osc = ctx.createOscillator();
          const gainNode = ctx.createGain();
          
          osc.frequency.value = freq;
          osc.type = 'triangle'; // Softer sound
          
          osc.connect(gainNode);
          gainNode.connect(ctx.destination);
          
          gainNode.gain.setValueAtTime(0, ctx.currentTime);
          gainNode.gain.linearRampToValueAtTime(0.2 * volume, ctx.currentTime + 0.05);
          gainNode.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.8);
          
          osc.start(ctx.currentTime);
          osc.stop(ctx.currentTime + 0.8);
        }, index * 150);
      });
    } catch (error) {
      console.error('Failed to play chime sound:', error);
    }
  }

  private static playDingSound(volume: number) {
    try {
      if (!this.audioContext) {
        this.audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
      }

      const ctx = this.audioContext;
      const osc = ctx.createOscillator();
      const gainNode = ctx.createGain();
      
      // Higher pitched "ding"
      osc.frequency.value = 1200;
      osc.type = 'square';
      
      osc.connect(gainNode);
      gainNode.connect(ctx.destination);
      
      // Quick attack and decay
      gainNode.gain.setValueAtTime(0, ctx.currentTime);
      gainNode.gain.linearRampToValueAtTime(0.4 * volume, ctx.currentTime + 0.005);
      gainNode.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.3);
      
      osc.start(ctx.currentTime);
      osc.stop(ctx.currentTime + 0.3);
    } catch (error) {
      console.error('Failed to play ding sound:', error);
    }
  }

  private static playGeneratedBeep(volume: number = 0.5) {
    try {
      // Create or reuse AudioContext
      if (!this.audioContext) {
        this.audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
      }

      const ctx = this.audioContext;
      const oscillator = ctx.createOscillator();
      const gainNode = ctx.createGain();

      // Connect nodes
      oscillator.connect(gainNode);
      gainNode.connect(ctx.destination);

      // Configure the beep
      oscillator.frequency.value = 800; // Frequency in Hz
      oscillator.type = 'sine';

      // Create envelope for pleasant sound with volume control
      gainNode.gain.setValueAtTime(0, ctx.currentTime);
      gainNode.gain.linearRampToValueAtTime(0.3 * volume, ctx.currentTime + 0.01);
      gainNode.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.5);

      // Play the sound
      oscillator.start(ctx.currentTime);
      oscillator.stop(ctx.currentTime + 0.5);

      // Play a second beep after a short delay
      setTimeout(() => {
        const osc2 = ctx.createOscillator();
        const gain2 = ctx.createGain();
        
        osc2.connect(gain2);
        gain2.connect(ctx.destination);
        
        osc2.frequency.value = 1000;
        osc2.type = 'sine';
        
        gain2.gain.setValueAtTime(0, ctx.currentTime);
        gain2.gain.linearRampToValueAtTime(0.3 * volume, ctx.currentTime + 0.01);
        gain2.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.5);
        
        osc2.start(ctx.currentTime);
        osc2.stop(ctx.currentTime + 0.5);
      }, 600);

    } catch (error) {
      console.error('Failed to play generated beep:', error);
    }
  }
}