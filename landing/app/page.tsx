"use client";

import React, { useState, useEffect } from "react";
import { Download, Clock, Zap, Palette, Moon, Command, RotateCcw, Github, X } from "lucide-react";

export default function Home() {
  const [showModal, setShowModal] = useState(false);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [professionStyle, setProfessionStyle] = useState<'original' | 'tag' | 'underline' | 'glossy'>('original');
  const [wavyPath, setWavyPath] = useState("");
  
  const professions = [
    "developers",
    "designers",
    "writers",
    "students",
    "creators",
    "founders",
    "engineers",
    "researchers",
    "artists",
    "makers"
  ];
  
  // Generate a slightly random wavy path based on hour
  const generateWavyPath = () => {
    const time = new Date();
    // Use hour as primary seed, changes every hour
    const hourSeed = time.getHours();
    // Add day of month for more variation across days
    const daySeed = time.getDate();
    const seed = hourSeed + daySeed * 0.1;
    
    // Generate control points with slight variations
    const y1 = 6.5 + Math.sin(seed * 0.8) * 0.3;
    const y2 = 5.5 + Math.cos(seed * 1.3) * 0.4;
    const y3 = 6 + Math.sin(seed * 0.7) * 0.3;
    const y4 = 6.5 + Math.cos(seed * 0.9) * 0.35;
    const y5 = 6 + Math.sin(seed * 1.1) * 0.3;
    
    return `M2,${y1} Q30,${y2} 60,${y3} T120,${y4} Q150,${y2} 180,${y1} T198,${y5}`;
  };

  useEffect(() => {
    const interval = setInterval(() => {
      setCurrentIndex((prevIndex) => (prevIndex + 1) % professions.length);
    }, 2500);
    
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    // Generate path once on mount
    setWavyPath(generateWavyPath());
  }, []);

  const features = [
    {
      icon: <Clock className="w-6 h-6" />,
      title: "Floating Timer",
      description: "Always-on-top window that stays out of your way while keeping you focused.",
    },
    {
      icon: <Zap className="w-6 h-6" />,
      title: "Menu Bar Integration",
      description: "Live timer updates in your menu bar with intelligent progress tracking.",
    },
    {
      icon: <Palette className="w-6 h-6" />,
      title: "Custom Themes",
      description: "Multiple beautiful watchfaces from minimal to retro.",
    },
    {
      icon: <Moon className="w-6 h-6" />,
      title: "Focus Modes",
      description: "Deep focus, break time, and planning modes tailored to your workflow.",
    },
    {
      icon: <Command className="w-6 h-6" />,
      title: "Keyboard First",
      description: "Complete keyboard control with fully customizable shortcuts.",
    },
    {
      icon: <RotateCcw className="w-6 h-6" />,
      title: "Session Tracking",
      description: "Comprehensive analytics to track your progress and build habits.",
    },
  ];

  return (
    <div className="min-h-screen bg-gray-50 text-gray-900">
      {/* Navigation */}
      <nav className="fixed top-0 w-full z-50 bg-white/80 backdrop-blur-xl border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-8">
          <div className="flex justify-between items-center h-20">
            <div className="flex items-center gap-2">
              <div className="w-10 h-10 rounded-xl bg-red-500 flex items-center justify-center">
                <span className="text-xl font-bold text-white font-pixelify-sans">P</span>
              </div>
              <span className="text-xl font-bold text-gray-900 font-pixelify-sans">Pomo</span>
            </div>
            <div className="flex items-center gap-12">
              <div className="hidden md:flex items-center gap-12">
                <a href="#features" className="text-gray-600 hover:text-gray-900 transition-colors font-inter text-sm font-medium">
                  Features
                </a>
                <a href="#about" className="text-gray-600 hover:text-gray-900 transition-colors font-inter text-sm font-medium">
                  About
                </a>
              </div>
              <a
                href="https://github.com/arach/pomo/releases/latest"
                className="bg-gray-900 text-white hover:bg-gray-800 rounded-xl transition-all px-6 py-3 text-sm inline-flex items-center gap-2 font-inter font-semibold shadow-sm hover:shadow-md"
              >
                <Download className="w-4 h-4" />
                <span className="hidden sm:inline">Download</span>
              </a>
            </div>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="relative min-h-screen flex items-center justify-center overflow-hidden bg-white">
        <div className="relative max-w-7xl mx-auto px-8 py-20">
          <div className="text-center max-w-5xl mx-auto">
            <h1 className="text-3xl sm:text-4xl md:text-5xl font-inter font-bold tracking-tight mb-6 leading-[1.1] animate-slide-up">
              <span className="text-black">
                <span className="font-light">the</span> <span className="font-black text-red-500">focus timer</span>
                <span className="font-light"> for </span>
                
                {/* Original Style - Gray background tag */}
                {professionStyle === 'original' && (
                  <span className="relative inline-block bg-gray-100 px-4 py-1 rounded-lg border border-gray-200" style={{ minWidth: '200px', verticalAlign: 'baseline' }}>
                    {professions.map((profession, index) => (
                      <span
                        key={profession}
                        className={`absolute inset-0 flex items-center justify-center font-bold text-gray-700 transition-all duration-500 ${
                          index === currentIndex 
                            ? 'opacity-100' 
                            : 'opacity-0'
                        }`}
                      >
                        {profession}
                      </span>
                    ))}
                    <span className="invisible font-bold">researchers</span>
                  </span>
                )}
                
                {/* Tag Style */}
                {professionStyle === 'tag' && (
                  <span className="relative inline-block bg-gray-100 px-4 py-1 rounded-lg border border-gray-200 transition-all duration-300" style={{ minWidth: '200px', verticalAlign: 'baseline' }}>
                    {professions.map((profession, index) => (
                      <span
                        key={profession}
                        className={`absolute inset-0 flex items-center justify-center font-bold text-gray-700 transition-all duration-500 ${
                          index === currentIndex 
                            ? 'opacity-100 translate-y-0' 
                            : index === (currentIndex - 1 + professions.length) % professions.length
                            ? 'opacity-0 -translate-y-2'
                            : 'opacity-0 translate-y-2'
                        }`}
                      >
                        {profession}
                      </span>
                    ))}
                    <span className="invisible font-bold">researchers</span>
                  </span>
                )}
                
                {/* Underline Style */}
                {professionStyle === 'underline' && (
                  <span className="relative inline-block" style={{ minWidth: '200px', verticalAlign: 'baseline' }}>
                    {professions.map((profession, index) => (
                      <span
                        key={profession}
                        className={`absolute inset-0 flex items-center justify-center font-bold text-gray-700 transition-all duration-500 ${
                          index === currentIndex 
                            ? 'opacity-100 scale-100' 
                            : 'opacity-0 scale-95'
                        }`}
                      >
                        {profession}
                      </span>
                    ))}
                    <span className="invisible font-bold">researchers</span>
                    <svg 
                      className="absolute -bottom-0.5 left-0 w-full h-3 overflow-visible"
                      preserveAspectRatio="none"
                      viewBox="0 0 200 10"
                    >
                      <path
                        d={wavyPath}
                        stroke="url(#wavy-gradient)"
                        strokeWidth="1.5"
                        fill="none"
                        strokeLinecap="round"
                        opacity="0.9"
                      />
                      <defs>
                        <linearGradient id="wavy-gradient" x1="0%" y1="0%" x2="100%" y2="0%">
                          <stop offset="0%" stopColor="transparent" />
                          <stop offset="10%" stopColor="#ef4444" />
                          <stop offset="90%" stopColor="#ef4444" />
                          <stop offset="100%" stopColor="transparent" />
                        </linearGradient>
                      </defs>
                    </svg>
                  </span>
                )}
                
                {/* Glossy Style */}
                {professionStyle === 'glossy' && (
                  <span className="relative inline-block bg-gradient-to-r from-gray-100 to-gray-200 px-4 py-1 rounded-lg overflow-hidden border border-gray-300" style={{ minWidth: '200px', verticalAlign: 'text-bottom' }}>
                    <div className="absolute inset-0 bg-gradient-to-t from-transparent via-white/40 to-white/60"></div>
                    {professions.map((profession, index) => (
                      <span
                        key={profession}
                        className={`absolute inset-0 flex items-center justify-center font-bold text-gray-700 z-10 transition-all duration-500 ${
                          index === currentIndex 
                            ? 'opacity-100' 
                            : 'opacity-0'
                        }`}
                      >
                        {profession}
                      </span>
                    ))}
                    <span className="invisible font-bold relative z-10">researchers</span>
                  </span>
                )}
              </span>
            </h1>

            <p className="text-base md:text-lg text-gray-600 mb-8 leading-relaxed max-w-3xl mx-auto font-mono animate-slide-up" style={{ animationDelay: '0.2s' }}>
              A beautifully minimal Pomodoro timer that lives in your menu bar. 
              <span className="text-gray-900 font-medium"> No distractions, just focus.</span>
            </p>

            {/* Style Selector */}
            <div className="flex justify-center gap-2 mb-8 animate-fade-in" style={{ animationDelay: '0.25s' }}>
              <button
                onClick={() => setProfessionStyle('original')}
                className={`px-3 py-1.5 rounded-lg text-xs font-mono transition-all ${
                  professionStyle === 'original' 
                    ? 'bg-gray-900 text-white' 
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                }`}
                aria-label="Original style"
              >
                original
              </button>
              <button
                onClick={() => setProfessionStyle('tag')}
                className={`px-3 py-1.5 rounded-lg text-xs font-mono transition-all ${
                  professionStyle === 'tag' 
                    ? 'bg-gray-900 text-white' 
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                }`}
                aria-label="Tag style"
              >
                tag
              </button>
              <button
                onClick={() => setProfessionStyle('underline')}
                className={`px-3 py-1.5 rounded-lg text-xs font-mono transition-all ${
                  professionStyle === 'underline' 
                    ? 'bg-gray-900 text-white' 
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                }`}
                aria-label="Underline style"
              >
                underline
              </button>
              <button
                onClick={() => setProfessionStyle('glossy')}
                className={`px-3 py-1.5 rounded-lg text-xs font-mono transition-all ${
                  professionStyle === 'glossy' 
                    ? 'bg-gray-900 text-white' 
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                }`}
                aria-label="Glossy style"
              >
                glossy
              </button>
            </div>

            {/* Platform badges */}
            <div className="flex justify-center gap-2 mb-12 animate-fade-in" style={{ animationDelay: '0.3s' }}>
              <span className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-gray-100 border border-gray-200">
                <span className="text-xs font-inter font-medium text-gray-600">macOS</span>
              </span>
              <span className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-gray-100 border border-gray-200">
                <span className="text-xs font-inter font-medium text-gray-600">watchOS</span>
              </span>
              <span className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-gray-100 border border-gray-200">
                <span className="text-xs font-inter font-medium text-gray-600">iOS</span>
              </span>
            </div>

            <div className="flex flex-col sm:flex-row gap-4 justify-center mb-20 animate-slide-up" style={{ animationDelay: '0.4s' }}>
              <a
                href="https://github.com/arach/pomo/releases/latest"
                className="bg-black text-white hover:bg-gray-800 rounded-lg transition-all px-6 py-3 inline-flex items-center justify-center gap-2 font-inter font-medium text-sm"
              >
                <Download className="w-4 h-4" />
                Download for macOS
              </a>
              <a
                href="https://github.com/arach/pomo"
                className="border border-gray-300 text-gray-600 hover:border-gray-400 hover:text-gray-900 rounded-lg transition-all px-6 py-3 inline-flex items-center justify-center gap-2 font-inter font-medium text-sm"
              >
                <Github className="w-4 h-4" />
                View Source
              </a>
            </div>

            {/* Screenshots Section */}
            <div className="relative animate-fade-in" style={{ animationDelay: '0.8s' }}>
              <div className="relative bg-gray-100 rounded-3xl p-8 md:p-12 border border-gray-200">
                <div className="grid lg:grid-cols-2 gap-12 items-start">
                  {/* Terminal Desktop App */}
                  <div className="text-center">
                    <div className="mb-6">
                      <h3 className="text-xl font-inter font-bold mb-2 text-gray-900">
                        Pomo Desktop
                      </h3>
                      <p className="text-gray-600 font-inter text-sm">Floating timer with terminal aesthetics</p>
                    </div>
                    <div className="relative inline-block cursor-pointer group" onClick={(e) => { e.preventDefault(); setShowModal(true); }}>
                      <img
                        src="/pomo-desktop.png"
                        alt="Pomo Desktop App"
                        className="w-full max-w-lg h-auto rounded-2xl shadow-lg group-hover:shadow-xl transition-all duration-300 group-hover:scale-[1.02]"
                      />
                      <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none">
                        <div className="bg-white/95 text-gray-900 px-4 py-2 rounded-xl font-inter text-xs shadow-lg border border-gray-200">
                          Click to enlarge
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Watch Terminal Screenshot */}
                  <div className="text-center">
                    <div className="mb-6">
                      <h3 className="text-xl font-inter font-bold mb-2 text-gray-900">
                        Pomo Watch
                      </h3>
                      <p className="text-gray-600 font-inter text-sm">6 unique themes on your wrist</p>
                    </div>
                    <div className="relative inline-block">
                      <img
                        src="/pomo-watch.png"
                        alt="Pomo Watch App"
                        className="w-32 h-auto rounded-[2rem] shadow-lg mx-auto"
                      />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Modal for enlarged image */}
      {showModal && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-md"
          onClick={(e) => { e.preventDefault(); setShowModal(false); }}
        >
          <div className="relative max-w-6xl max-h-[90vh] p-6">
            <button
              onClick={(e) => { e.preventDefault(); e.stopPropagation(); setShowModal(false); }}
              className="absolute -top-4 -right-4 z-10 bg-white rounded-full p-3 hover:bg-gray-100 transition-all shadow-lg"
            >
              <X className="w-5 h-5 text-gray-700" />
            </button>
            <img
              src="/pomo-desktop.png"
              alt="Pomo Desktop App - Full Size"
              className="w-full h-auto rounded-3xl shadow-2xl"
              onClick={(e) => e.stopPropagation()}
            />
            <div className="text-center mt-6">
              <p className="text-white font-inter text-sm">Clean, focused interface with customizable session lengths</p>
            </div>
          </div>
        </div>
      )}

      {/* Features Grid */}
      <section id="features" className="py-32 relative overflow-hidden bg-white">
        <div className="max-w-7xl mx-auto px-8 relative">
          <div className="text-center mb-20">
            <h2 className="text-3xl md:text-4xl font-inter font-bold mb-6 text-gray-900">
              Everything you need to <span className="text-red-500">focus</span>
            </h2>
            <p className="text-base text-gray-600 max-w-3xl mx-auto font-inter leading-relaxed">
              Thoughtfully designed features that help you work better, not harder.
            </p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
            {features.map((feature, index) => (
              <div
                key={index}
                className="group text-center bg-gray-50 rounded-2xl p-8 border border-gray-200 hover:border-red-300 hover:bg-white transition-all hover:shadow-lg transform hover:-translate-y-1 duration-300"
              >
                <div className="w-14 h-14 rounded-2xl bg-red-50 flex items-center justify-center mb-6 mx-auto border border-red-200 group-hover:bg-red-100 group-hover:border-red-300 transition-all">
                  <div className="text-red-500 group-hover:text-red-600 transition-colors">
                    {feature.icon}
                  </div>
                </div>
                <h3 className="text-lg font-bold mb-3 text-gray-900 font-inter">{feature.title}</h3>
                <p className="text-gray-600 leading-relaxed font-inter text-sm">{feature.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* How It Works Section */}
      <section className="py-32 relative overflow-hidden bg-gray-50">
        <div className="max-w-6xl mx-auto px-8 relative">
          <h2 className="text-3xl font-inter font-bold mb-16 text-center text-gray-900">
            How the <span className="text-red-500">Pomodoro</span> works
          </h2>
          
          {/* Single Pomodoro */}
          <div className="mb-20">
            <h3 className="text-xl text-gray-700 mb-8 text-center font-inter">
              One pomodoro: 25 minutes + 5 minutes break
            </h3>
            <div className="flex items-center justify-center gap-4 mb-4">
              <div className="flex items-center gap-2 flex-1 max-w-md">
                <div className="h-2 bg-gray-800 flex-1 rounded-full relative">
                  <div className="absolute -right-1 top-1/2 -translate-y-1/2 w-4 h-4 bg-gray-800 rounded-full border-2 border-white shadow-sm"></div>
                </div>
                <div className="h-2 bg-gray-400 w-20 rounded-full relative">
                  <div className="absolute -right-1 top-1/2 -translate-y-1/2 w-4 h-4 bg-gray-400 rounded-full border-2 border-white shadow-sm"></div>
                </div>
              </div>
            </div>
            <div className="flex justify-center gap-4 text-sm text-gray-600 font-inter">
              <div className="flex items-center gap-8">
                <div className="text-center">
                  <div className="text-gray-900 font-semibold mb-1">25 min</div>
                  <div>Focused work</div>
                </div>
                <div className="text-center">
                  <div className="text-gray-900 font-semibold mb-1">5 min</div>
                  <div>Break</div>
                </div>
              </div>
            </div>
          </div>

          {/* Four Pomodoros Cycle */}
          <div>
            <h3 className="text-xl text-gray-700 mb-8 text-center font-inter">
              Complete 4 Pomodoros then take a longer break
            </h3>
            <div className="flex items-center justify-center gap-3 mb-8">
              <div className="flex items-center gap-2 flex-1 max-w-3xl">
                {[1, 2, 3, 4].map((i) => (
                  <React.Fragment key={i}>
                    <div className="h-2 bg-gray-800 flex-1 rounded-full relative">
                      <div className="absolute -right-1 top-1/2 -translate-y-1/2 w-4 h-4 bg-gray-800 rounded-full border-2 border-white shadow-sm"></div>
                    </div>
                    {i < 4 && (
                      <div className="h-2 bg-gray-400 w-12 rounded-full relative">
                        <div className="absolute -right-1 top-1/2 -translate-y-1/2 w-4 h-4 bg-gray-400 rounded-full border-2 border-white shadow-sm"></div>
                      </div>
                    )}
                  </React.Fragment>
                ))}
                <div className="h-2 bg-gray-600 w-32 rounded-full relative">
                  <div className="absolute -right-1 top-1/2 -translate-y-1/2 w-4 h-4 bg-gray-600 rounded-full border-2 border-white shadow-sm"></div>
                </div>
              </div>
            </div>
            <div className="text-center text-sm text-gray-600 font-inter">
              <div className="text-gray-900 font-semibold mb-1">15 - 30 min</div>
              <div>Long Break</div>
            </div>
          </div>
        </div>
      </section>

      {/* About Section */}
      <section id="about" className="py-32 relative bg-white">
        <div className="max-w-5xl mx-auto px-8">
          <h2 className="text-2xl font-inter font-bold mb-8 text-center text-gray-900">
            Words from the <span className="text-red-500">creator</span>
          </h2>
          <div className="bg-gray-50 rounded-3xl p-8 border border-gray-200">
            {/* YouTube Video Embed */}
            <div className="aspect-video mb-8 rounded-xl overflow-hidden">
              <iframe
                className="w-full h-full"
                src="https://www.youtube.com/embed/dnt2lTdcn8g"
                title="Francesco Cirillo - Introduction to the Pomodoro Technique"
                frameBorder="0"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                allowFullScreen
              />
            </div>
            
            <blockquote className="text-base text-gray-700 mb-6 leading-relaxed font-inter italic text-center">
              "The Pomodoro Technique is a time management method that can be used for any task. The aim is to use time
              as a valuable ally to accomplish what we want to do the way we want to do it."
            </blockquote>
            <div className="flex items-center justify-center gap-4">
              <div className="w-12 h-12 rounded-full bg-red-100 border border-red-200 flex items-center justify-center">
                <span className="font-bold text-red-600 font-inter">FC</span>
              </div>
              <div className="text-left">
                <div className="font-bold text-gray-900 text-sm font-inter">Francesco Cirillo</div>
                <div className="text-gray-500 font-inter text-xs">Creator of the Pomodoro Technique</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-32 relative overflow-hidden bg-black">
        <div className="max-w-5xl mx-auto px-8 text-center relative">
          <h2 className="text-3xl md:text-4xl font-inter font-bold mb-6 text-white">
            Start focusing today
          </h2>
          <p className="text-base text-gray-400 mb-10 max-w-2xl mx-auto font-inter leading-relaxed">
            Simple focus timer. No tracking, no analytics, no pressure. Just you and your work.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <a
              href="https://github.com/arach/pomo/releases/latest"
              className="bg-white text-black hover:bg-gray-100 rounded-lg transition-all px-6 py-3 inline-flex items-center justify-center gap-2 font-inter font-medium text-sm"
            >
              <Download className="w-4 h-4" />
              Download for macOS
            </a>
            <a
              href="https://github.com/arach/pomo"
              className="border border-gray-600 text-gray-300 hover:border-gray-400 hover:text-white rounded-lg transition-all px-6 py-3 inline-flex items-center justify-center gap-2 font-inter font-medium text-sm"
            >
              <Github className="w-4 h-4" />
              View Source
            </a>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-gray-200 py-16 bg-white">
        <div className="max-w-7xl mx-auto px-8">
          <div className="flex flex-col md:flex-row justify-between items-center gap-6">
            <div className="flex items-center gap-2">
              <div className="w-10 h-10 rounded-xl bg-red-500 flex items-center justify-center">
                <span className="text-xl font-bold text-white font-pixelify-sans">P</span>
              </div>
              <span className="text-xl font-bold text-gray-900 font-pixelify-sans">Pomo</span>
            </div>
            <div className="flex gap-6">
              <a href="https://github.com/arach/pomo" className="text-gray-600 hover:text-gray-900 transition-colors">
                <Github className="w-6 h-6" />
              </a>
            </div>
          </div>
          <div className="text-center mt-8 text-gray-500 font-inter text-xs">
            © 2024 <span className="text-red-500 font-pixelify-sans">Pomo</span>. Open source under MIT License.
          </div>
        </div>
      </footer>
    </div>
  );
}