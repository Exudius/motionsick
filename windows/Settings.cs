using System;
using System.IO;
using System.Text.Json;

namespace MotionSick
{
    /// <summary>
    /// App settings, persisted as JSON in %APPDATA%\MotionSick\settings.json.
    /// Raising <see cref="Changed"/> lets the overlay live-update without restart.
    /// All access is defensive so a corrupt file can never crash the app.
    /// </summary>
    public sealed class Settings
    {
        public static readonly Settings Shared = Load();
        public event Action Changed;

        // mode: "combo" | "sensor" | "calm" | "reactive" | "fixed"
        public string Mode { get; set; } = "combo";
        public bool OverlayEnabled { get; set; } = true;

        public double Intensity { get; set; } = 0.75;
        public double Speed { get; set; } = 0.5;
        public double SensorGain { get; set; } = 0.7;
        public double DotSize { get; set; } = 9.0;
        public double Spacing { get; set; } = 74.0;
        public double Opacity { get; set; } = 0.7;

        public bool EdgeTop { get; set; } = true;
        public bool EdgeBottom { get; set; } = true;
        public bool EdgeLeft { get; set; } = true;
        public bool EdgeRight { get; set; } = true;

        public bool SensorEnabled { get; set; } = true;   // real accelerometer
        public bool ScrollEnabled { get; set; } = true;
        public bool PointerEnabled { get; set; } = true;
        public bool FadeWithMotion { get; set; } = true;

        // dot colour (sRGB 0..255)
        public int ColorR { get; set; } = 255;
        public int ColorG { get; set; } = 204;
        public int ColorB { get; set; } = 107;

        public bool TintEnabled { get; set; } = false;
        public double TintOpacity { get; set; } = 0.10;
        public double TintWarmth { get; set; } = 0.6;

        private static string PathOnDisk()
        {
            string dir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "MotionSick");
            Directory.CreateDirectory(dir);
            return Path.Combine(dir, "settings.json");
        }

        private static Settings Load()
        {
            try
            {
                string p = PathOnDisk();
                if (File.Exists(p))
                {
                    var s = JsonSerializer.Deserialize<Settings>(File.ReadAllText(p));
                    if (s != null) return s;
                }
            }
            catch { /* fall through to defaults */ }
            return new Settings();
        }

        public void Save()
        {
            try
            {
                File.WriteAllText(PathOnDisk(),
                    JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
            }
            catch { /* non-fatal */ }
        }

        /// <summary>Persist and notify listeners. Call after any mutation.</summary>
        public void Commit()
        {
            Save();
            try { Changed?.Invoke(); } catch { }
        }

        public void ResetToDefaults()
        {
            var d = new Settings();
            Mode = d.Mode; OverlayEnabled = d.OverlayEnabled;
            Intensity = d.Intensity; Speed = d.Speed; SensorGain = d.SensorGain;
            DotSize = d.DotSize; Spacing = d.Spacing; Opacity = d.Opacity;
            EdgeTop = d.EdgeTop; EdgeBottom = d.EdgeBottom; EdgeLeft = d.EdgeLeft; EdgeRight = d.EdgeRight;
            SensorEnabled = d.SensorEnabled; ScrollEnabled = d.ScrollEnabled;
            PointerEnabled = d.PointerEnabled; FadeWithMotion = d.FadeWithMotion;
            ColorR = d.ColorR; ColorG = d.ColorG; ColorB = d.ColorB;
            TintEnabled = d.TintEnabled; TintOpacity = d.TintOpacity; TintWarmth = d.TintWarmth;
            Commit();
        }
    }
}
