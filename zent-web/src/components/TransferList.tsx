import { memo, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { FileText, Check, X, Pause, Play, ArrowUp, ArrowDown, Sparkles, Trash2 } from 'lucide-react';
import { useZent } from '@/context/ZentContext';
import SpeedGraph from './SpeedGraph';

const formatSize = (bytes: number) => {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1048576).toFixed(1)} MB`;
};

const TransferItem = memo(({ t, i, onPause, onResume, onCancel }: {
  t: any; i: number;
  onPause: (id: string) => void;
  onResume: (id: string) => void;
  onCancel: (id: string) => void;
}) => (
  <motion.div
    key={t.id}
    initial={{ opacity: 0, x: -20, scale: 0.95 }}
    animate={{ opacity: 1, x: 0, scale: 1 }}
    exit={{ opacity: 0, x: 20, scale: 0.95 }}
    transition={{ delay: i * 0.05, type: 'spring', stiffness: 300, damping: 25 }}
    className="glass rounded-2xl p-4 relative overflow-hidden"
  >
    {t.status === 'transferring' && (
      <motion.div
        className="absolute inset-0 gradient-primary opacity-5"
        animate={{ opacity: [0.03, 0.08, 0.03] }}
        transition={{ duration: 2, repeat: Infinity }}
      />
    )}

    <AnimatePresence>
      {t.status === 'completed' && (
        <motion.div
          initial={{ scale: 0, opacity: 0 }}
          animate={{ scale: [0, 1.5, 1], opacity: [0, 1, 0] }}
          transition={{ duration: 0.8 }}
          className="absolute inset-0 flex items-center justify-center"
        >
          <Sparkles className="w-20 h-20 text-success opacity-20" />
        </motion.div>
      )}
    </AnimatePresence>

    <div className="flex items-start gap-3 relative z-10">
      <motion.div
        className="w-10 h-10 rounded-xl gradient-primary flex items-center justify-center shrink-0"
        animate={t.status === 'transferring' ? { 
          boxShadow: ['0 0 0px hsla(262, 83%, 58%, 0)', '0 0 20px hsla(262, 83%, 58%, 0.4)', '0 0 0px hsla(262, 83%, 58%, 0)']
        } : {}}
        transition={{ duration: 1.5, repeat: Infinity }}
      >
        {t.direction === 'send' ? (
          <ArrowUp className="w-5 h-5 text-primary-foreground" />
        ) : (
          <ArrowDown className="w-5 h-5 text-primary-foreground" />
        )}
      </motion.div>
      <div className="flex-1 min-w-0">
        <p className="font-medium text-sm truncate">{t.fileName}</p>
        <p className="text-xs text-muted-foreground mt-0.5">
          {formatSize(t.fileSize)} → {t.targetDevice}
        </p>
        {(t.status === 'transferring' || t.status === 'paused') && (
          <div className="mt-2">
            <div className="h-2 rounded-full bg-muted overflow-hidden relative">
              <motion.div
                className={`h-full rounded-full relative ${t.status === 'paused' ? 'bg-warning' : ''}`}
                style={t.status !== 'paused' ? { background: 'var(--gradient-primary)' } : undefined}
                initial={{ width: 0 }}
                animate={{ width: `${t.progress}%` }}
                transition={{ duration: 0.3, ease: 'easeOut' }}
              >
                {t.status === 'transferring' && (
                  <motion.div
                    className="absolute inset-0 bg-gradient-to-r from-transparent via-white/30 to-transparent"
                    animate={{ x: ['-100%', '200%'] }}
                    transition={{ duration: 1.5, repeat: Infinity, ease: 'linear' }}
                  />
                )}
              </motion.div>
            </div>
            <div className="flex justify-between mt-1">
              <motion.span 
                className="text-[10px] text-muted-foreground"
                key={t.progress}
                initial={{ scale: 1.2 }}
                animate={{ scale: 1 }}
              >
                {t.progress}%{t.status === 'paused' ? ' (Paused)' : ''}
              </motion.span>
              <span className="text-[10px] text-primary font-medium">
                {t.status === 'paused' ? '—' : `${t.speed.toFixed(1)} MB/s`}
              </span>
            </div>
          </div>
        )}
      </div>
      <div className="shrink-0 flex items-center gap-1">
        {/* Controls for active/paused transfers */}
        {(t.status === 'transferring' || t.status === 'paused') && (
          <>
            {t.status === 'transferring' ? (
              <button
                onClick={() => onPause(t.id)}
                className="w-7 h-7 rounded-lg bg-muted flex items-center justify-center hover:bg-warning/20 transition-colors"
                title="Pause"
              >
                <Pause className="w-3.5 h-3.5 text-warning" />
              </button>
            ) : (
              <button
                onClick={() => onResume(t.id)}
                className="w-7 h-7 rounded-lg bg-muted flex items-center justify-center hover:bg-success/20 transition-colors"
                title="Resume"
              >
                <Play className="w-3.5 h-3.5 text-success" />
              </button>
            )}
            <button
              onClick={() => onCancel(t.id)}
              className="w-7 h-7 rounded-lg bg-muted flex items-center justify-center hover:bg-destructive/20 transition-colors"
              title="Cancel"
            >
              <Trash2 className="w-3.5 h-3.5 text-destructive" />
            </button>
          </>
        )}
        {t.status === 'completed' && (
          <motion.div
            initial={{ scale: 0, rotate: -180 }}
            animate={{ scale: 1, rotate: 0 }}
            transition={{ type: 'spring', stiffness: 400, damping: 15 }}
          >
            <Check className="w-5 h-5 text-success" />
          </motion.div>
        )}
        {t.status === 'failed' && <X className="w-5 h-5 text-destructive" />}
        {t.status === 'queued' && (
          <motion.div
            className="w-2.5 h-2.5 rounded-full bg-primary"
            animate={{ scale: [1, 1.5, 1], opacity: [1, 0.5, 1] }}
            transition={{ duration: 1, repeat: Infinity }}
          />
        )}
      </div>
    </div>
  </motion.div>
));
TransferItem.displayName = 'TransferItem';

const TransferList = () => {
  const { transfers, pauseTransfer, resumeTransfer, cancelTransfer, speedHistory } = useZent();

  const hasActiveTransfers = useMemo(() => 
    transfers.some(t => t.status === 'transferring'), 
    [transfers]
  );

  if (transfers.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-16 text-muted-foreground">
        <FileText className="w-12 h-12 mb-3 opacity-40" />
        <p className="font-display font-medium">No transfers yet</p>
        <p className="text-sm mt-1">Drop files in the Drop Zone to start</p>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-3 px-4 pb-24">
      {/* Speed Graph */}
      {(hasActiveTransfers || speedHistory.length > 0) && (
        <SpeedGraph data={speedHistory} />
      )}
      
      <AnimatePresence>
        {transfers.map((t, i) => (
          <TransferItem
            key={t.id}
            t={t}
            i={i}
            onPause={pauseTransfer}
            onResume={resumeTransfer}
            onCancel={cancelTransfer}
          />
        ))}
      </AnimatePresence>
    </div>
  );
};

export default TransferList;
