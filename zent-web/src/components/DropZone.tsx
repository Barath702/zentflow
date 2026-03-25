import { useState, useCallback, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Upload, Zap, FileText, Wifi } from 'lucide-react';
import { useZent } from '@/context/ZentContext';
import DeviceBubble from './DeviceBubble';
import ConnectPanel from './ConnectPanel';
import ParticleFlow from './ParticleFlow';

const DropZone = () => {
  const { devices, turboMode, sendFileToPeer, activeAnimations } = useZent();
  const [isDragging, setIsDragging] = useState(false);
  const [selectedDevice, setSelectedDevice] = useState<string | null>(null);
  const [recentFile, setRecentFile] = useState<string | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  const onlineDevices = devices.filter(d => d.status === 'online');

  const handleFiles = useCallback((files: FileList) => {
    const targetPeerId = selectedDevice;
    if (!targetPeerId) return;
    sendFileToPeer(targetPeerId, files);
    setRecentFile(files[0]?.name || null);
    setTimeout(() => setRecentFile(null), 2000);
  }, [selectedDevice, sendFileToPeer]);

  const onDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    if (e.dataTransfer.files.length) handleFiles(e.dataTransfer.files);
  }, [handleFiles]);

  return (
    <div className="flex flex-col items-center gap-4 px-4 py-4 w-full max-w-lg mx-auto relative">
      {/* Connect panel */}
      <ConnectPanel />

      {/* Device bubbles */}
      {onlineDevices.length > 0 ? (
        <div className="flex flex-wrap justify-center gap-4 w-full">
          {onlineDevices.map((device, i) => (
            <DeviceBubble
              key={device.id}
              device={device}
              index={i}
              selected={selectedDevice === device.peerId}
              onClick={() => setSelectedDevice(prev => prev === device.peerId ? null : device.peerId!)}
            />
          ))}
        </div>
      ) : (
        <div className="flex flex-col items-center gap-2 py-4 text-muted-foreground">
          <Wifi className="w-8 h-8 opacity-40" />
          <p className="text-sm">No devices connected yet</p>
          <p className="text-xs">Share your ID above to connect</p>
        </div>
      )}

      {/* Drop zone with particle effects */}
      <div className="relative w-full max-w-xs">
        <ParticleFlow />
        <motion.div
          onDragOver={e => { e.preventDefault(); setIsDragging(true); }}
          onDragLeave={() => setIsDragging(false)}
          onDrop={onDrop}
          onClick={() => selectedDevice && fileInput.current?.click()}
          className={`relative w-full aspect-square rounded-3xl glass cursor-pointer
            flex flex-col items-center justify-center gap-4 transition-all duration-300 overflow-hidden
            ${isDragging ? 'ring-2 ring-primary scale-105' : 'hover:scale-[1.02]'}
            ${!selectedDevice ? 'opacity-60 cursor-not-allowed' : ''}
          `}
          whileTap={selectedDevice ? { scale: 0.98 } : {}}
        >
          {/* Animated background */}
          <div className="absolute inset-0 gradient-primary opacity-10 rounded-3xl" />
          
          {/* Active transfer glow */}
          <AnimatePresence>
            {activeAnimations.length > 0 && (
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: [0.1, 0.3, 0.1] }}
                exit={{ opacity: 0 }}
                transition={{ duration: 1.5, repeat: Infinity }}
                className="absolute inset-0 gradient-primary rounded-3xl"
              />
            )}
          </AnimatePresence>
          
          {/* Ripple on drag */}
          <AnimatePresence>
            {isDragging && (
              <motion.div
                initial={{ scale: 0.5, opacity: 0.8 }}
                animate={{ scale: 2, opacity: 0 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 1, repeat: Infinity }}
                className="absolute w-24 h-24 rounded-full gradient-primary"
              />
            )}
          </AnimatePresence>

          <motion.div
            animate={isDragging ? { y: -10, scale: 1.2 } : { y: 0, scale: 1 }}
            className="relative z-10"
          >
            <Upload className="w-12 h-12 text-primary" />
          </motion.div>

          <div className="relative z-10 text-center">
            <p className="font-display font-semibold text-foreground">
              {activeAnimations.length > 0 
                ? 'Transferring...' 
                : isDragging 
                  ? 'Drop to send!' 
                  : selectedDevice 
                    ? 'Drop files here' 
                    : 'Select a device first'}
            </p>
            <p className="text-sm text-muted-foreground mt-1">
              {selectedDevice
                ? `Sending to ${devices.find(d => d.peerId === selectedDevice)?.name}`
                : onlineDevices.length > 0 ? 'Tap a device above' : 'Connect a device to start'}
            </p>
          </div>

          {turboMode && (
            <div className="absolute top-3 right-3 z-10 flex items-center gap-1 px-2 py-1 rounded-full gradient-warm">
              <Zap className="w-3 h-3 text-warning-foreground" />
              <span className="text-[10px] font-bold text-warning-foreground">WARP</span>
            </div>
          )}

          <input
            ref={fileInput}
            type="file"
            multiple
            className="hidden"
            onChange={e => e.target.files && handleFiles(e.target.files)}
          />
        </motion.div>
      </div>

      {/* Recent file indicator */}
      <AnimatePresence>
        {recentFile && (
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className="flex items-center gap-2 px-4 py-2 rounded-xl glass"
          >
            <FileText className="w-4 h-4 text-primary" />
            <span className="text-sm font-medium">{recentFile}</span>
            <span className="text-xs text-muted-foreground">sending...</span>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
};

export default DropZone;
