class SessionPreset {
  
    /**
     * @param  {String} name SessionPresetName, must match native one
     * @param  {number} width
     * @param  {number} height
     */
    constructor(name, width, height) {
        this.name = name;
        this.height = height;
        this.width = width;
      }
};

const DictSessionPreset = {
  hd1280x720: new SessionPreset('hd1280x720', 1280, 720),
  hd1920x1080: new SessionPreset('hd1920x1080', 1920, 1080),
  hd4K3840x2160: new SessionPreset('hd4K3840x2160', 3840, 2160),
  iFrame960x540: new SessionPreset('iFrame960x540', 960, 540),
  vga640x480: new SessionPreset('vga640x480', 640, 480),
  cif352x288: new SessionPreset('cif352x288', 352, 288),
};