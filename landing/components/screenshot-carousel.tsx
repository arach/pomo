"use client";

import React, { useState, useEffect } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";

interface Screenshot {
  src: string;
  alt: string;
  title: string;
  description: string;
  type: 'desktop' | 'watch' | 'mobile';
}

const screenshots: Screenshot[] = [
  {
    src: "/pomo-desktop.png",
    alt: "Pomo Timer",
    title: "Focus Timer",
    description: "Clean, distraction-free interface",
    type: 'desktop'
  },
  {
    src: "/pomo-settings.png", 
    alt: "Settings",
    title: "Customizable",
    description: "Tailor every aspect to your workflow",
    type: 'desktop'
  },
  {
    src: "/pomo-keyboard.png",
    alt: "Keyboard Shortcuts",
    title: "Keyboard First",
    description: "Complete control without lifting your hands",
    type: 'desktop'
  },
  {
    src: "/pomo-watch.png",
    alt: "Apple Watch",
    title: "On Your Wrist",
    description: "6 unique themes for Apple Watch",
    type: 'watch'
  }
];

export default function ScreenshotCarousel() {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [isAutoPlaying, setIsAutoPlaying] = useState(true);

  useEffect(() => {
    if (!isAutoPlaying) return;
    
    const interval = setInterval(() => {
      setCurrentIndex((prev) => (prev + 1) % screenshots.length);
    }, 4000);

    return () => clearInterval(interval);
  }, [isAutoPlaying]);

  const goToSlide = (index: number) => {
    setCurrentIndex(index);
    setIsAutoPlaying(false);
    // Resume autoplay after user interaction
    setTimeout(() => setIsAutoPlaying(true), 10000);
  };

  const goToPrevious = () => {
    goToSlide((currentIndex - 1 + screenshots.length) % screenshots.length);
  };

  const goToNext = () => {
    goToSlide((currentIndex + 1) % screenshots.length);
  };

  const current = screenshots[currentIndex];

  return (
    <div className="relative">
      {/* Main carousel container */}
      <div className="relative">
        
        {/* Title and description - always visible */}
        <div className="text-center mb-8">
          <h3 className="text-2xl font-inter font-bold mb-2 text-gray-900 transition-all duration-500">
            {current.title}
          </h3>
          <p className="text-gray-600 font-inter text-sm transition-all duration-500">
            {current.description}
          </p>
        </div>

        {/* Image container with optimized sizing */}
        <div className="relative mx-auto" style={{ maxWidth: '600px' }}>
          <div className="relative" style={{ paddingBottom: '60%' }}>
            {screenshots.map((screenshot, index) => (
              <div
                key={screenshot.src}
                className={`absolute inset-0 flex items-center justify-center transition-all duration-700 ${
                  index === currentIndex 
                    ? 'opacity-100 scale-100' 
                    : 'opacity-0 scale-95 pointer-events-none'
                }`}
              >
                {screenshot.type === 'watch' ? (
                  <div className="flex items-center justify-center h-full">
                    <img
                      src={screenshot.src}
                      alt={screenshot.alt}
                      className="w-24 md:w-32 h-auto rounded-[1.5rem]"
                    />
                  </div>
                ) : (
                  <img
                    src={screenshot.src}
                    alt={screenshot.alt}
                    className="w-full h-full object-contain rounded-xl"
                  />
                )}
              </div>
            ))}
          </div>
        </div>

        {/* Navigation arrows */}
        <button
          onClick={goToPrevious}
          className="absolute left-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-700 p-2 rounded-full transition-all hover:scale-110"
          aria-label="Previous screenshot"
        >
          <ChevronLeft className="w-6 h-6" />
        </button>
        <button
          onClick={goToNext}
          className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-700 p-2 rounded-full transition-all hover:scale-110"
          aria-label="Next screenshot"
        >
          <ChevronRight className="w-6 h-6" />
        </button>

        {/* Dot indicators */}
        <div className="flex justify-center gap-2 mt-8">
          {screenshots.map((_, index) => (
            <button
              key={index}
              onClick={() => goToSlide(index)}
              className={`transition-all duration-300 ${
                index === currentIndex 
                  ? 'w-8 h-2 bg-gray-800 rounded-full' 
                  : 'w-2 h-2 bg-gray-300 hover:bg-gray-400 rounded-full'
              }`}
              aria-label={`Go to screenshot ${index + 1}`}
            />
          ))}
        </div>
      </div>

      {/* Simplified thumbnail strip */}
      <div className="mt-6 flex justify-center gap-2 px-4">
        {screenshots.map((screenshot, index) => (
          <button
            key={screenshot.src}
            onClick={() => goToSlide(index)}
            className={`relative transition-all duration-300 ${
              index === currentIndex 
                ? 'opacity-100' 
                : 'opacity-40 hover:opacity-70'
            }`}
          >
            {screenshot.type === 'watch' ? (
              <div className="w-10 h-14 bg-gray-100 rounded flex items-center justify-center">
                <div className="w-5 h-7 bg-gray-300 rounded-sm"></div>
              </div>
            ) : (
              <div className="w-14 h-10 bg-gray-100 rounded overflow-hidden">
                <img
                  src={screenshot.src}
                  alt=""
                  className="w-full h-full object-cover"
                />
              </div>
            )}
          </button>
        ))}
      </div>
    </div>
  );
}