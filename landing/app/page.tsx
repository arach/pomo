"use client";

import { Download, Clock, Zap, Palette, Moon, Command, ChevronRight, Play, Pause, RotateCcw } from "lucide-react";
import { useState, useEffect } from "react";
import Image from "next/image";

export default function Home() {
  const [timeLeft, setTimeLeft] = useState(25 * 60);
  const [isRunning, setIsRunning] = useState(false);
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    let interval: NodeJS.Timeout;
    if (isRunning && timeLeft > 0) {
      interval = setInterval(() => {
        setTimeLeft((prev) => {
          const newTime = prev - 1;
          setProgress(((25 * 60 - newTime) / (25 * 60)) * 100);
          return newTime;
        });
      }, 1000);
    }
    return () => clearInterval(interval);
  }, [isRunning, timeLeft]);

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, "0")}:${secs.toString().padStart(2, "0")}`;
  };

  const features = [
    {
      icon: <Clock className="w-6 h-6" />,
      title: "Floating Timer",
      description: "Always-on-top window that stays out of your way while keeping you focused.",
    },
    {
      icon: <Zap className="w-6 h-6" />,
      title: "Menu Bar Integration",
      description: "Live timer updates in your menu bar with smart minute-level progress.",
    },
    {
      icon: <Palette className="w-6 h-6" />,
      title: "Custom Themes",
      description: "Multiple watchfaces from minimal to retro. Make it yours.",
    },
    {
      icon: <Moon className="w-6 h-6" />,
      title: "Focus Modes",
      description: "Deep focus, break time, planning, and learning modes.",
    },
    {
      icon: <Command className="w-6 h-6" />,
      title: "Keyboard First",
      description: "Complete keyboard control with customizable shortcuts.",
    },
    {
      icon: <RotateCcw className="w-6 h-6" />,
      title: "Session Tracking",
      description: "Track your progress and build better focus habits.",
    },
  ];

  return (
    <div className="min-h-screen bg-background text-foreground">
      {/* Hero Section */}
      <section className="relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-br from-accent/20 via-transparent to-transparent" />
        <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-24 lg:py-32">
          <div className="grid lg:grid-cols-2 gap-12 items-center">
            <div className="animate-fade-up">
              <h1 className="text-5xl lg:text-7xl font-light tracking-tight mb-6">
                Focus with
                <span className="block font-medium text-accent">Pomo</span>
              </h1>
              <p className="text-xl text-foreground/70 mb-8 leading-relaxed">
                A beautifully minimal Pomodoro timer for macOS. 
                Floating, always accessible, and designed to help you find your flow.
              </p>
              <div className="flex flex-col sm:flex-row gap-4">
                <a
                  href="https://github.com/arach/pomo/releases/latest"
                  className="inline-flex items-center justify-center gap-2 px-6 py-3 bg-accent text-background font-medium rounded-full hover:bg-accent/90 transition-all duration-200 hover:scale-105"
                >
                  <Download className="w-5 h-5" />
                  Download for macOS
                </a>
                <a
                  href="https://github.com/arach/pomo"
                  className="inline-flex items-center justify-center gap-2 px-6 py-3 border border-foreground/20 rounded-full hover:bg-foreground/5 transition-all duration-200"
                >
                  View on GitHub
                  <ChevronRight className="w-4 h-4" />
                </a>
              </div>
            </div>

            {/* Live Demo */}
            <div className="flex justify-center animate-scale-in">
              <div className="relative">
                <div className="absolute inset-0 bg-accent/20 blur-3xl" />
                <div className="relative bg-background/90 backdrop-blur-xl rounded-xl shadow-2xl p-8 border border-foreground/10 w-80">
                  <div className="text-center">
                    <div className="relative w-32 h-32 mx-auto mb-6">
                      <svg className="w-32 h-32 transform -rotate-90">
                        <circle
                          cx="64"
                          cy="64"
                          r="56"
                          fill="none"
                          stroke="rgba(255, 255, 255, 0.08)"
                          strokeWidth="3"
                        />
                        <circle
                          cx="64"
                          cy="64"
                          r="56"
                          fill="none"
                          stroke="#4a9eff"
                          strokeWidth="3"
                          strokeDasharray={`${2 * Math.PI * 56}`}
                          strokeDashoffset={`${2 * Math.PI * 56 * (1 - progress / 100)}`}
                          strokeLinecap="round"
                          className="transition-all duration-1000 ease-linear"
                        />
                      </svg>
                      <div className="absolute inset-0 flex flex-col items-center justify-center">
                        <div className="text-[9px] font-medium tracking-wider text-foreground/50 uppercase">
                          Deep Focus
                        </div>
                        <div className="text-xs text-foreground/30 mt-1">
                          {Math.round(progress)}%
                        </div>
                      </div>
                    </div>
                    <div className="font-mono text-4xl tracking-tight mb-6">
                      {formatTime(timeLeft)}
                    </div>
                    <div className="flex gap-2 justify-center">
                      <button
                        onClick={() => setIsRunning(!isRunning)}
                        className="flex-1 h-9 px-4 bg-transparent text-foreground border border-foreground/15 rounded-full text-sm font-medium flex items-center justify-center gap-2 hover:bg-foreground/5 transition-all duration-200"
                      >
                        {isRunning ? (
                          <>
                            <Pause size={14} strokeWidth={2} /> Pause
                          </>
                        ) : (
                          <>
                            <Play size={14} strokeWidth={2} /> Start
                          </>
                        )}
                      </button>
                      <button
                        onClick={() => {
                          setTimeLeft(25 * 60);
                          setProgress(0);
                          setIsRunning(false);
                        }}
                        className="h-9 px-4 bg-transparent text-foreground/40 border border-foreground/8 rounded-full text-sm font-medium flex items-center justify-center gap-2 hover:bg-foreground/5 transition-all duration-200"
                      >
                        <RotateCcw size={14} strokeWidth={2} /> Reset
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Features Grid */}
      <section className="py-24 border-t border-foreground/10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16 animate-fade-up">
            <h2 className="text-3xl lg:text-4xl font-light mb-4">
              Designed for <span className="font-medium">Deep Work</span>
            </h2>
            <p className="text-lg text-foreground/60 max-w-2xl mx-auto">
              Every detail crafted to help you maintain focus and build better work habits.
            </p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
            {features.map((feature, index) => (
              <div
                key={index}
                className="group p-6 rounded-xl border border-foreground/10 hover:border-foreground/20 transition-all duration-300 animate-fade-up"
                style={{ animationDelay: `${index * 100}ms` }}
              >
                <div className="w-12 h-12 rounded-lg bg-accent/10 text-accent flex items-center justify-center mb-4 group-hover:scale-110 transition-transform duration-300">
                  {feature.icon}
                </div>
                <h3 className="text-xl font-medium mb-2">{feature.title}</h3>
                <p className="text-foreground/60">{feature.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Screenshots */}
      <section className="py-24 border-t border-foreground/10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16 animate-fade-up">
            <h2 className="text-3xl lg:text-4xl font-light mb-4">
              Multiple <span className="font-medium">Watchfaces</span>
            </h2>
            <p className="text-lg text-foreground/60 max-w-2xl mx-auto">
              Choose from our collection of beautifully designed themes or create your own.
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-6">
            <div className="relative group cursor-pointer animate-fade-up">
              <div className="absolute inset-0 bg-accent/20 blur-xl opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
              <div className="relative bg-background/50 backdrop-blur rounded-lg p-6 border border-foreground/10 hover:border-foreground/20 transition-all duration-300">
                <h3 className="text-lg font-medium mb-2">Minimal</h3>
                <p className="text-sm text-foreground/60">Clean and distraction-free</p>
              </div>
            </div>
            <div className="relative group cursor-pointer animate-fade-up" style={{ animationDelay: "100ms" }}>
              <div className="absolute inset-0 bg-accent/20 blur-xl opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
              <div className="relative bg-background/50 backdrop-blur rounded-lg p-6 border border-foreground/10 hover:border-foreground/20 transition-all duration-300">
                <h3 className="text-lg font-medium mb-2">Terminal</h3>
                <p className="text-sm text-foreground/60">For the command line lovers</p>
              </div>
            </div>
            <div className="relative group cursor-pointer animate-fade-up" style={{ animationDelay: "200ms" }}>
              <div className="absolute inset-0 bg-accent/20 blur-xl opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
              <div className="relative bg-background/50 backdrop-blur rounded-lg p-6 border border-foreground/10 hover:border-foreground/20 transition-all duration-300">
                <h3 className="text-lg font-medium mb-2">Neon</h3>
                <p className="text-sm text-foreground/60">Vibrant and energetic</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-24 border-t border-foreground/10">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-3xl lg:text-4xl font-light mb-6 animate-fade-up">
            Start focusing <span className="font-medium">today</span>
          </h2>
          <p className="text-lg text-foreground/60 mb-8 animate-fade-up" style={{ animationDelay: "100ms" }}>
            Free and open source. No account needed. Just download and start.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center animate-fade-up" style={{ animationDelay: "200ms" }}>
            <a
              href="https://github.com/arach/pomo/releases/latest"
              className="inline-flex items-center justify-center gap-2 px-8 py-4 bg-accent text-background font-medium rounded-full hover:bg-accent/90 transition-all duration-200 hover:scale-105"
            >
              <Download className="w-5 h-5" />
              Download for macOS
            </a>
          </div>
          <p className="text-sm text-foreground/40 mt-6 animate-fade-up" style={{ animationDelay: "300ms" }}>
            Requires macOS 10.15 or later
          </p>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-foreground/10 py-12">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col md:flex-row justify-between items-center gap-4">
            <div className="text-sm text-foreground/40">
              © 2024 Pomo. Open source under MIT License.
            </div>
            <div className="flex gap-6">
              <a
                href="https://github.com/arach/pomo"
                className="text-sm text-foreground/60 hover:text-foreground transition-colors"
              >
                GitHub
              </a>
              <a
                href="https://github.com/arach/pomo/issues"
                className="text-sm text-foreground/60 hover:text-foreground transition-colors"
              >
                Support
              </a>
              <a
                href="https://github.com/arach/pomo/blob/main/LICENSE"
                className="text-sm text-foreground/60 hover:text-foreground transition-colors"
              >
                License
              </a>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}