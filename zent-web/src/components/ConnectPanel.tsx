import { useState } from 'react';
import { motion } from 'framer-motion';
import { Link2, Copy, Check, UserPlus } from 'lucide-react';
import { useZent } from '@/context/ZentContext';
import { toast } from '@/hooks/use-toast';
import { InputOTP, InputOTPGroup, InputOTPSlot } from '@/components/ui/input-otp';

const ConnectPanel = () => {
  const { peerId, connectToPeer } = useZent();
  const [remotePin, setRemotePin] = useState('');
  const [copied, setCopied] = useState(false);
  const [connecting, setConnecting] = useState(false);

  const copyId = async () => {
    await navigator.clipboard.writeText(peerId);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleConnect = async (pin?: string) => {
    const targetPin = pin || remotePin;
    if (targetPin.length !== 4) return;
    setConnecting(true);
    try {
      await connectToPeer(targetPin);
      setRemotePin('');
      toast({ title: '🔗 Connecting...', description: 'Waiting for device response' });
    } catch {
      toast({ title: '❌ Connection failed', variant: 'destructive' });
    }
    setConnecting(false);
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      className="glass rounded-2xl p-4 mx-4 mb-4"
    >
      {/* Your PIN */}
      <div className="flex items-center gap-3 mb-4">
        <div className="w-8 h-8 rounded-lg gradient-primary flex items-center justify-center shrink-0">
          <Link2 className="w-4 h-4 text-primary-foreground" />
        </div>
        <div className="flex-1 min-w-0">
          <p className="text-xs text-muted-foreground">Your PIN (share this)</p>
          <div className="flex items-center gap-2 mt-0.5">
            {peerId ? (
              <span className="text-2xl font-bold tracking-[0.3em] font-mono gradient-text">{peerId}</span>
            ) : (
              <span className="text-sm text-muted-foreground">Initializing...</span>
            )}
          </div>
        </div>
        <button
          onClick={copyId}
          className="shrink-0 w-8 h-8 rounded-lg bg-muted flex items-center justify-center hover:bg-primary hover:text-primary-foreground transition-colors"
        >
          {copied ? <Check className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
        </button>
      </div>

      {/* Connect with PIN */}
      <div className="flex flex-col items-center gap-3">
        <p className="text-xs text-muted-foreground">Enter peer's 4-digit PIN</p>
        <div className="flex items-center gap-3">
          <InputOTP
            maxLength={4}
            value={remotePin}
            onChange={(value) => {
              setRemotePin(value);
              if (value.length === 4) handleConnect(value);
            }}
            pattern="^[0-9]*$"
          >
            <InputOTPGroup>
              <InputOTPSlot index={0} className="w-12 h-14 text-xl font-bold rounded-xl border-border bg-muted" />
              <InputOTPSlot index={1} className="w-12 h-14 text-xl font-bold rounded-xl border-border bg-muted" />
              <InputOTPSlot index={2} className="w-12 h-14 text-xl font-bold rounded-xl border-border bg-muted" />
              <InputOTPSlot index={3} className="w-12 h-14 text-xl font-bold rounded-xl border-border bg-muted" />
            </InputOTPGroup>
          </InputOTP>
          <button
            onClick={() => handleConnect()}
            disabled={connecting || remotePin.length !== 4}
            className="px-4 py-3 rounded-xl gradient-primary text-primary-foreground text-sm font-medium disabled:opacity-50 flex items-center gap-1"
          >
            <UserPlus className="w-4 h-4" />
            {connecting ? '...' : 'Join'}
          </button>
        </div>
      </div>
    </motion.div>
  );
};

export default ConnectPanel;
