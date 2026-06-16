using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace MotionSick
{
    /// <summary>Programmatic WPF settings panel. Every control commits straight
    /// to <see cref="Settings.Shared"/>, which live-updates the overlay.</summary>
    public sealed class SettingsWindow : Window
    {
        private readonly Settings _s = Settings.Shared;

        public SettingsWindow()
        {
            Title = "MotionSick";
            Width = 420; Height = 720;
            WindowStartupLocation = WindowStartupLocation.CenterScreen;
            ResizeMode = ResizeMode.CanResize;

            var panel = new StackPanel { Margin = new Thickness(16) };

            panel.Children.Add(Header("MotionSick", 18));
            panel.Children.Add(Note("Peripheral motion cues to ease motion sickness.\n" +
                (NativeInput.AccelPresent ? "Hardware accelerometer detected ✓" : "No hardware accelerometer — using mouse/scroll cues.")));

            panel.Children.Add(Check("Show motion-cue overlay", _s.OverlayEnabled, v => { _s.OverlayEnabled = v; _s.Commit(); }));

            panel.Children.Add(Header("Motion mode", 13));
            panel.Children.Add(ModeCombo());

            panel.Children.Add(Header("Real-motion sources", 13));
            panel.Children.Add(Check(NativeInput.AccelPresent ? "Accelerometer ✓" : "Accelerometer (not found)",
                _s.SensorEnabled, v => { _s.SensorEnabled = v; _s.Commit(); }));
            panel.Children.Add(Check("React to scrolling", _s.ScrollEnabled, v => { _s.ScrollEnabled = v; _s.Commit(); }));
            panel.Children.Add(Check("Follow mouse pointer", _s.PointerEnabled, v => { _s.PointerEnabled = v; _s.Commit(); }));

            panel.Children.Add(Slider("Intensity", 0, 1, _s.Intensity, "How far the dots travel for a given motion.", v => { _s.Intensity = v; _s.Commit(); }));
            panel.Children.Add(Slider("Speed", 0, 1, _s.Speed, "Pace of the Calm drift and motion smoothing.", v => { _s.Speed = v; _s.Commit(); }));
            panel.Children.Add(Slider("Motion sensitivity", 0, 1, _s.SensorGain, "Amplifies the accelerometer / tilt signal.", v => { _s.SensorGain = v; _s.Commit(); }));
            panel.Children.Add(Slider("Dot size", 2, 20, _s.DotSize, "Diameter of each dot, in pixels.", v => { _s.DotSize = v; _s.Commit(); }));
            panel.Children.Add(Slider("Spacing", 24, 160, _s.Spacing, "Gap between dots along the edges.", v => { _s.Spacing = v; _s.Commit(); }));
            panel.Children.Add(Slider("Opacity", 0.05, 1, _s.Opacity, "How solid the dots appear.", v => { _s.Opacity = v; _s.Commit(); }));
            panel.Children.Add(Check("Fade & swell with motion (Apple-style)", _s.FadeWithMotion, v => { _s.FadeWithMotion = v; _s.Commit(); }));

            panel.Children.Add(Header("Active edges", 13));
            var edges = new WrapPanel();
            edges.Children.Add(Check("Top", _s.EdgeTop, v => { _s.EdgeTop = v; _s.Commit(); }));
            edges.Children.Add(Check("Bottom", _s.EdgeBottom, v => { _s.EdgeBottom = v; _s.Commit(); }));
            edges.Children.Add(Check("Left", _s.EdgeLeft, v => { _s.EdgeLeft = v; _s.Commit(); }));
            edges.Children.Add(Check("Right", _s.EdgeRight, v => { _s.EdgeRight = v; _s.Commit(); }));
            panel.Children.Add(edges);

            panel.Children.Add(Header("Dot colour", 13));
            panel.Children.Add(ColorRow());

            panel.Children.Add(Header("Comfort tint", 13));
            panel.Children.Add(Check("Warm screen wash", _s.TintEnabled, v => { _s.TintEnabled = v; _s.Commit(); }));
            panel.Children.Add(Slider("Tint opacity", 0, 0.4, _s.TintOpacity, "Strength of the warm wash.", v => { _s.TintOpacity = v; _s.Commit(); }));
            panel.Children.Add(Slider("Tint warmth", 0, 1, _s.TintWarmth, "Cool amber → deep warm red.", v => { _s.TintWarmth = v; _s.Commit(); }));

            var reset = new Button { Content = "Reset defaults", Margin = new Thickness(0, 12, 0, 0), Padding = new Thickness(8, 4, 8, 4) };
            reset.Click += (a, b) => { _s.ResetToDefaults(); Close(); var w = new SettingsWindow(); w.Show(); };
            panel.Children.Add(reset);

            Content = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Auto, Content = panel };
        }

        private UIElement ModeCombo()
        {
            var modes = new[] { "combo", "sensor", "calm", "reactive", "fixed" };
            var labels = new[] { "Combo (fuse all sources)", "Sensor (accelerometer)", "Calm (gentle horizon)", "Reactive (scroll/pointer)", "Fixed (still reference)" };
            var cb = new ComboBox { Margin = new Thickness(0, 2, 0, 6) };
            for (int i = 0; i < modes.Length; i++) cb.Items.Add(labels[i]);
            int idx = Array.IndexOf(modes, _s.Mode); cb.SelectedIndex = idx < 0 ? 0 : idx;
            cb.SelectionChanged += (a, b) => { if (cb.SelectedIndex >= 0) { _s.Mode = modes[cb.SelectedIndex]; _s.Commit(); } };
            return cb;
        }

        private UIElement ColorRow()
        {
            var row = new StackPanel { Orientation = Orientation.Horizontal };
            var swatch = new Border
            {
                Width = 40, Height = 24, CornerRadius = new CornerRadius(4),
                Background = new SolidColorBrush(Color.FromRgb((byte)_s.ColorR, (byte)_s.ColorG, (byte)_s.ColorB))
            };
            var pick = new Button { Content = "Pick colour…", Margin = new Thickness(10, 0, 0, 0), Padding = new Thickness(8, 2, 8, 2) };
            pick.Click += (a, b) =>
            {
                using (var dlg = new System.Windows.Forms.ColorDialog())
                {
                    dlg.Color = System.Drawing.Color.FromArgb(_s.ColorR, _s.ColorG, _s.ColorB);
                    if (dlg.ShowDialog() == System.Windows.Forms.DialogResult.OK)
                    {
                        _s.ColorR = dlg.Color.R; _s.ColorG = dlg.Color.G; _s.ColorB = dlg.Color.B; _s.Commit();
                        swatch.Background = new SolidColorBrush(Color.FromRgb(dlg.Color.R, dlg.Color.G, dlg.Color.B));
                    }
                }
            };
            row.Children.Add(swatch); row.Children.Add(pick);
            return row;
        }

        // ---- builders ----
        private static TextBlock Header(string t, double size)
            => new TextBlock { Text = t, FontWeight = FontWeights.Bold, FontSize = size, Margin = new Thickness(0, 10, 0, 4) };

        private static TextBlock Note(string t)
            => new TextBlock { Text = t, Foreground = Brushes.Gray, FontSize = 11, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 0, 0, 8) };

        private static CheckBox Check(string label, bool initial, Action<bool> set)
        {
            var c = new CheckBox { Content = label, IsChecked = initial, Margin = new Thickness(0, 3, 12, 3) };
            c.Checked += (a, b) => set(true);
            c.Unchecked += (a, b) => set(false);
            return c;
        }

        private static UIElement Slider(string label, double lo, double hi, double initial, string info, Action<double> set)
        {
            var box = new StackPanel { Margin = new Thickness(0, 4, 0, 2) };
            box.Children.Add(new TextBlock { Text = label, FontSize = 11 });
            var sl = new Slider { Minimum = lo, Maximum = hi, Value = initial, Width = 360, HorizontalAlignment = HorizontalAlignment.Left };
            sl.ValueChanged += (a, b) => set(sl.Value);
            box.Children.Add(sl);
            box.Children.Add(new TextBlock { Text = info, Foreground = Brushes.Gray, FontSize = 10, TextWrapping = TextWrapping.Wrap });
            return box;
        }
    }
}
