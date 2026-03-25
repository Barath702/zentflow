import { memo } from 'react';
import { motion } from 'framer-motion';
import { Activity } from 'lucide-react';
import { SpeedDataPoint } from '@/context/ZentContext';

const SpeedGraph = memo(({ data }: { data: SpeedDataPoint[] }) => {
  if (data.length < 2) return null;

  const maxSpeed = Math.max(...data.map(d => d.speed), 0.1);
  const currentSpeed = data[data.length - 1]?.speed || 0;
  const height = 80;
  const width = 100; // percentage-based

  // Build SVG path
  const points = data.map((d, i) => {
    const x = (i / (data.length - 1)) * 100;
    const y = height - (d.speed / maxSpeed) * (height - 10);
    return `${x},${y}`;
  });
  const linePath = `M ${points.join(' L ')}`;
  const areaPath = `${linePath} L 100,${height} L 0,${height} Z`;

  return (
    <motion.div
      initial={{ opacity: 0, y: -10 }}
      animate={{ opacity: 1, y: 0 }}
      className="glass rounded-2xl p-3 relative overflow-hidden"
    >
      <div className="flex items-center justify-between mb-2">
        <div className="flex items-center gap-2">
          <Activity className="w-4 h-4 text-primary" />
          <span className="text-xs font-medium text-foreground">Transfer Speed</span>
        </div>
        <div className="flex items-baseline gap-1">
          <span className="text-lg font-bold gradient-text">{currentSpeed.toFixed(1)}</span>
          <span className="text-[10px] text-muted-foreground">MB/s</span>
        </div>
      </div>
      <svg
        viewBox={`0 0 100 ${height}`}
        className="w-full"
        style={{ height: 60 }}
        preserveAspectRatio="none"
      >
        <defs>
          <linearGradient id="speedGrad" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="hsl(262 83% 58%)" stopOpacity="0.4" />
            <stop offset="100%" stopColor="hsl(262 83% 58%)" stopOpacity="0.02" />
          </linearGradient>
        </defs>
        <path d={areaPath} fill="url(#speedGrad)" />
        <path d={linePath} fill="none" stroke="hsl(262 83% 58%)" strokeWidth="1.5" vectorEffect="non-scaling-stroke" />
      </svg>
      <div className="flex justify-between mt-1">
        <span className="text-[9px] text-muted-foreground">Peak: {maxSpeed.toFixed(1)} MB/s</span>
        <span className="text-[9px] text-muted-foreground">{data.length} samples</span>
      </div>
    </motion.div>
  );
});
SpeedGraph.displayName = 'SpeedGraph';

export default SpeedGraph;
