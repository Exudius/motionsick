using System;
using System.Runtime.InteropServices;
using Windows.Devices.Sensors;

namespace MotionSick
{
    /// <summary>
    /// Real motion inputs on Windows:
    ///  • the hardware accelerometer (Windows.Devices.Sensors) — gives the gravity
    ///    vector, so a physical tilt is sensed directly and steady vehicle motion
    ///    too; this is the proper source for "tilt 30° → dots reflect it";
    ///  • global mouse move + wheel via a low-level hook, as a decaying velocity.
    /// Every entry point is wrapped so a missing sensor or hook never crashes.
    /// </summary>
    public static class NativeInput
    {
        private static readonly object Gate = new object();
        private static double _vx, _vy;
        private static int _lastX, _lastY;
        private static bool _haveLast;

        private static Accelerometer _accel;
        public static bool AccelPresent { get; private set; }

        // Keep the delegate alive for the lifetime of the process.
        private static LowLevelMouseProc _proc = HookCallback;
        private static IntPtr _hook = IntPtr.Zero;

        public static void Init()
        {
            try { _accel = Accelerometer.GetDefault(); AccelPresent = _accel != null; }
            catch { _accel = null; AccelPresent = false; }

            try
            {
                _hook = SetWindowsHookEx(WH_MOUSE_LL, _proc, GetModuleHandle(null), 0);
            }
            catch { _hook = IntPtr.Zero; }
        }

        /// <summary>Accelerometer reading in g (X,Y,Z), or null if unavailable.</summary>
        public static (double x, double y, double z)? ReadAccel()
        {
            if (_accel == null) return null;
            try
            {
                var r = _accel.GetCurrentReading();
                if (r == null) return null;
                return (r.AccelerationX, r.AccelerationY, r.AccelerationZ);
            }
            catch { return null; }
        }

        /// <summary>Mouse/scroll velocity since the last call, then decay it.</summary>
        public static (double x, double y) ConsumePointer()
        {
            lock (Gate)
            {
                var r = (_vx, _vy);
                _vx *= 0.85; _vy *= 0.85;
                return r;
            }
        }

        private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
        {
            try
            {
                if (nCode >= 0)
                {
                    int msg = (int)wParam;
                    var data = Marshal.PtrToStructure<MSLLHOOKSTRUCT>(lParam);
                    if (msg == WM_MOUSEMOVE)
                    {
                        if (_haveLast && Settings.Shared.PointerEnabled)
                        {
                            double dx = data.pt.x - _lastX;
                            double dy = data.pt.y - _lastY;
                            lock (Gate) { _vx += dx * 0.04; _vy += -dy * 0.04; }
                        }
                        _lastX = data.pt.x; _lastY = data.pt.y; _haveLast = true;
                    }
                    else if (msg == WM_MOUSEWHEEL && Settings.Shared.ScrollEnabled)
                    {
                        short delta = (short)((data.mouseData >> 16) & 0xffff);
                        lock (Gate) { _vy += delta * 0.01; }
                    }
                    else if (msg == WM_MOUSEHWHEEL && Settings.Shared.ScrollEnabled)
                    {
                        short delta = (short)((data.mouseData >> 16) & 0xffff);
                        lock (Gate) { _vx += delta * 0.01; }
                    }
                }
            }
            catch { /* never let a hook exception escape */ }
            return CallNextHookEx(_hook, nCode, wParam, lParam);
        }

        // ---- P/Invoke ----
        private const int WH_MOUSE_LL = 14;
        private const int WM_MOUSEMOVE = 0x0200;
        private const int WM_MOUSEWHEEL = 0x020A;
        private const int WM_MOUSEHWHEEL = 0x020E;

        private delegate IntPtr LowLevelMouseProc(int nCode, IntPtr wParam, IntPtr lParam);

        [StructLayout(LayoutKind.Sequential)]
        private struct POINT { public int x; public int y; }

        [StructLayout(LayoutKind.Sequential)]
        private struct MSLLHOOKSTRUCT
        {
            public POINT pt;
            public uint mouseData;
            public uint flags;
            public uint time;
            public IntPtr dwExtraInfo;
        }

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelMouseProc lpfn, IntPtr hMod, uint dwThreadId);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr GetModuleHandle(string lpModuleName);
    }
}
