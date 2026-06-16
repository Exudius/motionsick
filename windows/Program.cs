using System;
using System.Drawing;
using System.Windows;
using System.Windows.Forms; // NotifyIcon (tray)

namespace MotionSick
{
    /// <summary>
    /// Entry point. Runs as a tray app (no taskbar window), owns the overlay,
    /// and wires the system-tray menu. Wrapped so startup can never hard-crash.
    /// </summary>
    public static class Program
    {
        private static OverlayWindow _overlay;
        private static NotifyIcon _tray;
        private static SettingsWindow _settings;

        [STAThread]
        public static void Main()
        {
            try
            {
                var app = new System.Windows.Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };

                NativeInput.Init();
                MotionEngine.Calibrate();

                _overlay = new OverlayWindow();
                _overlay.Show();        // OnSourceInitialized applies enabled state
                _overlay.ApplyEnabled();

                Settings.Shared.Changed += () =>
                {
                    try { _overlay?.ApplyEnabled(); UpdateTray(); } catch { }
                };

                BuildTray();
                app.Run();
            }
            catch (Exception ex)
            {
                System.Windows.MessageBox.Show("MotionSick failed to start:\n" + ex.Message,
                    "MotionSick", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private static void BuildTray()
        {
            Icon trayIcon = SystemIcons.Application;
            try
            {
                string exe = System.Diagnostics.Process.GetCurrentProcess().MainModule?.FileName;
                if (!string.IsNullOrEmpty(exe))
                {
                    var extracted = Icon.ExtractAssociatedIcon(exe);
                    if (extracted != null) trayIcon = extracted;
                }
            }
            catch { }

            _tray = new NotifyIcon
            {
                Icon = trayIcon,
                Visible = true,
                Text = "MotionSick"
            };
            UpdateTray();
        }

        private static void UpdateTray()
        {
            if (_tray == null) return;
            var menu = new ContextMenuStrip();

            var toggle = new ToolStripMenuItem("Show overlay")
            {
                Checked = Settings.Shared.OverlayEnabled,
                CheckOnClick = false
            };
            toggle.Click += (s, e) => { Settings.Shared.OverlayEnabled = !Settings.Shared.OverlayEnabled; Settings.Shared.Commit(); };
            menu.Items.Add(toggle);

            menu.Items.Add(new ToolStripMenuItem(
                NativeInput.AccelPresent ? "Source: accelerometer + mouse" : "Source: mouse / scroll") { Enabled = false });

            menu.Items.Add(new ToolStripSeparator());

            var settings = new ToolStripMenuItem("Settings…");
            settings.Click += (s, e) => OpenSettings();
            menu.Items.Add(settings);

            var calibrate = new ToolStripMenuItem("Calibrate (zero tilt)");
            calibrate.Click += (s, e) => MotionEngine.Calibrate();
            menu.Items.Add(calibrate);

            var quit = new ToolStripMenuItem("Quit MotionSick");
            quit.Click += (s, e) => { try { _tray.Visible = false; } catch { } System.Windows.Application.Current.Shutdown(); };
            menu.Items.Add(quit);

            _tray.ContextMenuStrip = menu;
        }

        private static void OpenSettings()
        {
            try
            {
                if (_settings != null) { _settings.Close(); _settings = null; }
                _settings = new SettingsWindow();
                _settings.Closed += (s, e) => _settings = null;
                _settings.Show();
                _settings.Activate();
            }
            catch { }
        }
    }
}
