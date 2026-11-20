using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: AssemblyTitle("Charm City Beatdown Uninstall")]
[assembly: AssemblyCompany("BSOD Interactive")]

internal static class Uninstall
{
    [STAThread]
    private static void Main(string[] args)
    {
        Application.EnableVisualStyles();
        try
        {
            var folder = InstallFiles.InstalledFolder();
            if (String.IsNullOrEmpty(folder) || !InstallFiles.OwnsFolder(folder)) return;
            if (args.Length == 2 && args[0] == "--remove")
            {
                try
                {
                    using (var parent = Process.GetProcessById(Int32.Parse(args[1])))
                        if (!parent.WaitForExit(5000)) throw new IOException("Close setup and try again.");
                }
                catch (ArgumentException) { }
                Remove(folder);
                return;
            }
            if (MessageBox.Show("Remove Charm City Beatdown? Your game settings and scores will be kept.",
                InstallFiles.Game, MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
            InstallFiles.EnsureGameClosed(folder);
            var helper = Path.Combine(Path.GetTempPath(), "BSOD-CCBD-Uninstall-" + Guid.NewGuid().ToString("N") + ".exe");
            File.Copy(Application.ExecutablePath, helper);
            Process.Start(new ProcessStartInfo(helper, "--remove " + Process.GetCurrentProcess().Id) { UseShellExecute = false });
        }
        catch (Exception error)
        {
            MessageBox.Show("Close the game if it is running, then try again.\n\n" + error.Message,
                InstallFiles.Game, MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
    }

    private static void Remove(string folder)
    {
        InstallFiles.EnsureGameClosed(folder);
        var game = Path.Combine(folder, InstallFiles.Exe);
        InstallFiles.RemoveShortcut(Environment.GetFolderPath(Environment.SpecialFolder.Programs), game);
        InstallFiles.RemoveShortcut(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), game);
        foreach (var filename in new[] { InstallFiles.Exe, InstallFiles.Pack, InstallFiles.Uninstall, InstallFiles.OwnerFile })
            File.Delete(Path.Combine(folder, filename));
        Registry.CurrentUser.DeleteSubKey(InstallFiles.RegistryPath, false);
        if (Directory.GetFileSystemEntries(folder).Length == 0) Directory.Delete(folder);
    }
}
