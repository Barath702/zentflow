import { motion } from 'framer-motion';
import { Copy, ExternalLink, Key, Type, Check, Send } from 'lucide-react';
import { useZent } from '@/context/ZentContext';
import { useState } from 'react';

const typeIcons = {
  text: Type,
  url: ExternalLink,
  otp: Key,
  image: Type,
};

function detectClipType(text: string): 'url' | 'otp' | 'text' {
  if (/^https?:\/\//i.test(text)) return 'url';
  if (/^\d{4,8}$/.test(text.trim())) return 'otp';
  return 'text';
}

const ClipboardPanel = () => {
  const { clipboard, autoClipSync, setAutoClipSync, syncClipboardToPeers, addClipboardEntry, myDevice, devices } = useZent();
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [newClip, setNewClip] = useState('');

  const copyToClipboard = async (id: string, content: string) => {
    await navigator.clipboard.writeText(content);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 1500);
  };

  const sendClipboard = () => {
    if (!newClip.trim()) return;
    const clipType = detectClipType(newClip);
    syncClipboardToPeers(newClip, clipType);
    addClipboardEntry({
      id: crypto.randomUUID(),
      content: newClip,
      type: clipType,
      timestamp: Date.now(),
      fromDevice: myDevice.name + ' (you)',
    });
    setNewClip('');
  };

  return (
    <div className="px-4 pb-24">
      {/* Send clipboard content */}
      <div className="flex gap-2 mb-4">
        <input
          type="text"
          value={newClip}
          onChange={e => setNewClip(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && sendClipboard()}
          placeholder="Type or paste to share..."
          className="flex-1 px-3 py-2 rounded-xl bg-muted text-foreground text-sm outline-none focus:ring-2 focus:ring-primary transition-all"
        />
        <button
          onClick={sendClipboard}
          disabled={!newClip.trim() || devices.filter(d => d.status === 'online').length === 0}
          className="px-4 py-2 rounded-xl gradient-primary text-primary-foreground text-sm font-medium disabled:opacity-50 flex items-center gap-1"
        >
          <Send className="w-4 h-4" />
        </button>
      </div>

      {/* Toggle */}
      <div className="flex items-center justify-between glass rounded-2xl p-4 mb-4">
        <div>
          <p className="font-display font-semibold text-sm">Auto-sync clipboard</p>
          <p className="text-xs text-muted-foreground">Auto-copy received clips</p>
        </div>
        <button
          onClick={() => setAutoClipSync(!autoClipSync)}
          className={`w-12 h-7 rounded-full transition-colors duration-200 flex items-center px-0.5 ${
            autoClipSync ? 'gradient-primary' : 'bg-muted'
          }`}
        >
          <motion.div
            className="w-6 h-6 rounded-full bg-card shadow-md"
            animate={{ x: autoClipSync ? 20 : 0 }}
            transition={{ type: 'spring', stiffness: 500, damping: 30 }}
          />
        </button>
      </div>

      {/* Entries */}
      {clipboard.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
          <Copy className="w-10 h-10 mb-3 opacity-40" />
          <p className="font-display font-medium text-sm">No clipboard entries</p>
          <p className="text-xs mt-1">Share text with connected devices</p>
        </div>
      ) : (
        <div className="flex flex-col gap-3">
          {clipboard.map((entry, i) => {
            const Icon = typeIcons[entry.type];
            return (
              <motion.div
                key={entry.id}
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: i * 0.05 }}
                className="glass rounded-2xl p-4"
              >
                <div className="flex items-start gap-3">
                  <div className={`w-8 h-8 rounded-lg flex items-center justify-center shrink-0 ${
                    entry.type === 'url' ? 'gradient-primary' :
                    entry.type === 'otp' ? 'gradient-warm' : 'gradient-accent'
                  }`}>
                    <Icon className="w-4 h-4 text-primary-foreground" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className={`text-sm break-all ${entry.type === 'otp' ? 'font-mono font-bold tracking-widest text-lg' : ''}`}>
                      {entry.content}
                    </p>
                    <p className="text-[10px] text-muted-foreground mt-1">
                      from {entry.fromDevice} · {new Date(entry.timestamp).toLocaleTimeString()}
                    </p>
                  </div>
                  <button
                    onClick={() => copyToClipboard(entry.id, entry.content)}
                    className="shrink-0 w-8 h-8 rounded-lg bg-muted flex items-center justify-center hover:bg-primary hover:text-primary-foreground transition-colors"
                  >
                    {copiedId === entry.id ? <Check className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
                  </button>
                </div>
              </motion.div>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default ClipboardPanel;
