using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Threading;

namespace MotionSick
{
    /// <summary>
    /// Full-screen transparent, click-through, top-most overlay that paints the
    /// peripheral cue dots. A 60 Hz timer steps the engine and repaints.
    /// </summary>
    public sealed class OverlayWindow : Window
    {
        private readonly DispatcherTimer _timer;

        public OverlayWindow()
        {
            WindowStyle = WindowStyle.None;
            AllowsTransparency = true;
            Background = Brushes.Transparent;
            ShowInTaskbar = false;
            Topmost = true;
            ResizeMode = ResizeMode.NoResize;
            IsHitTestVisible = false;
            Focusable = false;

            // Cover the whole virtual desktop (all monitors).
            Left = SystemParameters.VirtualScreenLeft;
            Top = SystemParameters.VirtualScreenTop;
            Width = SystemParameters.VirtualScreenWidth;
            Height = SystemParameters.VirtualScreenHeight;

            _timer = new DispatcherTimer(DispatcherPriority.Render)
            {
                Interval = TimeSpan.FromMilliseconds(1000.0 / 60.0)
            };
            _timer.Tick += (s, e) => { MotionEngine.Tick(); InvalidateVisual(); };
        }

        protected override void OnSourceInitialized(EventArgs e)
        {
            base.OnSourceInitialized(e);
            var helper = new WindowInteropHelper(this);
            int ex = GetWindowLong(helper.Handle, GWL_EXSTYLE);
            // Layered + transparent (click-through) + tool window (no alt-tab).
            SetWindowLong(helper.Handle, GWL_EXSTYLE,
                ex | WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE);
            ApplyEnabled();
        }

        public void ApplyEnabled()
        {
            if (Settings.Shared.OverlayEnabled)
            {
                if (!IsVisible) Show();
                if (!_timer.IsEnabled) _timer.Start();
            }
            else
            {
                _timer.Stop();
                if (IsVisible) Hide();
            }
        }

        protected override void OnRender(DrawingContext dc)
        {
            base.OnRender(dc);
            var s = Settings.Shared;
            double w = ActualWidth, h = ActualHeight;
            if (w <= 0 || h <= 0) return;

            if (s.TintEnabled)
            {
                double warmth = s.TintWarmth;
                var tint = Color.FromScRgb((float)s.TintOpacity,
                    (float)(0.9 + 0.1 * warmth),
                    (float)(0.55 + 0.25 * (1 - warmth)),
                    (float)(0.35 + 0.45 * (1 - warmth)));
                dc.DrawRectangle(new SolidColorBrush(tint), null, new Rect(0, 0, w, h));
            }

            double level = MotionEngine.MotionLevel;
            double opacityScale = s.FadeWithMotion ? (0.32 + 0.68 * Math.Min(1, level)) : 1.0;
            double sizeScale = s.FadeWithMotion ? (0.85 + 0.30 * Math.Min(1, level)) : 1.0;

            byte a = (byte)Math.Max(0, Math.Min(255, s.Opacity * opacityScale * 255));
            var brush = new SolidColorBrush(Color.FromArgb(a, (byte)s.ColorR, (byte)s.ColorG, (byte)s.ColorB));
            brush.Freeze();

            double size = Math.Max(2, s.DotSize) * sizeScale;
            double r = size / 2.0;
            double spacing = Math.Max(18, s.Spacing);
            double margin = 26;
            double ox = MotionEngine.OffsetX, oy = -MotionEngine.OffsetY; // screen Y is top-down

            var pts = new List<Point>();
            for (double x = margin; x <= w - margin; x += spacing)
            {
                if (s.EdgeTop) pts.Add(new Point(x, margin));
                if (s.EdgeBottom) pts.Add(new Point(x, h - margin));
            }
            for (double y = margin; y <= h - margin; y += spacing)
            {
                if (s.EdgeLeft) pts.Add(new Point(margin, y));
                if (s.EdgeRight) pts.Add(new Point(w - margin, y));
            }

            foreach (var p in pts)
                dc.DrawEllipse(brush, null, new Point(p.X + ox, p.Y + oy), r, r);
        }

        // ---- P/Invoke ----
        private const int GWL_EXSTYLE = -20;
        private const int WS_EX_LAYERED = 0x80000;
        private const int WS_EX_TRANSPARENT = 0x20;
        private const int WS_EX_TOOLWINDOW = 0x80;
        private const int WS_EX_NOACTIVATE = 0x08000000;

        [DllImport("user32.dll")] private static extern int GetWindowLong(IntPtr hWnd, int nIndex);
        [DllImport("user32.dll")] private static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
    }
}
