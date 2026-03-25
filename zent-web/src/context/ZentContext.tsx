import React, { createContext, useContext, useState, useCallback, useEffect, useRef } from 'react';
import { getPeerService, ZentPeerService, PeerDeviceInfo, FileMetaPayload } from '@/lib/peer-service';
import { toast } from '@/hooks/use-toast';

export interface Device {
  id: string;
  name: string;
  type: 'phone' | 'laptop' | 'tablet' | 'desktop';
  status: 'online' | 'offline' | 'busy';
  lastSeen: number;
  peerId?: string;
}

export interface FileTransfer {
  id: string;
  fileName: string;
  fileSize: number;
  progress: number;
  speed: number;
  status: 'queued' | 'transferring' | 'completed' | 'failed' | 'paused';
  targetDevice: string;
  direction: 'send' | 'receive';
  startTime: number;
  senderPeerId?: string;
}

export interface ClipboardEntry {
  id: string;
  content: string;
  type: 'text' | 'url' | 'otp' | 'image';
  timestamp: number;
  fromDevice: string;
}

export interface ActiveTransferAnimation {
  transferId: string;
  fromDeviceId: string;
  toDeviceId: string;
  progress: number;
}

export interface SpeedDataPoint {
  time: number;
  speed: number;
}

interface ZentContextType {
  devices: Device[];
  myDevice: Device;
  transfers: FileTransfer[];
  clipboard: ClipboardEntry[];
  theme: 'light' | 'dark' | 'amoled';
  turboMode: boolean;
  autoClipSync: boolean;
  setTheme: (t: 'light' | 'dark' | 'amoled') => void;
  setTurboMode: (v: boolean) => void;
  setAutoClipSync: (v: boolean) => void;
  addTransfer: (t: FileTransfer) => void;
  updateTransfer: (id: string, updates: Partial<FileTransfer>) => void;
  addClipboardEntry: (e: ClipboardEntry) => void;
  totalTransferred: number;
  totalDataMB: number;
  setMyDeviceName: (name: string) => void;
  peerId: string;
  connectToPeer: (remotePin: string) => Promise<void>;
  sendFileToPeer: (peerId: string, files: FileList) => void;
  syncClipboardToPeers: (content: string, clipType: string) => void;
  activeAnimations: ActiveTransferAnimation[];
  peerService: ZentPeerService;
  pauseTransfer: (id: string) => void;
  resumeTransfer: (id: string) => void;
  cancelTransfer: (id: string) => void;
  speedHistory: SpeedDataPoint[];
}

const ZentContext = createContext<ZentContextType | null>(null);

export const useZent = () => {
  const ctx = useContext(ZentContext);
  if (!ctx) throw new Error('useZent must be used within ZentProvider');
  return ctx;
};

export const ZentProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [theme, setThemeState] = useState<'light' | 'dark' | 'amoled'>(() => {
    return (localStorage.getItem('zent-theme') as any) || 'dark';
  });
  const [turboMode, setTurboMode] = useState(false);
  const [autoClipSync, setAutoClipSync] = useState(false);
  const [transfers, setTransfers] = useState<FileTransfer[]>([]);
  const [clipboard, setClipboard] = useState<ClipboardEntry[]>([]);
  const [devices, setDevices] = useState<Device[]>([]);
  const [peerId, setPeerId] = useState('');
  const [activeAnimations, setActiveAnimations] = useState<ActiveTransferAnimation[]>([]);
  const [speedHistory, setSpeedHistory] = useState<SpeedDataPoint[]>([]);
  const [myDevice, setMyDevice] = useState<Device>({
    id: 'self', name: localStorage.getItem('zent-device-name') || 'My Device', type: 'laptop', status: 'online', lastSeen: Date.now(),
  });

  const peerServiceRef = useRef<ZentPeerService>(getPeerService());
  const autoClipSyncRef = useRef(autoClipSync);
  const devicesRef = useRef(devices);
  autoClipSyncRef.current = autoClipSync;
  devicesRef.current = devices;

  const setTheme = useCallback((t: 'light' | 'dark' | 'amoled') => {
    setThemeState(t);
    localStorage.setItem('zent-theme', t);
  }, []);

  useEffect(() => {
    const root = document.documentElement;
    root.classList.remove('dark', 'amoled');
    if (theme === 'dark') root.classList.add('dark');
    else if (theme === 'amoled') root.classList.add('dark', 'amoled');
  }, [theme]);

  const addTransfer = useCallback((t: FileTransfer) => setTransfers(p => [t, ...p]), []);
  const updateTransfer = useCallback((id: string, updates: Partial<FileTransfer>) => {
    setTransfers(p => p.map(t => t.id === id ? { ...t, ...updates } : t));
    if (updates.progress !== undefined) {
      setActiveAnimations(prev => prev.map(a => a.transferId === id ? { ...a, progress: updates.progress! } : a));
    }
    if (updates.status === 'completed' || updates.status === 'failed') {
      setActiveAnimations(prev => prev.filter(a => a.transferId !== id));
    }
  }, []);
  const addClipboardEntry = useCallback((e: ClipboardEntry) => setClipboard(p => [e, ...p].slice(0, 50)), []);
  const setMyDeviceName = useCallback((name: string) => {
    setMyDevice(d => ({ ...d, name }));
    peerServiceRef.current.setDeviceName(name);
  }, []);

  // Speed history tracking
  useEffect(() => {
    const interval = setInterval(() => {
      setTransfers(current => {
        const activeTransfers = current.filter(t => t.status === 'transferring');
        if (activeTransfers.length > 0) {
          const avgSpeed = activeTransfers.reduce((sum, t) => sum + t.speed, 0) / activeTransfers.length;
          setSpeedHistory(prev => [...prev.slice(-59), { time: Date.now(), speed: avgSpeed }]);
        }
        return current;
      });
    }, 500);
    return () => clearInterval(interval);
  }, []);

  // Pause/Resume/Cancel
  const pauseTransfer = useCallback((id: string) => {
    peerServiceRef.current.pauseTransfer(id);
    setTransfers(p => p.map(t => t.id === id ? { ...t, status: 'paused' as const } : t));
  }, []);

  const resumeTransfer = useCallback((id: string) => {
    peerServiceRef.current.resumeTransfer(id);
    setTransfers(p => p.map(t => t.id === id ? { ...t, status: 'transferring' as const } : t));
  }, []);

  const cancelTransfer = useCallback((id: string) => {
    const transfer = transfers.find(t => t.id === id);
    peerServiceRef.current.cancelTransfer(id, transfer?.senderPeerId);
    setTransfers(p => p.filter(t => t.id !== id));
    setActiveAnimations(prev => prev.filter(a => a.transferId !== id));
  }, [transfers]);

  // Initialize peer
  useEffect(() => {
    const svc = peerServiceRef.current;
    
    svc.setHandlers({
      onPeerConnected: (info: PeerDeviceInfo) => {
        setDevices(prev => {
          const exists = prev.find(d => d.peerId === info.peerId);
          if (exists) {
            return prev.map(d => d.peerId === info.peerId ? { ...d, name: info.name, type: info.type, status: 'online' as const, lastSeen: Date.now() } : d);
          }
          return [...prev, {
            id: info.peerId,
            peerId: info.peerId,
            name: info.name,
            type: info.type,
            status: 'online' as const,
            lastSeen: Date.now(),
          }];
        });
        toast({ title: '📱 Device connected', description: `${info.name} joined the network` });
      },
      onPeerDisconnected: (pid: string) => {
        setDevices(prev => prev.map(d => d.peerId === pid ? { ...d, status: 'offline' as const } : d));
      },
      onFileMeta: (pid: string, meta: FileMetaPayload) => {
        const device = devicesRef.current.find(d => d.peerId === pid);
        const transfer: FileTransfer = {
          id: meta.transferId,
          fileName: meta.fileName,
          fileSize: meta.fileSize,
          progress: 0,
          speed: 0,
          status: 'transferring',
          targetDevice: device?.name || pid,
          direction: 'receive',
          startTime: Date.now(),
          senderPeerId: pid,
        };
        setTransfers(p => [transfer, ...p]);
        setActiveAnimations(prev => [...prev, { transferId: meta.transferId, fromDeviceId: pid, toDeviceId: 'self', progress: 0 }]);
        toast({ title: '📥 Incoming file', description: `Receiving ${meta.fileName}` });
      },
      onFileChunk: () => {},
      onFileComplete: (_pid: string, transferId: string) => {
        setTransfers(p => p.map(t => t.id === transferId ? { ...t, status: 'completed' as const, progress: 100 } : t));
        setActiveAnimations(prev => prev.filter(a => a.transferId !== transferId));
        toast({ title: '✅ Transfer complete', description: 'File downloaded!' });
      },
      onFileReceivedAck: (transferId: string) => {
        // Sender now knows receiver got the file - mark as completed
        svc.completeTransfer(transferId);
        setTransfers(p => p.map(t => t.id === transferId ? { ...t, status: 'completed' as const, progress: 100 } : t));
        setActiveAnimations(prev => prev.filter(a => a.transferId !== transferId));
        toast({ title: '✅ File delivered!', description: 'Receiver confirmed download' });
      },
      onClipboardSync: (pid: string, content: string, clipType: string) => {
        const device = devicesRef.current.find(d => d.peerId === pid);
        const detectedType = clipType === 'url' ? 'url' : clipType === 'otp' ? 'otp' : 'text';
        const entry: ClipboardEntry = {
          id: crypto.randomUUID(),
          content,
          type: detectedType as any,
          timestamp: Date.now(),
          fromDevice: device?.name || pid,
        };
        setClipboard(p => [entry, ...p].slice(0, 50));
        if (autoClipSyncRef.current) {
          navigator.clipboard.writeText(content).catch(() => {});
        }
        toast({ title: '📋 Clipboard synced', description: `From ${device?.name || 'peer'}` });
      },
      onTransferProgress: (transferId: string, progress: number, speed: number) => {
        setTransfers(p => p.map(t => t.id === transferId ? { ...t, progress, speed, status: 'transferring' as const } : t));
        setActiveAnimations(prev => prev.map(a => a.transferId === transferId ? { ...a, progress } : a));
      },
      onTransferCancelled: (transferId: string) => {
        setTransfers(p => p.filter(t => t.id !== transferId));
        setActiveAnimations(prev => prev.filter(a => a.transferId !== transferId));
      },
      onTransferPaused: (transferId: string) => {
        setTransfers(p => p.map(t => t.id === transferId ? { ...t, status: 'paused' as const } : t));
      },
      onTransferResumed: (transferId: string) => {
        setTransfers(p => p.map(t => t.id === transferId ? { ...t, status: 'transferring' as const } : t));
      },
    });

    svc.initialize().then(pin => {
      setPeerId(pin);
    }).catch(err => {
      console.error('[Zent] Failed to initialize peer:', err);
    });

    return () => { /* keep peer alive across remounts */ };
  }, []);

  const connectToPeer = useCallback(async (remotePin: string) => {
    await peerServiceRef.current.connectToPeer(remotePin);
  }, []);

  const sendFileToPeer = useCallback((targetPeerId: string, files: FileList) => {
    const device = devicesRef.current.find(d => d.peerId === targetPeerId);
    Array.from(files).forEach(file => {
      const transferId = crypto.randomUUID();
      const transfer: FileTransfer = {
        id: transferId,
        fileName: file.name,
        fileSize: file.size,
        progress: 0,
        speed: 0,
        status: 'transferring',
        targetDevice: device?.name || targetPeerId,
        direction: 'send',
        startTime: Date.now(),
      };
      setTransfers(p => [transfer, ...p]);
      setActiveAnimations(prev => [...prev, { transferId, fromDeviceId: 'self', toDeviceId: targetPeerId, progress: 0 }]);

      peerServiceRef.current.sendFile(targetPeerId, file, transferId, (progress, speed) => {
        setTransfers(p => p.map(t => t.id === transferId ? { ...t, progress, speed, status: 'transferring' as const } : t));
        setActiveAnimations(prev => prev.map(a => a.transferId === transferId ? { ...a, progress } : a));
      }).then(() => {
        // Don't mark as completed here - wait for receiver ack
        // The onFileReceivedAck handler will mark it as completed
      }).catch((err) => {
        if (err?.message === 'Transfer cancelled') return;
        setTransfers(p => p.map(t => t.id === transferId ? { ...t, status: 'failed' as const } : t));
        setActiveAnimations(prev => prev.filter(a => a.transferId !== transferId));
        toast({ title: '❌ Transfer failed', description: file.name, variant: 'destructive' });
      });
    });
  }, []);

  const syncClipboardToPeers = useCallback((content: string, clipType: string) => {
    peerServiceRef.current.syncClipboard(content, clipType);
  }, []);

  const totalTransferred = transfers.filter(t => t.status === 'completed').length;
  const totalDataMB = transfers.filter(t => t.status === 'completed').reduce((a, t) => a + t.fileSize, 0) / (1024 * 1024);

  return (
    <ZentContext.Provider value={{
      devices,
      myDevice,
      transfers,
      clipboard,
      theme,
      turboMode,
      autoClipSync,
      setTheme,
      setTurboMode,
      setAutoClipSync,
      addTransfer,
      updateTransfer,
      addClipboardEntry,
      totalTransferred,
      totalDataMB,
      setMyDeviceName,
      peerId,
      connectToPeer,
      sendFileToPeer,
      syncClipboardToPeers,
      activeAnimations,
      peerService: peerServiceRef.current,
      pauseTransfer,
      resumeTransfer,
      cancelTransfer,
      speedHistory,
    }}>
      {children}
    </ZentContext.Provider>
  );
};
