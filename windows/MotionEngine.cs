using System;

namespace MotionSick
{
    /// <summary>
    /// Shared physics: converts the chosen motion sources into a smoothly
    /// gliding offset with spring momentum, plus a 0..1 "motion level" used for
    /// the Apple-style fade/swell. Mirrors the macOS engine.
    /// </summary>
    public static class MotionEngine
    {
        public static double OffsetX { get; private set; }
        public static double OffsetY { get; private set; }
        public static double MotionLevel { get; private set; }

        private static double _phase;
        private static double _lastX, _lastY;
        private static double _accelBaseX, _accelBaseY;
        private static bool _haveBase;

        public static void Calibrate()
        {
            var a = NativeInput.ReadAccel();
            if (a.HasValue) { _accelBaseX = a.Value.x; _accelBaseY = a.Value.y; _haveBase = true; }
        }

        public static void Tick()
        {
            var s = Settings.Shared;
            _phase += 0.012 + s.Speed * 0.09;
            double gain = 0.4 + s.Intensity * 1.8;

            switch (s.Mode)
            {
                case "fixed":
                    OffsetX *= 0.8; OffsetY *= 0.8;
                    break;

                case "calm":
                {
                    double amp = gain * 22;
                    double tx = Math.Cos(_phase) * amp;
                    double ty = Math.Sin(_phase * 0.85) * amp * 0.6;
                    OffsetX += (tx - OffsetX) * 0.08;
                    OffsetY += (ty - OffsetY) * 0.08;
                    break;
                }

                case "sensor":
                    DriveSensorOrFallback(s, gain, sensorOnly: true);
                    break;

                case "reactive":
                {
                    var p = NativeInput.ConsumePointer();
                    DriveVelocity(p.x * gain, p.y * gain);
                    break;
                }

                default: // combo
                    DriveSensorOrFallback(s, gain, sensorOnly: false);
                    break;
            }

            OffsetX = Clamp(OffsetX, -130, 130);
            OffsetY = Clamp(OffsetY, -130, 130);

            double dx = OffsetX - _lastX, dy = OffsetY - _lastY;
            _lastX = OffsetX; _lastY = OffsetY;
            double speedMag = Math.Sqrt(dx * dx + dy * dy);
            double dispMag = Math.Sqrt(OffsetX * OffsetX + OffsetY * OffsetY) / 130.0;
            double raw = Math.Min(1, speedMag * 0.22 + dispMag * 0.85);
            MotionLevel = MotionLevel * 0.85 + raw * 0.15;
        }

        private static void DriveSensorOrFallback(Settings s, double gain, bool sensorOnly)
        {
            var a = (s.SensorEnabled) ? NativeInput.ReadAccel() : null;
            if (a.HasValue)
            {
                if (!_haveBase) { _accelBaseX = a.Value.x; _accelBaseY = a.Value.y; _haveBase = true; }
                // Gravity tilt relative to the calibrated rest pose → a 30° tilt
                // holds a steady offset; lateral vehicle g shifts it live.
                double g = s.SensorGain * 240;
                double tx = Clamp(-(a.Value.x - _accelBaseX) * g, -110, 110);
                double ty = Clamp((a.Value.y - _accelBaseY) * g, -110, 110);
                OffsetX += (tx - OffsetX) * 0.16;
                OffsetY += (ty - OffsetY) * 0.16;

                // In combo, scroll/pointer still nudge the field on top of tilt.
                if (!sensorOnly)
                {
                    var p = NativeInput.ConsumePointer();
                    OffsetX += p.x * gain * 0.5;
                    OffsetY += p.y * gain * 0.5;
                }
            }
            else
            {
                var p = NativeInput.ConsumePointer();
                DriveVelocity(p.x * gain, p.y * gain);
            }
        }

        private static void DriveVelocity(double vx, double vy)
        {
            OffsetX += vx; OffsetY += vy;
            const double spring = 0.08;
            OffsetX -= OffsetX * spring;
            OffsetY -= OffsetY * spring;
        }

        private static double Clamp(double v, double lo, double hi)
            => v < lo ? lo : (v > hi ? hi : v);
    }
}
