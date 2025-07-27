// Ambient Sound Composer - Dynamic layered soundscapes

interface SoundLayer {
  id: string;
  type: 'continuous' | 'intermittent' | 'random';
  probability?: number; // For random sounds (0-1)
  interval?: { min: number; max: number }; // For intermittent sounds
  volume: { min: number; max: number };
  variations?: number; // Number of variations for this sound
}

interface SoundscapeConfig {
  id: string;
  name: string;
  description: string;
  baseLayers: SoundLayer[]; // Always playing
  randomLayers: SoundLayer[]; // Randomly added/removed
  environmentalLayers: SoundLayer[]; // Time/weather based
}

export class AmbientComposer {
  private static audioContext: AudioContext | null = null;
  private static activeLayers: Map<string, {
    nodes: any[];
    layer: SoundLayer;
    startTime: number;
  }> = new Map();
  
  private static compositionInterval: ReturnType<typeof setInterval> | null = null;
  private static currentSoundscape: SoundscapeConfig | null = null;
  
  // Soundscape definitions
  private static soundscapes: Record<string, SoundscapeConfig> = {
    'zen-garden': {
      id: 'zen-garden',
      name: 'Zen Garden',
      description: 'Peaceful Japanese garden ambience',
      baseLayers: [
        { id: 'water-stream', type: 'continuous', volume: { min: 0.1, max: 0.2 } },
        { id: 'wind-chimes', type: 'intermittent', interval: { min: 10000, max: 30000 }, volume: { min: 0.05, max: 0.1 } }
      ],
      randomLayers: [
        { id: 'bird-chirp', type: 'random', probability: 0.3, volume: { min: 0.05, max: 0.15 }, variations: 5 },
        { id: 'bamboo-creak', type: 'random', probability: 0.1, volume: { min: 0.03, max: 0.08 } },
        { id: 'koi-splash', type: 'random', probability: 0.05, volume: { min: 0.1, max: 0.2 } },
        { id: 'temple-bell', type: 'random', probability: 0.02, volume: { min: 0.1, max: 0.15 } }
      ],
      environmentalLayers: [
        { id: 'cicadas', type: 'continuous', volume: { min: 0.05, max: 0.1 } }, // Summer/evening
        { id: 'rain-drops', type: 'continuous', volume: { min: 0.1, max: 0.3 } } // Rainy weather
      ]
    },
    
    'urban-flow': {
      id: 'urban-flow',
      name: 'Urban Flow',
      description: 'City life with dynamic traffic and activity',
      baseLayers: [
        { id: 'city-hum', type: 'continuous', volume: { min: 0.1, max: 0.15 } },
        { id: 'distant-traffic', type: 'continuous', volume: { min: 0.08, max: 0.12 } }
      ],
      randomLayers: [
        { id: 'car-pass', type: 'random', probability: 0.4, volume: { min: 0.1, max: 0.25 }, variations: 4 },
        { id: 'footsteps', type: 'random', probability: 0.2, volume: { min: 0.05, max: 0.1 }, variations: 3 },
        { id: 'door-close', type: 'random', probability: 0.1, volume: { min: 0.1, max: 0.15 } },
        { id: 'siren-distant', type: 'random', probability: 0.03, volume: { min: 0.05, max: 0.1 } },
        { id: 'conversation-murmur', type: 'random', probability: 0.15, volume: { min: 0.03, max: 0.08 } },
        { id: 'bicycle-bell', type: 'random', probability: 0.08, volume: { min: 0.1, max: 0.15 } }
      ],
      environmentalLayers: [
        { id: 'rush-hour-intensity', type: 'continuous', volume: { min: 0.1, max: 0.2 } }, // Time based
        { id: 'rain-on-pavement', type: 'continuous', volume: { min: 0.15, max: 0.25 } } // Weather based
      ]
    },
    
    'forest-depths': {
      id: 'forest-depths',
      name: 'Forest Depths',
      description: 'Deep forest with wildlife and natural sounds',
      baseLayers: [
        { id: 'forest-ambience', type: 'continuous', volume: { min: 0.1, max: 0.15 } },
        { id: 'leaves-rustle', type: 'continuous', volume: { min: 0.05, max: 0.1 } }
      ],
      randomLayers: [
        { id: 'bird-song', type: 'random', probability: 0.4, volume: { min: 0.1, max: 0.2 }, variations: 8 },
        { id: 'woodpecker', type: 'random', probability: 0.1, volume: { min: 0.15, max: 0.2 } },
        { id: 'branch-crack', type: 'random', probability: 0.08, volume: { min: 0.1, max: 0.2 } },
        { id: 'owl-hoot', type: 'random', probability: 0.05, volume: { min: 0.15, max: 0.25 } },
        { id: 'squirrel-chatter', type: 'random', probability: 0.12, volume: { min: 0.05, max: 0.1 } },
        { id: 'deer-movement', type: 'random', probability: 0.03, volume: { min: 0.08, max: 0.15 } }
      ],
      environmentalLayers: [
        { id: 'morning-chorus', type: 'continuous', volume: { min: 0.2, max: 0.3 } }, // Dawn
        { id: 'cricket-symphony', type: 'continuous', volume: { min: 0.1, max: 0.2 } }, // Night
        { id: 'rain-canopy', type: 'continuous', volume: { min: 0.2, max: 0.35 } } // Rain
      ]
    },
    
    'ocean-meditation': {
      id: 'ocean-meditation',
      name: 'Ocean Meditation',
      description: 'Rhythmic waves with coastal atmosphere',
      baseLayers: [
        { id: 'wave-rhythm', type: 'continuous', volume: { min: 0.2, max: 0.3 } },
        { id: 'distant-waves', type: 'continuous', volume: { min: 0.1, max: 0.15 } }
      ],
      randomLayers: [
        { id: 'seagull-call', type: 'random', probability: 0.2, volume: { min: 0.1, max: 0.2 }, variations: 4 },
        { id: 'wave-crash', type: 'random', probability: 0.15, volume: { min: 0.2, max: 0.35 } },
        { id: 'pebble-wash', type: 'random', probability: 0.3, volume: { min: 0.05, max: 0.1 } },
        { id: 'wind-gust', type: 'random', probability: 0.1, volume: { min: 0.1, max: 0.2 } },
        { id: 'boat-creak', type: 'random', probability: 0.05, volume: { min: 0.05, max: 0.1 } }
      ],
      environmentalLayers: [
        { id: 'storm-approaching', type: 'continuous', volume: { min: 0.15, max: 0.3 } }, // Weather
        { id: 'night-ocean', type: 'continuous', volume: { min: 0.1, max: 0.2 } } // Night time
      ]
    },
    
    'cosmic-journey': {
      id: 'cosmic-journey',
      name: 'Cosmic Journey',
      description: 'Ethereal space ambience with mysterious signals',
      baseLayers: [
        { id: 'cosmic-drone', type: 'continuous', volume: { min: 0.1, max: 0.15 } },
        { id: 'stellar-wind', type: 'continuous', volume: { min: 0.08, max: 0.12 } }
      ],
      randomLayers: [
        { id: 'pulsar-ping', type: 'random', probability: 0.15, volume: { min: 0.1, max: 0.2 } },
        { id: 'radio-burst', type: 'random', probability: 0.1, volume: { min: 0.05, max: 0.15 } },
        { id: 'asteroid-pass', type: 'random', probability: 0.08, volume: { min: 0.1, max: 0.25 } },
        { id: 'alien-signal', type: 'random', probability: 0.03, volume: { min: 0.15, max: 0.25 } },
        { id: 'nebula-whisper', type: 'random', probability: 0.2, volume: { min: 0.05, max: 0.1 } }
      ],
      environmentalLayers: [
        { id: 'solar-storm', type: 'intermittent', interval: { min: 30000, max: 60000 }, volume: { min: 0.2, max: 0.3 } }
      ]
    }
  };
  
  static startSoundscape(soundscapeId: string, baseVolume: number = 0.1) {
    this.stopSoundscape();
    
    const soundscape = this.soundscapes[soundscapeId];
    if (!soundscape) return;
    
    this.currentSoundscape = soundscape;
    this.initAudioContext();
    
    // Start base layers
    soundscape.baseLayers.forEach(layer => {
      this.startLayer(layer, baseVolume);
    });
    
    // Start composition engine for random layers
    this.compositionInterval = setInterval(() => {
      this.updateComposition(baseVolume);
    }, 5000); // Update every 5 seconds
    
    // Initial composition
    this.updateComposition(baseVolume);
  }
  
  static stopSoundscape() {
    if (this.compositionInterval) {
      clearInterval(this.compositionInterval);
      this.compositionInterval = null;
    }
    
    // Fade out all active layers
    this.activeLayers.forEach(({ nodes }) => {
      nodes.forEach(node => {
        if (node.gain) {
          node.gain.gain.exponentialRampToValueAtTime(0.001, this.audioContext!.currentTime + 2);
        }
      });
    });
    
    // Clean up after fade
    setTimeout(() => {
      this.activeLayers.forEach(({ nodes }) => {
        nodes.forEach(node => {
          try {
            if (node.stop) node.stop();
            if (node.disconnect) node.disconnect();
          } catch (e) {}
        });
      });
      this.activeLayers.clear();
    }, 2000);
    
    this.currentSoundscape = null;
  }
  
  private static updateComposition(baseVolume: number) {
    if (!this.currentSoundscape || !this.audioContext) return;
    
    const now = Date.now();
    const hour = new Date().getHours();
    
    // Process random layers
    this.currentSoundscape.randomLayers.forEach(layer => {
      const isActive = this.activeLayers.has(layer.id);
      const shouldPlay = Math.random() < (layer.probability || 0.1);
      
      if (!isActive && shouldPlay) {
        // Start new random layer
        this.startLayer(layer, baseVolume);
      } else if (isActive && !shouldPlay && Math.random() < 0.3) {
        // Sometimes stop active random layers
        this.stopLayer(layer.id);
      }
    });
    
    // Process environmental layers based on time/conditions
    this.currentSoundscape.environmentalLayers.forEach(layer => {
      const isActive = this.activeLayers.has(layer.id);
      let shouldPlay = false;
      
      // Time-based activation
      if (layer.id.includes('morning') && hour >= 5 && hour <= 9) shouldPlay = true;
      if (layer.id.includes('night') && (hour >= 20 || hour <= 5)) shouldPlay = true;
      if (layer.id.includes('evening') && hour >= 17 && hour <= 20) shouldPlay = true;
      if (layer.id.includes('rush-hour') && ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19))) shouldPlay = true;
      
      // Random weather (simulate)
      if (layer.id.includes('rain') && Math.random() < 0.2) shouldPlay = true;
      if (layer.id.includes('storm') && Math.random() < 0.1) shouldPlay = true;
      
      if (shouldPlay && !isActive) {
        this.startLayer(layer, baseVolume);
      } else if (!shouldPlay && isActive) {
        this.stopLayer(layer.id);
      }
    });
    
    // Clean up layers that have been playing too long
    this.activeLayers.forEach((data, id) => {
      if (data.layer.type === 'random' && now - data.startTime > 30000) {
        if (Math.random() < 0.3) this.stopLayer(id);
      }
    });
  }
  
  private static startLayer(layer: SoundLayer, baseVolume: number) {
    if (!this.audioContext) return;
    
    const volume = baseVolume * (layer.volume.min + Math.random() * (layer.volume.max - layer.volume.min));
    const variation = layer.variations ? Math.floor(Math.random() * layer.variations) : 0;
    
    // Create appropriate sound based on layer ID
    const nodes = this.createSound(layer.id, variation, volume);
    
    if (nodes.length > 0) {
      this.activeLayers.set(layer.id, {
        nodes,
        layer,
        startTime: Date.now()
      });
      
      // Schedule intermittent sounds
      if (layer.type === 'intermittent' && layer.interval) {
        const scheduleNext = () => {
          const delay = layer.interval!.min + Math.random() * (layer.interval!.max - layer.interval!.min);
          setTimeout(() => {
            if (this.activeLayers.has(layer.id)) {
              this.triggerIntermittentSound(layer.id, volume);
              scheduleNext();
            }
          }, delay);
        };
        scheduleNext();
      }
    }
  }
  
  private static stopLayer(layerId: string) {
    const layer = this.activeLayers.get(layerId);
    if (!layer) return;
    
    layer.nodes.forEach(node => {
      if (node.gain) {
        node.gain.gain.exponentialRampToValueAtTime(0.001, this.audioContext!.currentTime + 1);
        setTimeout(() => {
          try {
            if (node.stop) node.stop();
            if (node.disconnect) node.disconnect();
          } catch (e) {}
        }, 1000);
      }
    });
    
    this.activeLayers.delete(layerId);
  }
  
  private static createSound(soundId: string, variation: number, volume: number): any[] {
    // This is a simplified version - in reality, each sound would be uniquely crafted
    switch (soundId) {
      case 'water-stream':
        return this.createWaterStream(volume);
      
      case 'bird-chirp':
        return this.createBirdChirp(variation, volume);
      
      case 'car-pass':
        return this.createCarPass(variation, volume);
      
      case 'wave-rhythm':
        return this.createWaveRhythm(volume);
      
      case 'cosmic-drone':
        return this.createCosmicDrone(volume);
      
      // Add more sound creators...
      
      default:
        return this.createGenericAmbience(volume);
    }
  }
  
  private static createWaterStream(volume: number): any[] {
    const ctx = this.audioContext!;
    const noise = this.createBrownNoise(ctx);
    const filter1 = ctx.createBiquadFilter();
    const filter2 = ctx.createBiquadFilter();
    const gain = ctx.createGain();
    
    filter1.type = 'bandpass';
    filter1.frequency.value = 400;
    filter1.Q.value = 0.5;
    
    filter2.type = 'highshelf';
    filter2.frequency.value = 2000;
    filter2.gain.value = -10;
    
    // Gentle modulation
    const lfo = ctx.createOscillator();
    const lfoGain = ctx.createGain();
    lfo.frequency.value = 0.1;
    lfoGain.gain.value = 50;
    
    lfo.connect(lfoGain);
    lfoGain.connect(filter1.frequency);
    
    noise.connect(filter1);
    filter1.connect(filter2);
    filter2.connect(gain);
    gain.connect(ctx.destination);
    
    gain.gain.setValueAtTime(0, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(volume, ctx.currentTime + 2);
    
    noise.start();
    lfo.start();
    
    return [{ ...noise, gain }, lfo];
  }
  
  private static createBirdChirp(variation: number, volume: number): any[] {
    const ctx = this.audioContext!;
    const duration = 0.1 + Math.random() * 0.3;
    
    // Different bird types
    const birdTypes = [
      { baseFreq: 2000, freqRange: 1000, pattern: [1, 1.2, 0.9, 1.3] },
      { baseFreq: 3000, freqRange: 500, pattern: [1, 0.9, 1.1] },
      { baseFreq: 2500, freqRange: 800, pattern: [1, 1.5, 1.2, 1.8, 1] },
      { baseFreq: 4000, freqRange: 200, pattern: [1, 1, 0.95, 1] },
      { baseFreq: 1500, freqRange: 600, pattern: [1, 1.3, 1.1, 1.4, 0.9] }
    ];
    
    const bird = birdTypes[variation % birdTypes.length];
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    const filter = ctx.createBiquadFilter();
    
    osc.type = 'sine';
    filter.type = 'bandpass';
    filter.frequency.value = bird.baseFreq;
    filter.Q.value = 5;
    
    // Create chirp pattern
    const now = ctx.currentTime;
    bird.pattern.forEach((note, i) => {
      const time = now + (i * duration / bird.pattern.length);
      osc.frequency.setValueAtTime(bird.baseFreq + Math.random() * bird.freqRange * note, time);
    });
    
    osc.connect(filter);
    filter.connect(gain);
    gain.connect(ctx.destination);
    
    gain.gain.setValueAtTime(0, now);
    gain.gain.linearRampToValueAtTime(volume, now + 0.01);
    gain.gain.setValueAtTime(volume, now + duration - 0.02);
    gain.gain.linearRampToValueAtTime(0, now + duration);
    
    osc.start(now);
    osc.stop(now + duration);
    
    return [{ ...osc, gain }];
  }
  
  private static createCarPass(variation: number, volume: number): any[] {
    const ctx = this.audioContext!;
    const duration = 3 + Math.random() * 2;
    
    // Engine sound
    const engine = ctx.createOscillator();
    const engineGain = ctx.createGain();
    const engineFilter = ctx.createBiquadFilter();
    
    engine.type = 'sawtooth';
    engine.frequency.value = 80 + variation * 20;
    
    engineFilter.type = 'lowpass';
    engineFilter.frequency.value = 200;
    engineFilter.Q.value = 2;
    
    // Tire noise
    const noise = this.createWhiteNoise(ctx);
    const noiseGain = ctx.createGain();
    const noiseFilter = ctx.createBiquadFilter();
    
    noiseFilter.type = 'bandpass';
    noiseFilter.frequency.value = 1000;
    noiseFilter.Q.value = 0.5;
    
    // Doppler effect
    const now = ctx.currentTime;
    const panner = ctx.createStereoPanner();
    
    // Pan from left to right
    panner.pan.setValueAtTime(-1, now);
    panner.pan.linearRampToValueAtTime(1, now + duration);
    
    // Frequency shift for doppler
    engine.frequency.setValueAtTime(100, now);
    engine.frequency.linearRampToValueAtTime(120, now + duration/2);
    engine.frequency.linearRampToValueAtTime(80, now + duration);
    
    // Volume envelope
    engineGain.gain.setValueAtTime(0, now);
    engineGain.gain.linearRampToValueAtTime(volume * 0.7, now + duration * 0.3);
    engineGain.gain.linearRampToValueAtTime(volume, now + duration * 0.5);
    engineGain.gain.linearRampToValueAtTime(0, now + duration);
    
    noiseGain.gain.setValueAtTime(0, now);
    noiseGain.gain.linearRampToValueAtTime(volume * 0.3, now + duration * 0.4);
    noiseGain.gain.linearRampToValueAtTime(0, now + duration);
    
    engine.connect(engineFilter);
    engineFilter.connect(engineGain);
    engineGain.connect(panner);
    
    noise.connect(noiseFilter);
    noiseFilter.connect(noiseGain);
    noiseGain.connect(panner);
    
    panner.connect(ctx.destination);
    
    engine.start(now);
    engine.stop(now + duration);
    noise.start(now);
    noise.stop(now + duration);
    
    return [{ ...engine, gain: engineGain }, { ...noise, gain: noiseGain }];
  }
  
  private static createWaveRhythm(volume: number): any[] {
    const ctx = this.audioContext!;
    const nodes: any[] = [];
    
    // Create multiple layers of waves
    for (let i = 0; i < 3; i++) {
      const noise = this.createWhiteNoise(ctx);
      const filter = ctx.createBiquadFilter();
      const gain = ctx.createGain();
      const lfo = ctx.createOscillator();
      const lfoGain = ctx.createGain();
      
      filter.type = 'lowpass';
      filter.frequency.value = 200 + i * 100;
      filter.Q.value = 1;
      
      // Wave rhythm modulation
      lfo.type = 'sine';
      lfo.frequency.value = 0.1 + i * 0.05; // Different speeds for each layer
      lfoGain.gain.value = volume * (0.3 - i * 0.1);
      
      lfo.connect(lfoGain);
      lfoGain.connect(gain.gain);
      
      noise.connect(filter);
      filter.connect(gain);
      gain.connect(ctx.destination);
      
      gain.gain.value = volume * 0.3;
      
      noise.start();
      lfo.start();
      
      nodes.push({ ...noise, gain }, lfo);
    }
    
    return nodes;
  }
  
  private static createCosmicDrone(volume: number): any[] {
    const ctx = this.audioContext!;
    const fundamental = 55; // Low A
    const nodes: any[] = [];
    
    // Create harmonically rich drone
    [1, 1.5, 2, 3, 4].forEach((harmonic, i) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      const filter = ctx.createBiquadFilter();
      
      osc.frequency.value = fundamental * harmonic;
      osc.type = i === 0 ? 'sine' : 'triangle';
      
      filter.type = 'lowpass';
      filter.frequency.value = 400 / (i + 1);
      filter.Q.value = 5;
      
      // Slow modulation
      const lfo = ctx.createOscillator();
      const lfoGain = ctx.createGain();
      lfo.frequency.value = 0.05 * (i + 1);
      lfoGain.gain.value = 0.5;
      
      lfo.connect(lfoGain);
      lfoGain.connect(osc.frequency);
      
      osc.connect(filter);
      filter.connect(gain);
      gain.connect(ctx.destination);
      
      gain.gain.value = volume / (i + 2);
      
      osc.start();
      lfo.start();
      
      nodes.push({ ...osc, gain }, lfo);
    });
    
    return nodes;
  }
  
  private static createGenericAmbience(volume: number): any[] {
    const ctx = this.audioContext!;
    const noise = this.createPinkNoise(ctx);
    const gain = ctx.createGain();
    
    noise.connect(gain);
    gain.connect(ctx.destination);
    
    gain.gain.value = volume * 0.5;
    
    noise.start();
    
    return [{ ...noise, gain }];
  }
  
  private static triggerIntermittentSound(soundId: string, volume: number) {
    // Trigger one-shot sounds for intermittent layers
    const tempNodes = this.createSound(soundId, 0, volume);
    
    // Auto-cleanup after sound completes
    setTimeout(() => {
      tempNodes.forEach(node => {
        try {
          if (node.stop) node.stop();
          if (node.disconnect) node.disconnect();
        } catch (e) {}
      });
    }, 5000);
  }
  
  private static initAudioContext() {
    if (!this.audioContext) {
      this.audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
    }
  }
  
  // Noise generators
  private static createWhiteNoise(ctx: AudioContext): AudioBufferSourceNode {
    const bufferSize = ctx.sampleRate * 2;
    const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
    const output = buffer.getChannelData(0);
    
    for (let i = 0; i < bufferSize; i++) {
      output[i] = Math.random() * 2 - 1;
    }
    
    const noise = ctx.createBufferSource();
    noise.buffer = buffer;
    noise.loop = true;
    
    return noise;
  }
  
  private static createPinkNoise(ctx: AudioContext): AudioBufferSourceNode {
    const bufferSize = ctx.sampleRate * 2;
    const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
    const output = buffer.getChannelData(0);
    
    let b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0;
    for (let i = 0; i < bufferSize; i++) {
      const white = Math.random() * 2 - 1;
      b0 = 0.99886 * b0 + white * 0.0555179;
      b1 = 0.99332 * b1 + white * 0.0750759;
      b2 = 0.96900 * b2 + white * 0.1538520;
      b3 = 0.86650 * b3 + white * 0.3104856;
      b4 = 0.55000 * b4 + white * 0.5329522;
      b5 = -0.7616 * b5 - white * 0.0168980;
      output[i] = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362;
      output[i] *= 0.11;
      b6 = white * 0.115926;
    }
    
    const noise = ctx.createBufferSource();
    noise.buffer = buffer;
    noise.loop = true;
    
    return noise;
  }
  
  private static createBrownNoise(ctx: AudioContext): AudioBufferSourceNode {
    const bufferSize = ctx.sampleRate * 2;
    const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
    const output = buffer.getChannelData(0);
    
    let lastOut = 0;
    for (let i = 0; i < bufferSize; i++) {
      const white = Math.random() * 2 - 1;
      output[i] = (lastOut + (0.02 * white)) / 1.02;
      lastOut = output[i];
      output[i] *= 3.5; // (roughly) compensate for gain
    }
    
    const noise = ctx.createBufferSource();
    noise.buffer = buffer;
    noise.loop = true;
    
    return noise;
  }
}