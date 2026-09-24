'use strict';

// Godot policy 0 leaves sizing to the host. The canvas must follow its
// container, which can be narrower than the browser window on desktop.
class GameViewport {
  constructor(canvas, container) {
    this.canvas = canvas;
    this.container = container;
    this.resize = () => this.sync();
    this.densityChanged = () => {
      this.watchDensity();
      this.sync();
    };
    this.observer = new ResizeObserver(this.resize);
    this.observer.observe(container);
    window.addEventListener('resize', this.resize);
    window.addEventListener('pageshow', this.resize);
    window.visualViewport?.addEventListener('resize', this.resize);
    this.watchDensity();
    this.sync();
  }

  sync() {
    const width = this.container.clientWidth;
    const height = this.container.clientHeight;
    // A temporarily hidden host must not erase the WebGL drawing buffer.
    if (!width || !height) return;
    const ratio = window.devicePixelRatio || 1;
    const pixelsWide = Math.max(1, Math.round(width * ratio));
    const pixelsHigh = Math.max(1, Math.round(height * ratio));
    // Assigning even the same dimensions clears a canvas. Resize only on change.
    if (this.canvas.width !== pixelsWide) this.canvas.width = pixelsWide;
    if (this.canvas.height !== pixelsHigh) this.canvas.height = pixelsHigh;
  }

  watchDensity() {
    this.densityQuery?.removeEventListener('change', this.densityChanged);
    this.densityQuery = window.matchMedia(`(resolution: ${window.devicePixelRatio || 1}dppx)`);
    this.densityQuery.addEventListener('change', this.densityChanged);
  }

  destroy() {
    this.observer.disconnect();
    window.removeEventListener('resize', this.resize);
    window.removeEventListener('pageshow', this.resize);
    window.visualViewport?.removeEventListener('resize', this.resize);
    this.densityQuery.removeEventListener('change', this.densityChanged);
  }
}
