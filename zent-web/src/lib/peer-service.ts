import Peer, { DataConnection } from 'peerjs';

export type MessageType = 
  | 'device-info'
  | 'file-meta'
  | 'file-chunk'
  | 'file-complete'
  | 'file-ack'
  | 'file-pause'
  | 'file-resume'
  | 'file-cancel'
  | 'file-received-ack'
  | 'speed-update'
  | 'clipboard-sync'
  | 'ping';

export interface PeerMessage {
  type: MessageType;
  payload: any;
  timestamp: number;
}

export interface PeerDeviceInfo {
  peerId: string;
  name: string;
  type: 'phone' | 'laptop' | 'tablet' | 'desktop';
}

export interface FileMetaPayload {
  transferId: string;
  fileName: string;
  fileSize: number;
  fileType: string;
  totalChunks: number;
  chunkSize: number;
}

const CHUNK_SIZE = 256 * 1024;
const PARALLEL_CHUNKS = 8;

function detectDeviceType(): 'phone' | 'laptop' | 'tablet' | 'desktop' {
  const ua = navigator.userAgent.toLowerCase();
  if (/mobile|android|iphone/.test(ua)) return 'phone';
  if (/ipad|tablet/.test(ua)) return 'tablet';
  return 'laptop';
}

function generatePin(): string {
  const stored = localStorage.getItem('zent-peer-pin');
  if (stored) return stored;
  const pin = String(Math.floor(1000 + Math.random() * 9000));
  localStorage.setItem('zent-peer-pin', pin);
  return pin;
}

function pinToPeerId(pin: string): string {
  return `zent-pin-${pin}`;
}

export type ConnectionEventHandler = {
  onPeerConnected: (info: PeerDeviceInfo, conn: DataConnection) => void;
  onPeerDisconnected: (peerId: string) => void;
  onFileMeta: (peerId: string, meta: FileMetaPayload) => void;
  onFileChunk: (peerId: string, transferId: string, chunkIndex: number, data: ArrayBuffer) => void;
  onFileComplete: (peerId: string, transferId: string) => void;
  onFileReceivedAck: (transferId: string) => void;
  onClipboardSync: (peerId: string, content: string, clipType: string) => void;
  onTransferProgress: (transferId: string, progress: number, speed: number) => void;
  onTransferCancelled: (transferId: string) => void;
  onTransferPaused: (transferId: string) => void;
  onTransferResumed: (transferId: string) => void;
};

interface ActiveSend {
  file: File;
  transferId: string;
  peerId: string;
  paused: boolean;
  cancelled: boolean;
  currentChunk: number;
  totalChunks: number;
  onProgress: (progress: number, speed: number) => void;
  resolve: () => void;
  reject: (err: Error) => void;
  receiverSpeed: number; // speed reported by receiver
}

interface ReceiveBuffer {
  meta: FileMetaPayload;
  chunks: ArrayBuffer[];
  received: number;
  startTime: number;
  lastSpeedUpdate: number;
  bytesAtLastUpdate: number;
  paused: boolean;
  cancelled: boolean;
  senderPeerId: string;
}

export class ZentPeerService {
  private peer: Peer | null = null;
  private connections: Map<string, DataConnection> = new Map();
  private handlers: ConnectionEventHandler | null = null;
  private myInfo: PeerDeviceInfo;
  private myPin: string;
  private fileBuffers: Map<string, ReceiveBuffer> = new Map();
  private activeSends: Map<string, ActiveSend> = new Map();
  
  constructor() {
    const storedName = localStorage.getItem('zent-device-name') || 'My Device';
    this.myPin = generatePin();
    this.myInfo = {
      peerId: pinToPeerId(this.myPin),
      name: storedName,
      type: detectDeviceType(),
    };
  }

  get peerId() { return this.myPin; }
  get deviceName() { return this.myInfo.name; }
  
  setDeviceName(name: string) {
    this.myInfo.name = name;
    localStorage.setItem('zent-device-name', name);
    this.broadcast({ type: 'device-info', payload: this.myInfo, timestamp: Date.now() });
  }

  setHandlers(h: ConnectionEventHandler) {
    this.handlers = h;
  }

  async initialize(): Promise<string> {
    return new Promise((resolve, reject) => {
      this.peer = new Peer(this.myInfo.peerId, { debug: 1 });

      this.peer.on('open', (id) => {
        console.log('[Zent] Peer initialized with PIN:', this.myPin);
        this.myInfo.peerId = id;
        resolve(this.myPin);
      });

      this.peer.on('connection', (conn) => {
        this.setupConnection(conn);
      });

      this.peer.on('error', (err) => {
        console.error('[Zent] Peer error:', err);
        if (err.type === 'unavailable-id') {
          localStorage.removeItem('zent-peer-pin');
          this.myPin = generatePin();
          this.myInfo.peerId = pinToPeerId(this.myPin);
          this.initialize().then(resolve).catch(reject);
        } else {
          reject(err);
        }
      });
    });
  }

  connectToPeer(remotePin: string): Promise<DataConnection> {
    return new Promise((resolve, reject) => {
      if (!this.peer) return reject(new Error('Peer not initialized'));
      const remotePeerId = pinToPeerId(remotePin);
      if (this.connections.has(remotePeerId)) {
        return resolve(this.connections.get(remotePeerId)!);
      }
      const conn = this.peer.connect(remotePeerId, { reliable: true });
      conn.on('open', () => {
        this.setupConnection(conn);
        resolve(conn);
      });
      conn.on('error', reject);
    });
  }

  pinToPeerId(pin: string): string {
    return pinToPeerId(pin);
  }

  private setupConnection(conn: DataConnection) {
    const peerId = conn.peer;
    this.connections.set(peerId, conn);

    conn.on('open', () => {
      this.sendTo(peerId, { type: 'device-info', payload: this.myInfo, timestamp: Date.now() });
    });
    
    if (conn.open) {
      this.sendTo(peerId, { type: 'device-info', payload: this.myInfo, timestamp: Date.now() });
    }

    conn.on('data', (raw: any) => {
      this.handleMessage(peerId, raw);
    });

    conn.on('close', () => {
      this.connections.delete(peerId);
      this.handlers?.onPeerDisconnected(peerId);
    });

    conn.on('error', () => {
      this.connections.delete(peerId);
      this.handlers?.onPeerDisconnected(peerId);
    });
  }

  private handleMessage(peerId: string, raw: any) {
    const msg = raw as PeerMessage;
    if (!msg?.type) return;

    switch (msg.type) {
      case 'device-info': {
        const info = msg.payload as PeerDeviceInfo;
        const conn = this.connections.get(peerId);
        if (conn) this.handlers?.onPeerConnected(info, conn);
        break;
      }
      case 'file-meta': {
        const meta = msg.payload as FileMetaPayload;
        this.fileBuffers.set(meta.transferId, {
          meta,
          chunks: new Array(meta.totalChunks),
          received: 0,
          startTime: Date.now(),
          lastSpeedUpdate: Date.now(),
          bytesAtLastUpdate: 0,
          paused: false,
          cancelled: false,
          senderPeerId: peerId,
        });
        this.handlers?.onFileMeta(peerId, meta);
        this.sendTo(peerId, { type: 'file-ack', payload: { transferId: meta.transferId, ready: true }, timestamp: Date.now() });
        break;
      }
      case 'file-chunk': {
        const { transferId, chunkIndex, data } = msg.payload;
        const buf = this.fileBuffers.get(transferId);
        if (!buf || buf.cancelled || buf.paused) return; // Drop chunks if cancelled/paused
        buf.chunks[chunkIndex] = data;
        buf.received++;
        const progress = Math.round((buf.received / buf.meta.totalChunks) * 100);
        
        // Calculate receiver-side speed (source of truth)
        const now = Date.now();
        const elapsed = (now - buf.lastSpeedUpdate) / 1000;
        let speed = 0;
        if (elapsed >= 0.4) {
          const bytesReceived = (buf.received - buf.bytesAtLastUpdate / buf.meta.chunkSize) * buf.meta.chunkSize;
          const totalElapsed = (now - buf.startTime) / 1000;
          speed = totalElapsed > 0 ? (buf.received * buf.meta.chunkSize) / (1024 * 1024 * totalElapsed) : 0;
          buf.lastSpeedUpdate = now;
          buf.bytesAtLastUpdate = buf.received * buf.meta.chunkSize;
          
          // Send speed update to sender so both sides show same value
          this.sendTo(peerId, {
            type: 'speed-update',
            payload: { transferId, progress, speed },
            timestamp: now,
          });
        } else {
          const totalElapsed = (now - buf.startTime) / 1000;
          speed = totalElapsed > 0 ? (buf.received * buf.meta.chunkSize) / (1024 * 1024 * totalElapsed) : 0;
        }
        
        this.handlers?.onTransferProgress(transferId, progress, speed);
        this.handlers?.onFileChunk(peerId, transferId, chunkIndex, data);
        break;
      }
      case 'file-complete': {
        const { transferId } = msg.payload;
        const buf = this.fileBuffers.get(transferId);
        if (buf && !buf.cancelled) {
          this.handlers?.onFileComplete(peerId, transferId);
          const blob = new Blob(buf.chunks.filter(Boolean), { type: buf.meta.fileType || 'application/octet-stream' });
          const url = URL.createObjectURL(blob);
          const a = document.createElement('a');
          a.href = url;
          a.download = buf.meta.fileName;
          a.click();
          URL.revokeObjectURL(url);
          this.fileBuffers.delete(transferId);
          this.sendTo(peerId, { type: 'file-received-ack', payload: { transferId }, timestamp: Date.now() });
        }
        break;
      }
      case 'file-received-ack': {
        const { transferId } = msg.payload;
        this.handlers?.onFileReceivedAck(transferId);
        break;
      }
      case 'speed-update': {
        // Sender receives speed from receiver - use as source of truth
        const { transferId, progress, speed } = msg.payload;
        const send = this.activeSends.get(transferId);
        if (send) {
          send.receiverSpeed = speed;
          // Update sender UI with receiver's speed
          send.onProgress(progress, speed);
        }
        break;
      }
      case 'file-pause': {
        const { transferId } = msg.payload;
        // Receiver side: stop processing chunks
        const buf = this.fileBuffers.get(transferId);
        if (buf) buf.paused = true;
        // Sender side: pause sending
        const send = this.activeSends.get(transferId);
        if (send) send.paused = true;
        this.handlers?.onTransferPaused(transferId);
        break;
      }
      case 'file-resume': {
        const { transferId } = msg.payload;
        const buf = this.fileBuffers.get(transferId);
        if (buf) buf.paused = false;
        const send = this.activeSends.get(transferId);
        if (send) send.paused = false;
        this.handlers?.onTransferResumed(transferId);
        break;
      }
      case 'file-cancel': {
        const { transferId } = msg.payload;
        // Cancel on receiver side
        const buf = this.fileBuffers.get(transferId);
        if (buf) {
          buf.cancelled = true;
          this.fileBuffers.delete(transferId);
        }
        // Cancel on sender side
        const send = this.activeSends.get(transferId);
        if (send) {
          send.cancelled = true;
          this.activeSends.delete(transferId);
        }
        this.handlers?.onTransferCancelled(transferId);
        break;
      }
      case 'clipboard-sync': {
        const { content, clipType } = msg.payload;
        this.handlers?.onClipboardSync(peerId, content, clipType);
        break;
      }
    }
  }

  async sendFile(
    targetPeerId: string, 
    file: File, 
    transferId: string,
    onProgress: (progress: number, speed: number) => void
  ): Promise<void> {
    const conn = this.connections.get(targetPeerId);
    if (!conn) throw new Error('Not connected to peer');

    const totalChunks = Math.ceil(file.size / CHUNK_SIZE);
    const meta: FileMetaPayload = {
      transferId,
      fileName: file.name,
      fileSize: file.size,
      fileType: file.type,
      totalChunks,
      chunkSize: CHUNK_SIZE,
    };

    this.sendTo(targetPeerId, { type: 'file-meta', payload: meta, timestamp: Date.now() });
    await new Promise(r => setTimeout(r, 50));

    return new Promise<void>((resolve, reject) => {
      const activeSend: ActiveSend = {
        file,
        transferId,
        peerId: targetPeerId,
        paused: false,
        cancelled: false,
        currentChunk: 0,
        totalChunks,
        onProgress,
        resolve,
        reject,
        receiverSpeed: 0,
      };
      this.activeSends.set(transferId, activeSend);
      this.processChunks(activeSend);
    });
  }

  private async processChunks(send: ActiveSend) {
    const arrayBuffer = await send.file.arrayBuffer();

    while (send.currentChunk < send.totalChunks) {
      if (send.cancelled) {
        this.activeSends.delete(send.transferId);
        send.reject(new Error('Transfer cancelled'));
        return;
      }

      if (send.paused) {
        await new Promise<void>(r => {
          const check = setInterval(() => {
            if (!send.paused || send.cancelled) {
              clearInterval(check);
              r();
            }
          }, 100);
        });
        if (send.cancelled) {
          this.activeSends.delete(send.transferId);
          send.reject(new Error('Transfer cancelled'));
          return;
        }
      }

      const batchEnd = Math.min(send.currentChunk + PARALLEL_CHUNKS, send.totalChunks);
      
      for (let i = send.currentChunk; i < batchEnd; i++) {
        const start = i * CHUNK_SIZE;
        const end = Math.min(start + CHUNK_SIZE, send.file.size);
        const chunk = arrayBuffer.slice(start, end);

        this.sendTo(send.peerId, {
          type: 'file-chunk',
          payload: { transferId: send.transferId, chunkIndex: i, data: chunk },
          timestamp: Date.now(),
        });
      }

      send.currentChunk = batchEnd;
      
      // Don't calculate speed here - wait for receiver's speed-update messages
      // Only update progress locally for immediate feedback
      const progress = Math.round((send.currentChunk / send.totalChunks) * 100);
      // Use receiver speed if available, otherwise show 0
      send.onProgress(progress, send.receiverSpeed);

      await new Promise(r => setTimeout(r, 1));
    }

    this.sendTo(send.peerId, {
      type: 'file-complete',
      payload: { transferId: send.transferId },
      timestamp: Date.now(),
    });

    setTimeout(() => {
      if (this.activeSends.has(send.transferId)) {
        this.activeSends.delete(send.transferId);
        send.resolve();
      }
    }, 10000);
  }

  completeTransfer(transferId: string) {
    const send = this.activeSends.get(transferId);
    if (send) {
      this.activeSends.delete(transferId);
      send.resolve();
    }
  }

  pauseTransfer(transferId: string) {
    const send = this.activeSends.get(transferId);
    if (send) {
      send.paused = true;
      // Notify receiver to pause
      this.sendTo(send.peerId, { type: 'file-pause', payload: { transferId }, timestamp: Date.now() });
    }
    // If called from receiver side, notify sender
    const buf = this.fileBuffers.get(transferId);
    if (buf) {
      buf.paused = true;
      this.sendTo(buf.senderPeerId, { type: 'file-pause', payload: { transferId }, timestamp: Date.now() });
    }
  }

  resumeTransfer(transferId: string) {
    const send = this.activeSends.get(transferId);
    if (send) {
      send.paused = false;
      this.sendTo(send.peerId, { type: 'file-resume', payload: { transferId }, timestamp: Date.now() });
    }
    const buf = this.fileBuffers.get(transferId);
    if (buf) {
      buf.paused = false;
      this.sendTo(buf.senderPeerId, { type: 'file-resume', payload: { transferId }, timestamp: Date.now() });
    }
  }

  cancelTransfer(transferId: string, senderPeerId?: string) {
    const send = this.activeSends.get(transferId);
    if (send) {
      send.cancelled = true;
      this.sendTo(send.peerId, { type: 'file-cancel', payload: { transferId }, timestamp: Date.now() });
      this.activeSends.delete(transferId);
    }
    const buf = this.fileBuffers.get(transferId);
    if (buf) {
      buf.cancelled = true;
      this.sendTo(buf.senderPeerId, { type: 'file-cancel', payload: { transferId }, timestamp: Date.now() });
      this.fileBuffers.delete(transferId);
    }
    // Fallback: if we only have the peerId
    if (!send && !buf && senderPeerId) {
      this.sendTo(senderPeerId, { type: 'file-cancel', payload: { transferId }, timestamp: Date.now() });
    }
  }

  syncClipboard(content: string, clipType: string) {
    this.broadcast({
      type: 'clipboard-sync',
      payload: { content, clipType },
      timestamp: Date.now(),
    });
  }

  private sendTo(peerId: string, msg: PeerMessage) {
    const conn = this.connections.get(peerId);
    if (conn?.open) {
      conn.send(msg);
    }
  }

  private broadcast(msg: PeerMessage) {
    this.connections.forEach((conn) => {
      if (conn.open) conn.send(msg);
    });
  }

  getConnectedPeerIds(): string[] {
    return Array.from(this.connections.keys());
  }

  isConnected(peerId: string): boolean {
    return this.connections.has(peerId) && (this.connections.get(peerId)?.open ?? false);
  }

  disconnect(peerId: string) {
    const conn = this.connections.get(peerId);
    if (conn) {
      conn.close();
      this.connections.delete(peerId);
    }
  }

  destroy() {
    this.connections.forEach(c => c.close());
    this.connections.clear();
    this.activeSends.clear();
    this.peer?.destroy();
    this.peer = null;
  }
}

let instance: ZentPeerService | null = null;
export function getPeerService(): ZentPeerService {
  if (!instance) instance = new ZentPeerService();
  return instance;
}
