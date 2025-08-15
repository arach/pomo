// Audio service for timer notifications
import { AmbientComposer } from './ambient-composer';

interface SoundConfig {
  type: 'simple' | 'chord' | 'sequence' | 'complex';
  oscillatorType?: OscillatorType;
  frequencies?: number[];
  duration?: number;
  envelope?: {
    attack: number;
    decay?: number;
    sustain?: number;
    release: number;
  };
  filter?: {
    type: BiquadFilterType;
    frequency: number;
    Q?: number;
  };
  reverb?: number; // 0-1 wet/dry mix
  harmonics?: number[]; // For complex sounds
  sequence?: Array<{
    frequencies: number[];
    delay: number;
    duration: number;
  }>;
}

const SOUND_CONFIGS: Record<string, SoundConfig> = {
  zen: {
    type: 'complex',
    frequencies: [110],
    harmonics: [1, 2.4, 4.1],
    duration: 2.5,
    envelope: { attack: 0.2, sustain: 0.5, release: 2.5 },
    filter: { type: 'lowpass', frequency: 800, Q: 0.3 },
    reverb: 0.5
  },
  success: {
    type: 'sequence',
    sequence: [
      { frequencies: [261.63], delay: 0, duration: 0.15 },
      { frequencies: [329.63], delay: 100, duration: 0.15 },
      { frequencies: [392.00], delay: 200, duration: 0.15 },
      { frequencies: [523.25], delay: 300, duration: 0.15 }
    ],
    oscillatorType: 'triangle',
    filter: { type: 'lowpass', frequency: 2000, Q: 1 }
  },
  gentle: {
    type: 'sequence',
    sequence: [
      { frequencies: [261.63], delay: 0, duration: 0.8 },
      { frequencies: [392.00], delay: 200, duration: 0.8 },
      { frequencies: [659.25], delay: 400, duration: 0.8 }
    ],
    oscillatorType: 'sine',
    filter: { type: 'lowpass', frequency: 1500, Q: 0.5 },
    envelope: { attack: 0.1, release: 0.8 },
    reverb: 0.3
  },
  digital: {
    type: 'chord',
    frequencies: [440, 554.37, 659.25],
    duration: 0.3,
    oscillatorType: 'square',
    filter: { type: 'lowpass', frequency: 1200, Q: 5 },
    envelope: { attack: 0.01, release: 0.3 }
  },
  nature: {
    type: 'sequence',
    sequence: [
      { frequencies: [523.25, 659.25], delay: 0, duration: 0.5 },
      { frequencies: [587.33, 739.99], delay: 100, duration: 0.5 },
      { frequencies: [659.25, 830.61], delay: 200, duration: 0.7 }
    ],
    oscillatorType: 'sine',
    filter: { type: 'bandpass', frequency: 1000, Q: 0.5 },
    reverb: 0.4
  },
  retro: {
    type: 'sequence',
    sequence: [
      { frequencies: [440], delay: 0, duration: 0.1 },
      { frequencies: [880], delay: 100, duration: 0.1 },
      { frequencies: [440], delay: 200, duration: 0.1 },
      { frequencies: [1760], delay: 300, duration: 0.2 }
    ],
    oscillatorType: 'square',
    filter: { type: 'lowpass', frequency: 800, Q: 10 }
  },
  minimal: {
    type: 'simple',
    frequencies: [440],
    duration: 1,
    oscillatorType: 'sine',
    envelope: { attack: 0.05, sustain: 0.2, release: 1 },
    reverb: 0.6
  },
  // Legacy sounds
  bell: {
    type: 'complex',
    frequencies: [800],
    harmonics: [1, 2, 3, 4],
    duration: 2,
    oscillatorType: 'sine',
    envelope: { attack: 0.01, release: 2 },
    filter: { type: 'highpass', frequency: 400 }
  },
  chime: {
    type: 'chord',
    frequencies: [523.25, 659.25, 783.99],
    duration: 1.5,
    oscillatorType: 'sine',
    envelope: { attack: 0.05, release: 1.5 },
    reverb: 0.3
  },
  ding: {
    type: 'simple',
    frequencies: [880],
    duration: 0.5,
    oscillatorType: 'sine',
    envelope: { attack: 0.01, release: 0.5 }
  }
};

export class AudioService {
  private static audioContext: AudioContext | null = null;
  private static reverb: ConvolverNode | null = null;
  private static ambientNodes: Map<string, { source: OscillatorNode | AudioBufferSourceNode; gain: GainNode }> = new Map();

  static playCompletionSound(volume: number = 0.5, soundType: string = 'default') {
    console.log('🔊 Playing completion sound:', soundType, 'volume:', volume);
    try {
      // Always use generated sounds for consistency
      this.playGeneratedSound(soundType, volume);
      console.log('✅ Sound played successfully');
    } catch (error) {
      console.error('❌ Failed to play completion sound:', error);
    }
  }

  private static playGeneratedSound(soundType: string, volume: number = 0.5) {
    // Special cases that need custom implementation
    if (soundType === 'orchestra') {
      this.playOrchestraSound(volume);
      return;
    }
    if (soundType === 'bach') {
      this.playBachSound(volume);
      return;
    }
    if (soundType === 'beethoven') {
      this.playBeethovenSound(volume);
      return;
    }
    
    // Use configuration-based approach for standard sounds
    const config = SOUND_CONFIGS[soundType] || SOUND_CONFIGS['zen'];
    this.playSoundFromConfig(config, volume);
  }
  
  private static playSoundFromConfig(config: SoundConfig, volume: number) {
    try {
      this.initAudioContext();
      const ctx = this.audioContext!;
      const masterGain = ctx.createGain();
      
      // Set up output chain
      if (config.reverb && this.reverb) {
        const dry = ctx.createGain();
        const wet = ctx.createGain();
        dry.gain.value = 1 - config.reverb;
        wet.gain.value = config.reverb;
        
        masterGain.connect(dry);
        masterGain.connect(this.reverb);
        this.reverb.connect(wet);
        
        dry.connect(ctx.destination);
        wet.connect(ctx.destination);
      } else {
        masterGain.connect(ctx.destination);
      }
      
      switch (config.type) {
        case 'simple':
          this.playSimpleSound(ctx, masterGain, config, volume);
          break;
        case 'chord':
          this.playChordSound(ctx, masterGain, config, volume);
          break;
        case 'sequence':
          this.playSequenceSound(ctx, masterGain, config, volume);
          break;
        case 'complex':
          this.playComplexSound(ctx, masterGain, config, volume);
          break;
      }
    } catch (error) {
      console.error('Failed to play sound:', error);
    }
  }
  
  private static playSimpleSound(
    ctx: AudioContext,
    output: GainNode,
    config: SoundConfig,
    volume: number
  ) {
    const freq = config.frequencies?.[0] || 440;
    const duration = config.duration || 1;
    
    const osc = ctx.createOscillator();
    const gainNode = ctx.createGain();
    
    osc.type = config.oscillatorType || 'sine';
    osc.frequency.value = freq;
    
    // Apply filter if specified
    let chain: AudioNode = osc;
    if (config.filter) {
      const filter = ctx.createBiquadFilter();
      filter.type = config.filter.type;
      filter.frequency.value = config.filter.frequency;
      if (config.filter.Q) filter.Q.value = config.filter.Q;
      chain.connect(filter);
      chain = filter;
    }
    
    chain.connect(gainNode);
    gainNode.connect(output);
    
    // Apply envelope
    const env = config.envelope || { attack: 0.01, release: duration };
    gainNode.gain.setValueAtTime(0, ctx.currentTime);
    gainNode.gain.linearRampToValueAtTime(volume, ctx.currentTime + env.attack);
    if (env.sustain) {
      gainNode.gain.setValueAtTime(volume, ctx.currentTime + env.sustain);
    }
    gainNode.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + env.release);
    
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + duration);
  }
  
  private static playChordSound(
    ctx: AudioContext,
    output: GainNode,
    config: SoundConfig,
    volume: number
  ) {
    const frequencies = config.frequencies || [440, 554.37, 659.25];
    const duration = config.duration || 1;
    
    frequencies.forEach((freq, index) => {
      const osc = ctx.createOscillator();
      const gainNode = ctx.createGain();
      
      osc.type = config.oscillatorType || 'sine';
      osc.frequency.value = freq;
      
      // Apply filter if specified
      let chain: AudioNode = osc;
      if (config.filter) {
        const filter = ctx.createBiquadFilter();
        filter.type = config.filter.type;
        filter.frequency.value = config.filter.frequency;
        if (config.filter.Q) filter.Q.value = config.filter.Q;
        chain.connect(filter);
        chain = filter;
      }
      
      chain.connect(gainNode);
      gainNode.connect(output);
      
      // Reduce volume for higher notes to balance the chord
      const noteVolume = volume / (index + 1);
      
      // Apply envelope
      const env = config.envelope || { attack: 0.01, release: duration };
      gainNode.gain.setValueAtTime(0, ctx.currentTime);
      gainNode.gain.linearRampToValueAtTime(noteVolume, ctx.currentTime + env.attack);
      gainNode.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + env.release);
      
      osc.start(ctx.currentTime);
      osc.stop(ctx.currentTime + duration);
    });
  }
  
  private static playSequenceSound(
    ctx: AudioContext,
    output: GainNode,
    config: SoundConfig,
    volume: number
  ) {
    if (!config.sequence) return;
    
    config.sequence.forEach(({ frequencies, delay, duration }) => {
      setTimeout(() => {
        frequencies.forEach((freq, index) => {
          const osc = ctx.createOscillator();
          const gainNode = ctx.createGain();
          
          osc.type = config.oscillatorType || 'sine';
          osc.frequency.value = freq;
          
          // Apply filter if specified
          let chain: AudioNode = osc;
          if (config.filter) {
            const filter = ctx.createBiquadFilter();
            filter.type = config.filter.type;
            filter.frequency.value = config.filter.frequency;
            if (config.filter.Q) filter.Q.value = config.filter.Q;
            chain.connect(filter);
            chain = filter;
          }
          
          chain.connect(gainNode);
          gainNode.connect(output);
          
          // Apply envelope
          const env = config.envelope || { attack: 0.01, release: duration };
          gainNode.gain.setValueAtTime(0, ctx.currentTime);
          gainNode.gain.linearRampToValueAtTime(volume / (index + 1), ctx.currentTime + env.attack);
          gainNode.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + env.release);
          
          osc.start(ctx.currentTime);
          osc.stop(ctx.currentTime + duration);
        });
      }, delay);
    });
  }
  
  private static playComplexSound(
    ctx: AudioContext,
    output: GainNode,
    config: SoundConfig,
    volume: number
  ) {
    const fundamental = config.frequencies?.[0] || 440;
    const harmonics = config.harmonics || [1];
    const duration = config.duration || 1;
    
    const gainNode = ctx.createGain();
    
    // Create filter if specified
    let filterNode: BiquadFilterNode | undefined;
    if (config.filter) {
      filterNode = ctx.createBiquadFilter();
      filterNode.type = config.filter.type;
      filterNode.frequency.value = config.filter.frequency;
      if (config.filter.Q) filterNode.Q.value = config.filter.Q;
    }
    
    harmonics.forEach((harmonic, index) => {
      const osc = ctx.createOscillator();
      const oscGain = ctx.createGain();
      
      osc.frequency.value = fundamental * harmonic;
      osc.type = config.oscillatorType || 'sine';
      
      // Reduce volume for higher harmonics
      oscGain.gain.value = 0.3 / (index + 1);
      
      osc.connect(oscGain);
      if (filterNode) {
        oscGain.connect(filterNode);
      } else {
        oscGain.connect(gainNode);
      }
      
      osc.start(ctx.currentTime);
      osc.stop(ctx.currentTime + duration);
    });
    
    if (filterNode) {
      filterNode.connect(gainNode);
    }
    gainNode.connect(output);
    
    // Apply envelope
    const env = config.envelope || { attack: 0.01, release: duration };
    gainNode.gain.setValueAtTime(0, ctx.currentTime);
    gainNode.gain.linearRampToValueAtTime(volume * 0.15, ctx.currentTime + env.attack);
    if (env.sustain) {
      gainNode.gain.setValueAtTime(volume * 0.15, ctx.currentTime + env.sustain);
    }
    gainNode.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + env.release);
  }

  private static initAudioContext() {
    if (!this.audioContext) {
      console.log('🎵 Initializing audio context...');
      this.audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
      
      // Resume audio context if suspended (common in bundled apps)
      if (this.audioContext.state === 'suspended') {
        console.log('🔄 Audio context suspended, resuming...');
        this.audioContext.resume().then(() => {
          console.log('✅ Audio context resumed');
        }).catch(err => {
          console.error('❌ Failed to resume audio context:', err);
        });
      }
      
      this.createReverb();
      console.log('✅ Audio context initialized, state:', this.audioContext.state);
    }
  }

  private static createReverb() {
    if (!this.audioContext) return;
    
    const length = this.audioContext.sampleRate * 2;
    const impulse = this.audioContext.createBuffer(2, length, this.audioContext.sampleRate);
    
    for (let channel = 0; channel < 2; channel++) {
      const channelData = impulse.getChannelData(channel);
      for (let i = 0; i < length; i++) {
        channelData[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / length, 2);
      }
    }
    
    this.reverb = this.audioContext.createConvolver();
    this.reverb.buffer = impulse;
  }

  private static playOrchestraSound(volume: number) {
    try {
      this.initAudioContext();
      const ctx = this.audioContext!;
      
      // Majestic orchestral chord progression: I-V-I (C-G-C)
      const chordProgression = [
        { time: 0, chord: [130.81, 164.81, 196, 261.63], duration: 0.3 },     // C major
        { time: 0.3, chord: [146.83, 196, 246.94, 293.66], duration: 0.3 },  // G major
        { time: 0.6, chord: [130.81, 164.81, 196, 261.63], duration: 0.4 }   // C major (resolution)
      ];
      
      const masterGain = ctx.createGain();
      
      // Add reverb for concert hall feel
      if (this.reverb) {
        const dry = ctx.createGain();
        const wet = ctx.createGain();
        dry.gain.value = 0.6;
        wet.gain.value = 0.4;
        
        masterGain.connect(dry);
        masterGain.connect(this.reverb);
        this.reverb.connect(wet);
        
        dry.connect(ctx.destination);
        wet.connect(ctx.destination);
      } else {
        masterGain.connect(ctx.destination);
      }
      
      chordProgression.forEach(({ time, chord, duration }) => {
        // Strings section
        chord.forEach((freq, i) => {
          const osc = ctx.createOscillator();
          const filter = ctx.createBiquadFilter();
          const gain = ctx.createGain();
          
          osc.type = 'sawtooth';
          osc.frequency.value = freq;
          
          filter.type = 'lowpass';
          filter.frequency.value = 2000;
          filter.Q.value = 1;
          
          gain.gain.value = 0.15 / (i + 1);
          
          osc.connect(filter);
          filter.connect(gain);
          gain.connect(masterGain);
          
          osc.start(ctx.currentTime + time);
          osc.stop(ctx.currentTime + time + duration);
        });
        
        // Brass section (one octave higher)
        chord.slice(1).forEach((freq) => {
          const osc = ctx.createOscillator();
          const filter = ctx.createBiquadFilter();
          const gain = ctx.createGain();
          
          osc.type = 'square';
          osc.frequency.value = freq * 2;
          
          filter.type = 'lowpass';
          filter.frequency.value = 1000;
          filter.Q.value = 2;
          
          gain.gain.value = 0.05;
          
          osc.connect(filter);
          filter.connect(gain);
          gain.connect(masterGain);
          
          osc.start(ctx.currentTime + time);
          osc.stop(ctx.currentTime + time + duration);
        });
      });
      
      // Dynamic envelope for dramatic effect
      masterGain.gain.setValueAtTime(0, ctx.currentTime);
      masterGain.gain.linearRampToValueAtTime(0.5 * volume, ctx.currentTime + 0.1);
      masterGain.gain.setValueAtTime(0.5 * volume, ctx.currentTime + 0.8);
      masterGain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 1.3);
      
    } catch (error) {
      console.error('Failed to play orchestra sound:', error);
    }
  }

  private static playBachSound(volume: number) {
    try {
      this.initAudioContext();
      const ctx = this.audioContext!;
      
      // Bach-inspired fugue motif in C minor
      const theme = [
        { note: 261.63, time: 0, dur: 0.2 },      // C4
        { note: 233.08, time: 0.2, dur: 0.2 },    // Bb3
        { note: 261.63, time: 0.4, dur: 0.2 },    // C4
        { note: 196.00, time: 0.6, dur: 0.2 },    // G3
        { note: 207.65, time: 0.8, dur: 0.4 },    // Ab3
      ];
      
      const masterGain = ctx.createGain();
      
      // Add reverb for baroque church acoustics
      if (this.reverb) {
        const dry = ctx.createGain();
        const wet = ctx.createGain();
        dry.gain.value = 0.5;
        wet.gain.value = 0.5;
        
        masterGain.connect(dry);
        masterGain.connect(this.reverb);
        this.reverb.connect(wet);
        
        dry.connect(ctx.destination);
        wet.connect(ctx.destination);
      } else {
        masterGain.connect(ctx.destination);
      }
      
      // Play theme with harpsichord-like timbre
      theme.forEach(({ note, time, dur }) => {
        const osc = ctx.createOscillator();
        const osc2 = ctx.createOscillator();
        const gain = ctx.createGain();
        const filter = ctx.createBiquadFilter();
        
        // Harpsichord uses multiple harmonics
        osc.type = 'sawtooth';
        osc.frequency.value = note;
        osc2.type = 'square';
        osc2.frequency.value = note * 2;
        
        filter.type = 'bandpass';
        filter.frequency.value = note * 2;
        filter.Q.value = 2;
        
        osc.connect(filter);
        osc2.connect(filter);
        filter.connect(gain);
        gain.connect(masterGain);
        
        // Harpsichord-like pluck envelope
        gain.gain.setValueAtTime(0, ctx.currentTime + time);
        gain.gain.linearRampToValueAtTime(0.3 * volume, ctx.currentTime + time + 0.01);
        gain.gain.exponentialRampToValueAtTime(0.01 * volume, ctx.currentTime + time + dur * 0.3);
        gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + time + dur);
        
        osc.start(ctx.currentTime + time);
        osc.stop(ctx.currentTime + time + dur);
        osc2.start(ctx.currentTime + time);
        osc2.stop(ctx.currentTime + time + dur);
      });
      
      // Add a counter melody (simplified)
      setTimeout(() => {
        theme.forEach(({ note, time, dur }) => {
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();
          
          osc.type = 'triangle';
          osc.frequency.value = note * 1.5; // Fifth above
          
          osc.connect(gain);
          gain.connect(masterGain);
          
          gain.gain.setValueAtTime(0, ctx.currentTime + time);
          gain.gain.linearRampToValueAtTime(0.15 * volume, ctx.currentTime + time + 0.02);
          gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + time + dur);
          
          osc.start(ctx.currentTime + time);
          osc.stop(ctx.currentTime + time + dur);
        });
      }, 600);
      
    } catch (error) {
      console.error('Failed to play Bach sound:', error);
    }
  }

  private static playBeethovenSound(volume: number) {
    try {
      this.initAudioContext();
      const ctx = this.audioContext!;
      
      // Beethoven's 5th Symphony opening motif: "Fate knocking at the door"
      const motif = [
        { notes: [196.00], time: 0, dur: 0.15 },        // G3
        { notes: [196.00], time: 0.15, dur: 0.15 },     // G3
        { notes: [196.00], time: 0.3, dur: 0.15 },      // G3
        { notes: [155.56], time: 0.5, dur: 0.6 }        // Eb3 (held longer)
      ];
      
      const masterGain = ctx.createGain();
      masterGain.connect(ctx.destination);
      
      // Play the motif with dramatic orchestral sound
      motif.forEach(({ notes, time, dur }) => {
        notes.forEach(note => {
          // String section (main melody)
          const stringOsc = ctx.createOscillator();
          const stringGain = ctx.createGain();
          const stringFilter = ctx.createBiquadFilter();
          
          stringOsc.type = 'sawtooth';
          stringOsc.frequency.value = note;
          
          stringFilter.type = 'lowpass';
          stringFilter.frequency.value = 2000;
          stringFilter.Q.value = 1;
          
          stringOsc.connect(stringFilter);
          stringFilter.connect(stringGain);
          stringGain.connect(masterGain);
          
          // Dramatic volume envelope
          stringGain.gain.setValueAtTime(0, ctx.currentTime + time);
          stringGain.gain.linearRampToValueAtTime(0.4 * volume, ctx.currentTime + time + 0.02);
          stringGain.gain.setValueAtTime(0.4 * volume, ctx.currentTime + time + dur * 0.8);
          stringGain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + time + dur);
          
          stringOsc.start(ctx.currentTime + time);
          stringOsc.stop(ctx.currentTime + time + dur);
          
          // Add timpani for dramatic effect on the longer note
          if (dur > 0.3) {
            const timpani = ctx.createOscillator();
            const timpaniGain = ctx.createGain();
            const timpaniFilter = ctx.createBiquadFilter();
            
            timpani.type = 'sine';
            timpani.frequency.value = note / 2; // One octave lower
            
            timpaniFilter.type = 'lowpass';
            timpaniFilter.frequency.value = 100;
            timpaniFilter.Q.value = 5;
            
            timpani.connect(timpaniFilter);
            timpaniFilter.connect(timpaniGain);
            timpaniGain.connect(masterGain);
            
            // Timpani hit
            timpaniGain.gain.setValueAtTime(0, ctx.currentTime + time);
            timpaniGain.gain.linearRampToValueAtTime(0.3 * volume, ctx.currentTime + time + 0.01);
            timpaniGain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + time + 0.3);
            
            timpani.start(ctx.currentTime + time);
            timpani.stop(ctx.currentTime + time + 0.3);
          }
        });
      });
      
    } catch (error) {
      console.error('Failed to play Beethoven sound:', error);
    }
  }

  // Ambient sound system for watchfaces
  static startAmbientSound(type: string, volume: number = 0.1) {
    this.stopAmbientSound(); // Stop any existing ambient sound
    
    // Check if it's a composed soundscape
    const composedSoundscapes = ['zen-garden', 'urban-flow', 'forest-depths', 'ocean-meditation', 'cosmic-journey'];
    if (composedSoundscapes.includes(type)) {
      AmbientComposer.startSoundscape(type, volume);
      return;
    }
    
    try {
      this.initAudioContext();
      const ctx = this.audioContext!;
      
      switch (type) {
        case 'metallic-resonance':
          this.startMetallicResonance(ctx, volume);
          break;
        case 'gentle-cosmos':
          this.startGentleCosmos(ctx, volume);
          break;
        case 'nature-harmony':
          this.startNatureHarmony(ctx, volume);
          break;
        case 'deep-ocean':
          this.startDeepOcean(ctx, volume);
          break;
        case 'ethereal-bells':
          this.startEtherealBells(ctx, volume);
          break;
        case 'crystal-cave':
          this.startCrystalCave(ctx, volume);
          break;
        case 'aurora-waves':
          this.startAuroraWaves(ctx, volume);
          break;
        case 'quantum-hum':
          this.startQuantumHum(ctx, volume);
          break;
      }
    } catch (error) {
      console.error('Failed to start ambient sound:', error);
    }
  }
  
  static stopAmbientSound() {
    // Stop composed soundscapes
    AmbientComposer.stopSoundscape();
    
    // Stop individual ambient sounds
    this.ambientNodes.forEach(({ source, gain }) => {
      try {
        gain.gain.exponentialRampToValueAtTime(0.001, (this.audioContext?.currentTime || 0) + 0.5);
        setTimeout(() => {
          source.stop();
          source.disconnect();
          gain.disconnect();
        }, 600);
      } catch (error) {
        // Ignore errors when stopping
      }
    });
    this.ambientNodes.clear();
  }
  
  private static startMetallicResonance(ctx: AudioContext, volume: number) {
    // Clean metallic sound with minimal harmonics
    const fundamental = 220; // A3
    
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    const filter = ctx.createBiquadFilter();
    
    osc.type = 'sine';
    osc.frequency.value = fundamental;
    
    // Subtle vibrato for organic feel
    const lfo = ctx.createOscillator();
    const lfoGain = ctx.createGain();
    lfo.frequency.value = 0.5; // Very slow
    lfoGain.gain.value = 2; // ±2Hz variation
    lfo.connect(lfoGain);
    lfoGain.connect(osc.frequency);
    lfo.start();
    
    // Gentle filtering
    filter.type = 'lowpass';
    filter.frequency.value = 1000;
    filter.Q.value = 2;
    
    osc.connect(filter);
    filter.connect(gain);
    gain.connect(ctx.destination);
    
    // Fade in
    gain.gain.setValueAtTime(0, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(volume * 0.3, ctx.currentTime + 2);
    
    osc.start();
    
    this.ambientNodes.set('metallic-main', { source: osc, gain });
  }
  
  private static startGentleCosmos(ctx: AudioContext, volume: number) {
    // Clean, ethereal space sound
    const baseFreq = 110; // A2
    
    // Main drone
    const osc1 = ctx.createOscillator();
    const gain1 = ctx.createGain();
    const filter1 = ctx.createBiquadFilter();
    
    osc1.type = 'sine';
    osc1.frequency.value = baseFreq;
    
    filter1.type = 'lowpass';
    filter1.frequency.value = 500;
    filter1.Q.value = 1;
    
    // Subtle chorus effect
    const delay = ctx.createDelay(0.1);
    delay.delayTime.value = 0.02;
    const delayGain = ctx.createGain();
    delayGain.gain.value = 0.3;
    
    osc1.connect(filter1);
    filter1.connect(gain1);
    gain1.connect(ctx.destination);
    
    // Chorus path
    filter1.connect(delay);
    delay.connect(delayGain);
    delayGain.connect(ctx.destination);
    
    // Gentle fade in
    gain1.gain.setValueAtTime(0, ctx.currentTime);
    gain1.gain.linearRampToValueAtTime(volume * 0.2, ctx.currentTime + 3);
    
    osc1.start();
    
    this.ambientNodes.set('cosmos-main', { source: osc1, gain: gain1 });
  }
  
  private static startNatureHarmony(ctx: AudioContext, volume: number) {
    // Wind-like noise generator
    const bufferSize = 2 * ctx.sampleRate;
    const noiseBuffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
    const output = noiseBuffer.getChannelData(0);
    
    for (let i = 0; i < bufferSize; i++) {
      output[i] = Math.random() * 2 - 1;
    }
    
    const whiteNoise = ctx.createBufferSource();
    whiteNoise.buffer = noiseBuffer;
    whiteNoise.loop = true;
    
    // Create wind effect with filters
    const windFilter = ctx.createBiquadFilter();
    windFilter.type = 'bandpass';
    windFilter.frequency.value = 500;
    windFilter.Q.value = 0.5;
    
    // LFO for wind variation
    const lfo = ctx.createOscillator();
    const lfoGain = ctx.createGain();
    lfo.frequency.value = 0.2;
    lfoGain.gain.value = 200;
    lfo.connect(lfoGain);
    lfoGain.connect(windFilter.frequency);
    
    const windGain = ctx.createGain();
    windGain.gain.value = volume * 0.1;
    
    whiteNoise.connect(windFilter);
    windFilter.connect(windGain);
    windGain.connect(ctx.destination);
    
    whiteNoise.start();
    lfo.start();
    
    this.ambientNodes.set('nature-wind', { source: whiteNoise, gain: windGain });
    
    // Bird-like tones
    const birdInterval = setInterval(() => {
      if (!this.ambientNodes.has('nature-wind')) {
        clearInterval(birdInterval);
        return;
      }
      
      const birdOsc = ctx.createOscillator();
      const birdGain = ctx.createGain();
      const birdFilter = ctx.createBiquadFilter();
      
      birdOsc.type = 'sine';
      birdOsc.frequency.value = 1000 + Math.random() * 1000;
      
      birdFilter.type = 'bandpass';
      birdFilter.frequency.value = birdOsc.frequency.value;
      birdFilter.Q.value = 10;
      
      birdOsc.connect(birdFilter);
      birdFilter.connect(birdGain);
      birdGain.connect(ctx.destination);
      
      // Chirp envelope
      birdGain.gain.setValueAtTime(0, ctx.currentTime);
      birdGain.gain.linearRampToValueAtTime(volume * 0.05, ctx.currentTime + 0.05);
      birdGain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.3);
      
      // Pitch sweep
      birdOsc.frequency.setValueAtTime(birdOsc.frequency.value, ctx.currentTime);
      birdOsc.frequency.exponentialRampToValueAtTime(birdOsc.frequency.value * 1.2, ctx.currentTime + 0.1);
      
      birdOsc.start();
      birdOsc.stop(ctx.currentTime + 0.3);
    }, 5000 + Math.random() * 5000);
  }
  
  private static startDeepOcean(ctx: AudioContext, volume: number) {
    // Deep ocean drone
    const droneFreq = 55; // Low A
    
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    const filter = ctx.createBiquadFilter();
    
    osc.type = 'triangle';
    osc.frequency.value = droneFreq;
    
    // Deep filtering
    filter.type = 'lowpass';
    filter.frequency.value = 200;
    filter.Q.value = 1;
    
    // Slow volume oscillation (like ocean waves)
    const lfo = ctx.createOscillator();
    const lfoGain = ctx.createGain();
    lfo.frequency.value = 0.1; // Very slow
    lfoGain.gain.value = volume * 0.1;
    lfo.connect(lfoGain);
    lfoGain.connect(gain.gain);
    
    osc.connect(filter);
    filter.connect(gain);
    gain.connect(ctx.destination);
    
    gain.gain.value = volume * 0.2;
    
    osc.start();
    lfo.start();
    
    this.ambientNodes.set('ocean-drone', { source: osc, gain });
    
    // Add some higher frequency "bubbles"
    const bubbleInterval = setInterval(() => {
      if (!this.ambientNodes.has('ocean-drone')) {
        clearInterval(bubbleInterval);
        return;
      }
      
      const bubble = ctx.createOscillator();
      const bubbleGain = ctx.createGain();
      
      bubble.type = 'sine';
      bubble.frequency.value = 200 + Math.random() * 300;
      
      bubble.connect(bubbleGain);
      bubbleGain.connect(ctx.destination);
      
      // Bubble pop envelope
      bubbleGain.gain.setValueAtTime(0, ctx.currentTime);
      bubbleGain.gain.linearRampToValueAtTime(volume * 0.03, ctx.currentTime + 0.1);
      bubbleGain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.5);
      
      bubble.start();
      bubble.stop(ctx.currentTime + 0.5);
    }, 3000 + Math.random() * 4000);
  }
  
  private static startEtherealBells(ctx: AudioContext, volume: number) {
    const bellInterval = setInterval(() => {
      // Pentatonic scale for pleasant harmony
      const notes = [261.63, 293.66, 329.63, 392.00, 440.00]; // C, D, E, G, A
      const note = notes[Math.floor(Math.random() * notes.length)];
      
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      const filter = ctx.createBiquadFilter();
      
      osc.type = 'sine';
      osc.frequency.value = note * (1 + Math.floor(Math.random() * 3)); // Random octave
      
      filter.type = 'highpass';
      filter.frequency.value = 200;
      filter.Q.value = 1;
      
      osc.connect(filter);
      filter.connect(gain);
      
      // Add reverb for ethereal quality
      if (this.reverb) {
        const dry = ctx.createGain();
        const wet = ctx.createGain();
        dry.gain.value = 0.3;
        wet.gain.value = 0.7;
        
        gain.connect(dry);
        gain.connect(this.reverb);
        this.reverb.connect(wet);
        
        dry.connect(ctx.destination);
        wet.connect(ctx.destination);
      } else {
        gain.connect(ctx.destination);
      }
      
      // Bell envelope
      gain.gain.setValueAtTime(0, ctx.currentTime);
      gain.gain.linearRampToValueAtTime(volume * 0.1, ctx.currentTime + 0.01);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 4);
      
      osc.start();
      osc.stop(ctx.currentTime + 4);
    }, 4000 + Math.random() * 4000);
    
    // Store the interval ID for cleanup
    this.ambientNodes.set('bells-interval', { 
      source: { stop: () => clearInterval(bellInterval) } as any, 
      gain: ctx.createGain() 
    });
  }
  
  private static startCrystalCave(ctx: AudioContext, volume: number) {
    // Multiple resonant frequencies (like crystal formations)
    const crystalFreqs = [523.25, 659.25, 783.99, 1046.50]; // C5, E5, G5, C6
    
    crystalFreqs.forEach((freq, index) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      const filter = ctx.createBiquadFilter();
      const panner = ctx.createStereoPanner();
      
      osc.type = 'triangle';
      osc.frequency.value = freq;
      
      // High Q filter for resonance
      filter.type = 'bandpass';
      filter.frequency.value = freq;
      filter.Q.value = 30;
      
      // Stereo positioning
      panner.pan.value = (index - 1.5) / 2; // Distribute across stereo field
      
      osc.connect(filter);
      filter.connect(gain);
      gain.connect(panner);
      panner.connect(ctx.destination);
      
      // Very quiet, with occasional "pings"
      gain.gain.value = volume * 0.02;
      
      // Random amplitude modulation for shimmer
      const lfo = ctx.createOscillator();
      const lfoGain = ctx.createGain();
      lfo.frequency.value = 0.1 + Math.random() * 0.2;
      lfoGain.gain.value = volume * 0.01;
      lfo.connect(lfoGain);
      lfoGain.connect(gain.gain);
      
      osc.start();
      lfo.start();
      
      this.ambientNodes.set(`crystal-${index}`, { source: osc, gain });
    });
  }
  
  private static startAuroraWaves(ctx: AudioContext, volume: number) {
    // Slowly morphing harmonics
    const baseFreq = 165; // E3
    
    const osc1 = ctx.createOscillator();
    const osc2 = ctx.createOscillator();
    const gain1 = ctx.createGain();
    const gain2 = ctx.createGain();
    const masterGain = ctx.createGain();
    const filter = ctx.createBiquadFilter();
    
    osc1.type = 'sine';
    osc2.type = 'sine';
    osc1.frequency.value = baseFreq;
    osc2.frequency.value = baseFreq * 1.5; // Perfect fifth
    
    // Filter sweep for aurora-like effect
    filter.type = 'bandpass';
    filter.frequency.value = 400;
    filter.Q.value = 2;
    
    // LFO for filter sweep
    const filterLfo = ctx.createOscillator();
    const filterLfoGain = ctx.createGain();
    filterLfo.frequency.value = 0.05; // Very slow
    filterLfoGain.gain.value = 300;
    filterLfo.connect(filterLfoGain);
    filterLfoGain.connect(filter.frequency);
    
    osc1.connect(gain1);
    osc2.connect(gain2);
    gain1.connect(filter);
    gain2.connect(filter);
    filter.connect(masterGain);
    masterGain.connect(ctx.destination);
    
    // Cross-fade between oscillators
    gain1.gain.value = volume * 0.1;
    gain2.gain.value = 0;
    
    // Slow crossfade LFO
    const crossfadeLfo = ctx.createOscillator();
    const crossfadeLfoGain = ctx.createGain();
    crossfadeLfo.frequency.value = 0.03;
    crossfadeLfoGain.gain.value = volume * 0.05;
    crossfadeLfo.connect(crossfadeLfoGain);
    crossfadeLfoGain.connect(gain2.gain);
    
    // Inverse for osc1
    const inverseGain = ctx.createGain();
    inverseGain.gain.value = -1;
    crossfadeLfoGain.connect(inverseGain);
    inverseGain.connect(gain1.gain);
    
    osc1.start();
    osc2.start();
    filterLfo.start();
    crossfadeLfo.start();
    
    this.ambientNodes.set('aurora-main', { source: osc1, gain: masterGain });
  }
  
  private static startQuantumHum(ctx: AudioContext, volume: number) {
    // Microtonal intervals for otherworldly sound
    const baseFreq = 100;
    const intervals = [1, 1.0293, 1.0595, 1.122]; // Microtonal ratios
    
    intervals.forEach((ratio, index) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      const tremolo = ctx.createOscillator();
      const tremoloGain = ctx.createGain();
      
      osc.type = 'sine';
      osc.frequency.value = baseFreq * ratio;
      
      // Tremolo effect
      tremolo.type = 'sine';
      tremolo.frequency.value = 4 + index * 0.5; // Different rates
      tremoloGain.gain.value = 0.3;
      
      tremolo.connect(tremoloGain);
      tremoloGain.connect(gain.gain);
      
      osc.connect(gain);
      gain.connect(ctx.destination);
      
      gain.gain.value = volume * 0.05 / (index + 1);
      
      osc.start();
      tremolo.start();
      
      this.ambientNodes.set(`quantum-${index}`, { source: osc, gain });
    });
  }
}