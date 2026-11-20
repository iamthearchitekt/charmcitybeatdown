using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Threading;
using Microsoft.Win32;

internal static class InstallFiles
{
    internal const string Game = "Charm City Beatdown";
    internal const string Publisher = "BSOD Interactive";
    internal const string Exe = "CharmCityBeatdown.exe";
    internal const string Pack = "CharmCityBeatdown.pck";
    internal const string Uninstall = "Uninstall.exe";
    internal const string OwnerFile = ".ccbd-install";
    internal const string Owner = "BSOD Interactive / Charm City Beatdown";
    internal const string RegistryPath = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\BSODInteractive.CharmCityBeatdown";
    private static readonly string[] Files = { Exe, Pack, Uninstall, OwnerFile };

    internal static string InstalledFolder()
    {
        using (var entry = Registry.CurrentUser.OpenSubKey(RegistryPath))
            return entry == null ? null : entry.GetValue("InstallLocation") as string;
    }

    internal static string DefaultFolder()
    {
        return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", Game);
    }

    internal static bool OwnsFolder(string folder)
    {
        var marker = Path.Combine(folder, OwnerFile);
        return File.Exists(marker) && File.ReadAllText(marker) == Owner;
    }

    internal static void Install(string folder, string programs, string desktop, bool register, Action<int> progress)
    {
        folder = Path.GetFullPath(folder);
        using (var gate = new Mutex(false, @"Local\BSODInteractive.CharmCityBeatdown.Setup"))
        {
            bool entered;
            try { entered = gate.WaitOne(0); }
            catch (AbandonedMutexException) { entered = true; }
            if (!entered) throw new IOException("Another setup is already running.");
            try { InstallCore(folder, programs, desktop, register, progress); }
            finally { gate.ReleaseMutex(); }
        }
    }

    private static void InstallCore(string folder, string programs, string desktop, bool register, Action<int> progress)
    {
        Directory.CreateDirectory(folder);
        if (!OwnsFolder(folder))
        {
            foreach (string name in Files)
                if (File.Exists(Path.Combine(folder, name)))
                    throw new IOException("This folder contains another copy of the game. Choose a new folder.");
        }
        var id = Guid.NewGuid().ToString("N");
        var staging = Path.Combine(folder, ".setup-" + id);
        var backups = new List<string>();
        var installed = new List<string>();
        Directory.CreateDirectory(staging);
        bool complete = false;
        try
        {
            Extract(staging, progress);
            File.WriteAllText(Path.Combine(staging, OwnerFile), Owner);
            EnsureGameClosed(folder);
            foreach (var name in Files)
            {
                var current = Path.Combine(folder, name);
                if (!File.Exists(current)) continue;
                File.Move(current, BackupPath(staging, name));
                backups.Add(name);
            }
            foreach (var name in new[] { Pack, Uninstall, OwnerFile, Exe })
            {
                File.Move(Path.Combine(staging, name), Path.Combine(folder, name));
                installed.Add(name);
            }
            complete = true;
        }
        catch (Exception error)
        {
            foreach (var name in installed) File.Delete(Path.Combine(folder, name));
            foreach (var name in backups) File.Move(BackupPath(staging, name), Path.Combine(folder, name));
            throw new IOException("Setup could not replace the game files. Close the game if it is running. " + error.Message, error);
        }
        finally
        {
            foreach (var name in Files) File.Delete(Path.Combine(staging, name));
            if (complete)
                foreach (var name in backups) File.Delete(BackupPath(staging, name));
            if (Directory.GetFileSystemEntries(staging).Length == 0) Directory.Delete(staging);
        }
        var gamePath = Path.Combine(folder, Exe);
        if (register) Register(folder);
        if (!String.IsNullOrEmpty(programs)) WriteShortcut(programs, gamePath);
        if (!String.IsNullOrEmpty(desktop)) WriteShortcut(desktop, gamePath);
        if (progress != null) progress(100);
    }

    internal static void EnsureGameClosed(string folder)
    {
        var exe = Path.Combine(folder, Exe);
        if (File.Exists(exe))
            using (File.Open(exe, FileMode.Open, FileAccess.ReadWrite, FileShare.None)) { }
    }

    private static string BackupPath(string staging, string name)
    {
        return Path.Combine(staging, name + ".previous");
    }

    private static void Extract(string staging, Action<int> progress)
    {
        var resources = Assembly.GetExecutingAssembly();
        using (var payload = resources.GetManifestResourceStream("Game.zip"))
        using (var zip = new ZipArchive(payload, ZipArchiveMode.Read))
        {
            var exe = zip.GetEntry(Exe);
            var pack = zip.GetEntry(Pack);
            if (zip.Entries.Count != 2 || exe == null || pack == null)
                throw new InvalidDataException("The Windows game payload is incomplete.");
            long total = exe.Length + pack.Length;
            long copied = 0;
            var buffer = new byte[1024 * 1024];
            int lastPercent = -1;
            foreach (var entry in new[] { exe, pack })
            {
                var destination = Path.Combine(staging, entry.Name);
                using (var input = entry.Open())
                using (var output = File.Open(destination, FileMode.CreateNew, FileAccess.Write))
                {
                    int size;
                    while ((size = input.Read(buffer, 0, buffer.Length)) > 0)
                    {
                        output.Write(buffer, 0, size);
                        copied += size;
                        int percent = (int)(94L * copied / total);
                        if (progress != null && percent != lastPercent) progress(percent);
                        lastPercent = percent;
                    }
                    if (output.Length != entry.Length) throw new InvalidDataException("An installed game file was incomplete.");
                }
            }
        }
        using (var input = resources.GetManifestResourceStream("Uninstall.exe"))
        using (var output = File.Open(Path.Combine(staging, Uninstall), FileMode.CreateNew, FileAccess.Write))
            input.CopyTo(output);
    }

    internal static void WriteShortcut(string directory, string target)
    {
        Directory.CreateDirectory(directory);
        dynamic shell = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell"));
        dynamic shortcut = shell.CreateShortcut(Path.Combine(directory, Game + ".lnk"));
        shortcut.TargetPath = target;
        shortcut.WorkingDirectory = Path.GetDirectoryName(target);
        shortcut.IconLocation = target + ",0";
        shortcut.Description = Game + " by " + Publisher;
        shortcut.Save();
    }

    internal static void RemoveShortcut(string directory, string target)
    {
        if (String.IsNullOrEmpty(directory)) return;
        var path = Path.Combine(directory, Game + ".lnk");
        if (!File.Exists(path)) return;
        dynamic shell = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell"));
        dynamic shortcut = shell.CreateShortcut(path);
        if (String.Equals((string)shortcut.TargetPath, target, StringComparison.OrdinalIgnoreCase)) File.Delete(path);
    }

    private static void Register(string folder)
    {
        using (var entry = Registry.CurrentUser.CreateSubKey(RegistryPath))
        {
            entry.SetValue("DisplayName", Game);
            entry.SetValue("DisplayVersion", "Online Versus Playtest");
            entry.SetValue("Publisher", Publisher);
            entry.SetValue("InstallLocation", folder);
            entry.SetValue("DisplayIcon", Path.Combine(folder, Exe));
            entry.SetValue("UninstallString", "\"" + Path.Combine(folder, Uninstall) + "\"");
            entry.SetValue("NoModify", 1);
            entry.SetValue("NoRepair", 1);
            long bytes = new FileInfo(Path.Combine(folder, Exe)).Length + new FileInfo(Path.Combine(folder, Pack)).Length;
            entry.SetValue("EstimatedSize", (int)(bytes / 1024));
        }
    }
}
