import { Suspense } from "react";
import HomeContent from "./home-content";

export default function Home() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-gray-400 font-mono text-sm">Loading...</div>
      </div>
    }>
      <HomeContent />
    </Suspense>
  );
}