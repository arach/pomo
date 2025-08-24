"use client";

import React, { useState, useEffect } from "react";
import { Download, Clock, Zap, Palette, Moon, Command, RotateCcw, Github } from "lucide-react";
import { useSearchParams, useRouter, usePathname } from "next/navigation";
import { FocusCardsDemo } from "../components/focus-cards";

export default function HomeContent() {
  const [currentIndex, setCurrentIndex] = useState(0);
  const searchParams = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();
  
  // Get style from URL params, with fallback to 'original'
  const styleParam = searchParams.get('style') as 'original' | 'tag' | 'underline' | 'glossy' | null;
  const validStyles = ['original', 'tag', 'underline', 'glossy'];
  const initialStyle = styleParam && validStyles.includes(styleParam) ? styleParam : 'original';
  const [professionStyle, setProfessionStyle] = useState<'original' | 'tag' | 'underline' | 'glossy'>(initialStyle);
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

  // Update style when URL params change
  useEffect(() => {
    const style = searchParams.get('style') as 'original' | 'tag' | 'underline' | 'glossy' | null;
    if (style && validStyles.includes(style)) {
      setProfessionStyle(style);
    } else {
      setProfessionStyle('original');
    }
  }, [searchParams]);

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
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center gap-2">
              <div className="w-10 h-10 rounded-xl bg-gray-900 flex items-center justify-center">
                <span className="text-xl font-bold text-white font-pixelify-sans">P</span>
              </div>
              <span className="text-xl font-bold text-red-500 font-pixelify-sans">Pomo</span>
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
      <section className="relative pt-36 pb-24 overflow-hidden bg-white">
        <div className="relative max-w-7xl mx-auto px-8">
          <div className="text-center max-w-5xl mx-auto">
            <h1 className="text-3xl sm:text-4xl md:text-5xl font-inter font-bold tracking-tight mb-4 leading-[1.1] animate-slide-up">
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

            <p className="text-sm md:text-base text-gray-600 mb-10 leading-relaxed max-w-3xl mx-auto font-mono animate-slide-up" style={{ animationDelay: '0.2s' }}>
              a beautifully minimal Pomodoro timer.
              <span className="text-gray-900 font-medium"> No distractions, just focus.</span>
            </p>

            <div className="flex flex-col sm:flex-row gap-4 justify-center mb-16 animate-slide-up" style={{ animationDelay: '0.3s' }}>
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
            <div className="relative animate-fade-in mt-4" style={{ animationDelay: '0.5s' }}>
              <FocusCardsDemo />
            </div>
          </div>
        </div>
      </section>


      {/* Features Grid */}
      <section id="features" className="py-20 relative overflow-hidden bg-white">
        <div className="max-w-7xl mx-auto px-8 relative">
          <div className="text-center mb-12">
            <h2 className="text-3xl md:text-4xl font-inter font-bold mb-4 text-gray-900">
              everything you need to <span className="text-red-500">focus</span>
            </h2>
            <p className="text-base text-gray-600 max-w-3xl mx-auto font-mono leading-relaxed">
              thoughtfully designed features that help you work better, not harder.
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
                <h3 className="text-sm font-mono font-normal uppercase tracking-wide mb-3 text-gray-900">{feature.title}</h3>
                <p className="text-gray-600 leading-relaxed font-mono text-sm">{feature.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* How It Works Section */}
      <section className="py-20 relative overflow-hidden bg-gray-50">
        <div className="max-w-6xl mx-auto px-8 relative">
          <h2 className="text-3xl font-inter font-bold mb-16 text-center text-gray-900">
            How the <span className="text-red-500">Pomodoro</span> works
          </h2>
          
          {/* Single Pomodoro */}
          <div className="mb-20">
            <h3 className="text-xl text-gray-700 mb-8 text-center font-mono">
              One pomodoro: 25 minutes + 5 minutes break
            </h3>
            <div className="flex items-center justify-center gap-4 mb-6">
              <div className="flex items-center gap-2 flex-1 max-w-md">
                <div className="group relative flex-1">
                  <div className="h-3 bg-gray-800 rounded-full relative transition-all duration-300 hover:h-4 hover:shadow-lg cursor-pointer">
                    <div className="absolute -right-1 top-1/2 -translate-y-1/2 w-5 h-5 bg-gray-800 rounded-full border-2 border-white shadow-sm transition-all duration-300 group-hover:scale-110"></div>
                  </div>
                  <div className="absolute -top-8 left-1/2 -translate-x-1/2 opacity-0 group-hover:opacity-100 transition-opacity duration-300 bg-gray-900 text-white px-2 py-1 rounded text-xs whitespace-nowrap font-mono">
                    Deep focus time
                  </div>
                </div>
                <div className="group relative w-20">
                  <div className="h-3 bg-gray-400 rounded-full relative transition-all duration-300 hover:h-4 hover:shadow-lg cursor-pointer">
                    <div className="absolute -right-1 top-1/2 -translate-y-1/2 w-5 h-5 bg-gray-400 rounded-full border-2 border-white shadow-sm transition-all duration-300 group-hover:scale-110"></div>
                  </div>
                  <div className="absolute -top-8 left-1/2 -translate-x-1/2 opacity-0 group-hover:opacity-100 transition-opacity duration-300 bg-gray-600 text-white px-2 py-1 rounded text-xs whitespace-nowrap font-mono">
                    Quick stretch
                  </div>
                </div>
              </div>
            </div>
            <div className="flex items-center justify-center gap-2">
              <div className="flex items-center gap-2 flex-1 max-w-md">
                <div className="flex-1 text-center">
                  <div className="text-gray-900 font-bold text-base font-mono">25 min</div>
                  <div className="text-xs text-gray-600 font-mono">Focused work</div>
                </div>
                <div className="w-20 text-center">
                  <div className="text-gray-900 font-bold text-base font-mono">5 min</div>
                  <div className="text-xs text-gray-600 font-mono">Break</div>
                </div>
              </div>
            </div>
          </div>

          {/* Four Pomodoros Cycle */}
          <div>
            <h3 className="text-xl text-gray-700 mb-8 text-center font-mono">
              Complete 4 Pomodoros then take a longer break
            </h3>
            <div className="flex items-center justify-center gap-2 mb-10">
              <div className="flex items-center gap-2 flex-1 max-w-4xl">
                {[1, 2, 3, 4].map((i) => (
                  <React.Fragment key={i}>
                    <div className="group relative flex-1">
                      <div className="h-3 bg-gray-800 rounded-full relative transition-all duration-300 hover:h-4 hover:shadow-lg cursor-pointer">
                        <div className="absolute -right-1 top-1/2 -translate-y-1/2 w-5 h-5 bg-gray-800 rounded-full border-2 border-white shadow-sm transition-all duration-300 group-hover:scale-110"></div>
                      </div>
                      <div className="absolute -top-8 left-1/2 -translate-x-1/2 opacity-0 group-hover:opacity-100 transition-opacity duration-300 bg-gray-900 text-white px-2 py-1 rounded text-xs whitespace-nowrap font-mono z-10">
                        Pomodoro #{i}
                      </div>
                    </div>
                    {i < 4 && (
                      <div className="group relative w-12">
                        <div className="h-3 bg-gray-400 rounded-full relative transition-all duration-300 hover:h-4 hover:shadow-lg cursor-pointer">
                          <div className="absolute -right-1 top-1/2 -translate-y-1/2 w-5 h-5 bg-gray-400 rounded-full border-2 border-white shadow-sm transition-all duration-300 group-hover:scale-110"></div>
                        </div>
                        <div className="absolute -bottom-8 left-1/2 -translate-x-1/2 opacity-0 group-hover:opacity-100 transition-opacity duration-300 bg-gray-600 text-white px-2 py-1 rounded text-xs whitespace-nowrap font-mono z-10">
                          5 min
                        </div>
                      </div>
                    )}
                  </React.Fragment>
                ))}
                {/* Long Break - Made more prominent */}
                <div className="group relative w-40">
                  <div className="h-5 bg-gradient-to-r from-green-500 to-green-600 rounded-full relative transition-all duration-300 hover:h-6 hover:shadow-xl cursor-pointer animate-pulse">
                    <div className="absolute -right-1 top-1/2 -translate-y-1/2 w-7 h-7 bg-gradient-to-r from-green-500 to-green-600 rounded-full border-3 border-white shadow-lg transition-all duration-300 group-hover:scale-110"></div>
                  </div>
                  <div className="absolute -top-10 right-0 opacity-0 group-hover:opacity-100 transition-opacity duration-300 bg-green-600 text-white px-3 py-2 rounded text-xs whitespace-nowrap font-mono z-10">
                    Recharge completely! ✨
                  </div>
                </div>
              </div>
            </div>
            <div className="flex items-center justify-center gap-2">
              <div className="flex items-center gap-2 flex-1 max-w-4xl">
                <div className="flex-1 text-center">
                  <div className="text-xs font-mono text-gray-600 mb-1">4 × 25 min</div>
                  <div className="text-xs font-mono text-gray-500">Focus sessions</div>
                </div>
                <div className="w-12 text-center" style={{visibility: 'hidden'}}>
                  <div className="text-xs font-mono text-gray-600">5m</div>
                </div>
                <div className="w-12 text-center" style={{visibility: 'hidden'}}>
                  <div className="text-xs font-mono text-gray-600">5m</div>
                </div>
                <div className="w-12 text-center" style={{visibility: 'hidden'}}>
                  <div className="text-xs font-mono text-gray-600">5m</div>
                </div>
                <div className="w-40 text-center">
                  <div className="text-green-600 font-bold text-lg font-mono mb-1">15 - 30 min</div>
                  <div className="text-xs font-mono text-gray-600">Long Break</div>
                  <div className="text-xs font-mono text-gray-500 mt-1">Walk, snack, or rest</div>
                </div>
              </div>
            </div>
          </div>

          {/* Additional Tips */}
          <div className="mt-16 p-6 bg-white rounded-xl border border-gray-200">
            <h4 className="text-sm font-mono font-bold uppercase text-gray-700 mb-3">Pro Tips</h4>
            <ul className="space-y-2 text-xs font-mono text-gray-600">
              <li className="flex items-start gap-2">
                <span className="text-red-500">→</span>
                <span>During breaks, step away from your screen completely</span>
              </li>
              <li className="flex items-start gap-2">
                <span className="text-red-500">→</span>
                <span>Use the long break for physical movement or a healthy snack</span>
              </li>
              <li className="flex items-start gap-2">
                <span className="text-red-500">→</span>
                <span>If you finish a task mid-pomodoro, review your work for the remaining time</span>
              </li>
            </ul>
          </div>
        </div>
      </section>

      {/* About Section */}
      <section id="about" className="py-20 relative bg-white">
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
            
            <blockquote className="text-base text-gray-700 mb-6 leading-relaxed font-mono italic text-center">
              "The Pomodoro Technique is a time management method that can be used for any task. The aim is to use time
              as a valuable ally to accomplish what we want to do the way we want to do it."
            </blockquote>
            <div className="flex items-center justify-center gap-4">
              <div className="w-12 h-12 rounded-full bg-red-100 border border-red-200 flex items-center justify-center">
                <span className="font-bold text-red-600 font-inter">FC</span>
              </div>
              <div className="text-left">
                <div className="font-bold text-gray-900 text-sm font-inter">Francesco Cirillo</div>
                <div className="text-gray-500 font-mono text-xs">Creator of the Pomodoro Technique</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-20 relative overflow-hidden bg-black">
        <div className="max-w-5xl mx-auto px-8 text-center relative">
          <h2 className="text-3xl md:text-4xl font-inter font-bold mb-6 text-white">
            Start focusing today
          </h2>
          <p className="text-base text-gray-400 mb-10 max-w-2xl mx-auto font-mono leading-relaxed">
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
              <div className="w-10 h-10 rounded-xl bg-gray-900 flex items-center justify-center">
                <span className="text-xl font-bold text-white font-pixelify-sans">P</span>
              </div>
              <span className="text-xl font-bold text-red-500 font-pixelify-sans">Pomo</span>
            </div>
            <div className="flex gap-6">
              <a href="https://github.com/arach/pomo" className="text-gray-600 hover:text-gray-900 transition-colors">
                <Github className="w-6 h-6" />
              </a>
            </div>
          </div>
          <div className="text-center mt-8 text-gray-500 font-mono text-xs">
            © 2024 <span className="text-red-500 font-pixelify-sans">Pomo</span>. Open source under MIT License.
          </div>
        </div>
      </footer>
    </div>
  );
}