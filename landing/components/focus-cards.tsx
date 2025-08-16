"use client";

import React, { useState } from "react";
import Image from "next/image";
import { cn } from "../lib/utils";
import { X } from "lucide-react";

export type Card = {
  title: string;
  src: string;
  description: string;
  type?: 'desktop' | 'watch' | 'mobile';
  details?: string[];
};

export function FocusCards({ cards }: { cards: Card[] }) {
  const [hovered, setHovered] = useState<number | null>(null);
  const [selectedCard, setSelectedCard] = useState<Card | null>(null);

  return (
    <>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 max-w-6xl mx-auto w-full">
        {cards.map((card, index) => (
          <div
            key={card.title}
            onMouseEnter={() => setHovered(index)}
            onMouseLeave={() => setHovered(null)}
            onClick={() => setSelectedCard(card)}
            className={cn(
              "relative group transition-all duration-500 ease-out cursor-pointer",
              hovered !== null && hovered !== index && "opacity-50 scale-[0.98]"
            )}
          >
          <div className="flex flex-col h-full">
            {/* Image Container */}
            <div 
              className={cn(
                "relative overflow-hidden rounded-xl transition-all duration-500 bg-gray-50 h-44",
                card.type === 'watch' && 'flex items-center justify-center',
                hovered === index && "transform scale-[1.02]"
              )}
            >
              {card.type === 'watch' ? (
                <img
                  src={card.src}
                  alt={card.title}
                  className="w-20 h-auto rounded-xl"
                />
              ) : (
                <img
                  src={card.src}
                  alt={card.title}
                  className="w-full h-full object-cover object-top rounded-xl"
                />
              )}
            </div>

            {/* Content */}
            <div className="mt-4">
              <h3 
                className={cn(
                  "font-mono font-bold uppercase text-gray-900 transition-all duration-300",
                  hovered === index ? "text-sm" : "text-xs"
                )}
              >
                {card.title}
              </h3>
              <p 
                className={cn(
                  "mt-1 text-xs font-mono text-gray-500 transition-all duration-300 line-clamp-2",
                  hovered === index ? "opacity-100 text-gray-600" : "opacity-80"
                )}
              >
                {card.description}
              </p>
            </div>
          </div>
        </div>
      ))}
    </div>

    {/* Modal */}
    {selectedCard && (
      <div 
        className="fixed inset-0 z-[100] flex items-center justify-center bg-black/50 backdrop-blur-sm p-8"
        onClick={() => setSelectedCard(null)}
      >
        <div 
          className="relative bg-white rounded-2xl max-w-6xl w-full max-h-[85vh] overflow-hidden"
          onClick={(e) => e.stopPropagation()}
        >
          <button
            onClick={() => setSelectedCard(null)}
            className="absolute top-4 right-4 z-10 p-2 rounded-full bg-white/90 hover:bg-gray-100 transition-colors"
          >
            <X className="w-5 h-5 text-gray-700" />
          </button>

          <div className="grid md:grid-cols-2 h-full">
            {/* Image side */}
            <div className="bg-gray-50 p-8 flex items-center justify-center">
              {selectedCard.type === 'watch' ? (
                <img
                  src={selectedCard.src}
                  alt={selectedCard.title}
                  className="w-48 h-auto rounded-[2rem]"
                />
              ) : (
                <img
                  src={selectedCard.src}
                  alt={selectedCard.title}
                  className="w-full h-auto rounded-xl max-h-[60vh] object-contain"
                />
              )}
            </div>

            {/* Details side */}
            <div className="p-8 flex flex-col justify-center">
              <h2 className="text-2xl font-mono font-bold uppercase text-gray-900 mb-4">
                {selectedCard.title}
              </h2>
              <p className="text-sm font-mono text-gray-600 mb-6">
                {selectedCard.description}
              </p>
              
              {selectedCard.details && (
                <div className="space-y-2">
                  <h3 className="text-xs font-mono font-bold uppercase text-gray-700 mb-3">
                    Key Features
                  </h3>
                  <ul className="space-y-2">
                    {selectedCard.details.map((detail, idx) => (
                      <li key={idx} className="flex items-start gap-2">
                        <span className="text-gray-400 font-mono text-xs mt-0.5">→</span>
                        <span className="text-xs font-mono text-gray-600">{detail}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    )}
    </>
  );
}

export function FocusCardsDemo() {
  const cards: Card[] = [
    {
      title: "Timer",
      src: "/pomo-desktop.png",
      description: "Clean, distraction-free floating timer that stays out of your way",
      details: [
        "Floating always-on-top window",
        "Multiple beautiful watchfaces",
        "Smart break reminders",
        "Session history tracking",
        "Minimal CPU and memory usage"
      ]
    },
    {
      title: "Settings",
      src: "/pomo-settings.png",
      description: "Customize every aspect of your workflow with intuitive controls",
      details: [
        "Adjustable session durations",
        "Custom break intervals",
        "Sound and notification preferences",
        "Theme customization",
        "Auto-start options"
      ]
    },
    {
      title: "Shortcuts",
      src: "/pomo-keyboard.png",
      description: "Complete keyboard control for power users",
      details: [
        "Start/pause with spacebar",
        "Quick reset with R",
        "Skip breaks with S",
        "Toggle focus modes",
        "Fully customizable keybindings"
      ]
    },
    {
      title: "Watch",
      src: "/pomo-watch.png",
      description: "Track sessions directly from your wrist",
      type: 'watch',
      details: [
        "6 unique watch faces",
        "Haptic feedback",
        "Wrist-based controls",
        "Sync with desktop app",
        "Complications support"
      ]
    },
  ];

  return <FocusCards cards={cards} />;
}