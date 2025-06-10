// Audio service for timer notifications

export class AudioService {
  private static audioContext: AudioContext | null = null;

  static playCompletionSound() {
    try {
      // Try to play a sound file first
      const audio = new Audio('/notification.mp3');
      audio.play().catch(() => {
        // If file doesn't exist, use Web Audio API to generate a beep
        this.playGeneratedBeep();
      });
    } catch (error) {
      // Fallback to generated beep
      this.playGeneratedBeep();
    }
  }

  private static playGeneratedBeep() {
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

      // Create envelope for pleasant sound
      gainNode.gain.setValueAtTime(0, ctx.currentTime);
      gainNode.gain.linearRampToValueAtTime(0.3, ctx.currentTime + 0.01);
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
        gain2.gain.linearRampToValueAtTime(0.3, ctx.currentTime + 0.01);
        gain2.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.5);
        
        osc2.start(ctx.currentTime);
        osc2.stop(ctx.currentTime + 0.5);
      }, 600);

    } catch (error) {
      console.error('Failed to play generated beep:', error);
    }
  }
}