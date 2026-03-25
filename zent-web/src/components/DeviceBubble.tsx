import { Smartphone, Laptop, Tablet, Monitor } from 'lucide-react';
import { motion } from 'framer-motion';
import type { Device } from '@/context/ZentContext';

const typeIcon = {
  phone: Smartphone,
  laptop: Laptop,
  tablet: Tablet,
  desktop: Monitor,
};

const statusColor = {
  online: 'bg-success',
  offline: 'bg-muted-foreground',
  busy: 'bg-warning',
};

interface Props {
  device: Device;
  index: number;
  onClick?: () => void;
  selected?: boolean;
}

const DeviceBubble = ({ device, index, onClick, selected }: Props) => {
  const Icon = typeIcon[device.type];

  return (
    <motion.button
      onClick={onClick}
      initial={{ scale: 0, opacity: 0 }}
      animate={{ scale: 1, opacity: 1 }}
      transition={{ delay: index * 0.1, type: 'spring', stiffness: 260, damping: 20 }}
      whileHover={{ scale: 1.1 }}
      whileTap={{ scale: 0.95 }}
      className={`relative flex flex-col items-center gap-1.5 group ${
        selected ? 'z-10' : ''
      }`}
      style={{ animation: `float ${3 + index * 0.5}s ease-in-out infinite` }}
    >
      <div className={`relative w-16 h-16 rounded-2xl glass flex items-center justify-center transition-all duration-300 ${
        selected ? 'ring-2 ring-primary animate-pulse-glow' : 'hover:shadow-lg'
      }`}>
        <Icon className="w-7 h-7 text-primary" />
        <span className={`absolute -bottom-0.5 -right-0.5 w-3 h-3 rounded-full border-2 border-card ${statusColor[device.status]}`} />
      </div>
      <span className="text-xs font-medium text-foreground/80 max-w-[80px] truncate">
        {device.name}
      </span>
    </motion.button>
  );
};

export default DeviceBubble;
