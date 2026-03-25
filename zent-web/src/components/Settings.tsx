import { motion } from 'framer-motion';
import { Sun, Moon, Eclipse, Zap, User, Shield, Link2, Copy, Check } from 'lucide-react';
import { useZent } from '@/context/ZentContext';
import { useState } from 'react';

const Settings = () => {
  const { theme, setTheme, turboMode, setTurboMode, myDevice, setMyDeviceName, peerId, devices } = useZent();
  const [copied, setCopied] = useState(false);

  const themes = [
    { value: 'light' as const, icon: Sun, label: 'Light' },
    { value: 'dark' as const, icon: Moon, label: 'Dark' },
    { value: 'amoled' as const, icon: Eclipse, label: 'AMOLED' },
  ];

  const copyId = async () => {
    await navigator.clipboard.writeText(peerId);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="px-4 pb-24 flex flex-col gap-4">
      {/* Device name */}
      <div className="glass rounded-2xl p-4">
        <div className="flex items-center gap-3 mb-3">
          <div className="w-10 h-10 rounded-xl gradient-primary flex items-center justify-center">
            <User className="w-5 h-5 text-primary-foreground" />
          </div>
          <div>
            <p className="font-display font-semibold text-sm">Device Name</p>
            <p className="text-xs text-muted-foreground">How others see you</p>
          </div>
        </div>
        <input
          type="text"
          value={myDevice.name}
          onChange={e => setMyDeviceName(e.target.value)}
          className="w-full px-3 py-2 rounded-xl bg-muted text-foreground text-sm outline-none focus:ring-2 focus:ring-primary transition-all"
        />
      </div>

      {/* Peer ID */}
      <div className="glass rounded-2xl p-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl gradient-accent flex items-center justify-center">
            <Link2 className="w-5 h-5 text-primary-foreground" />
          </div>
          <div className="flex-1 min-w-0">
            <p className="font-display font-semibold text-sm">Your Peer ID</p>
            <p className="text-xs text-muted-foreground font-mono truncate">{peerId || '...'}</p>
          </div>
          <button onClick={copyId} className="w-8 h-8 rounded-lg bg-muted flex items-center justify-center hover:bg-primary hover:text-primary-foreground transition-colors">
            {copied ? <Check className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
          </button>
        </div>
      </div>

      {/* Connected devices */}
      <div className="glass rounded-2xl p-4">
        <p className="font-display font-semibold text-sm mb-2">Connected Devices</p>
        {devices.filter(d => d.status === 'online').length === 0 ? (
          <p className="text-xs text-muted-foreground">No devices connected</p>
        ) : (
          <div className="flex flex-col gap-2">
            {devices.filter(d => d.status === 'online').map(d => (
              <div key={d.id} className="flex items-center gap-2">
                <div className="w-2 h-2 rounded-full bg-success" />
                <span className="text-sm">{d.name}</span>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Theme */}
      <div className="glass rounded-2xl p-4">
        <p className="font-display font-semibold text-sm mb-3">Theme</p>
        <div className="grid grid-cols-3 gap-2">
          {themes.map(t => (
            <button
              key={t.value}
              onClick={() => setTheme(t.value)}
              className={`flex flex-col items-center gap-2 p-3 rounded-xl transition-all ${
                theme === t.value ? 'gradient-primary text-primary-foreground' : 'bg-muted text-muted-foreground hover:bg-muted/80'
              }`}
            >
              <t.icon className="w-5 h-5" />
              <span className="text-xs font-medium">{t.label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Turbo mode */}
      <div className="glass rounded-2xl p-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl gradient-warm flex items-center justify-center">
              <Zap className="w-5 h-5 text-primary-foreground" />
            </div>
            <div>
              <p className="font-display font-semibold text-sm">Warp Speed 🚀</p>
              <p className="text-xs text-muted-foreground">Multi-threaded transfer</p>
            </div>
          </div>
          <button
            onClick={() => setTurboMode(!turboMode)}
            className={`w-12 h-7 rounded-full transition-colors duration-200 flex items-center px-0.5 ${
              turboMode ? 'gradient-warm' : 'bg-muted'
            }`}
          >
            <motion.div
              className="w-6 h-6 rounded-full bg-card shadow-md"
              animate={{ x: turboMode ? 20 : 0 }}
              transition={{ type: 'spring', stiffness: 500, damping: 30 }}
            />
          </button>
        </div>
      </div>

      {/* Security */}
      <div className="glass rounded-2xl p-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl gradient-primary flex items-center justify-center">
            <Shield className="w-5 h-5 text-primary-foreground" />
          </div>
          <div>
            <p className="font-display font-semibold text-sm">Privacy & Security</p>
            <p className="text-xs text-muted-foreground">P2P encrypted via WebRTC. No external servers for data.</p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Settings;
