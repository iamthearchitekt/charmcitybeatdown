using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Threading.Tasks;
using System.Windows.Forms;

[assembly: AssemblyTitle("Charm City Beatdown Setup")]
[assembly: AssemblyCompany("BSOD Interactive")]
[assembly: AssemblyProduct("Charm City Beatdown")]
[assembly: AssemblyDescription("Online Versus playtest installer")]

internal static class Setup
{
    [STAThread]
    private static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        if (!Environment.Is64BitOperatingSystem)
        {
            MessageBox.Show("Charm City Beatdown requires 64-bit Windows.", InstallFiles.Game);
            return;
        }
        Application.Run(new SetupWizard());
    }
}

internal sealed class SetupWizard : Form
{
    private static readonly Color Navy = Color.FromArgb(10, 18, 32);
    private static readonly Color Sidebar = Color.FromArgb(15, 26, 44);
    private static readonly Color Gold = Color.FromArgb(239, 188, 109);
    private static readonly Color Mist = Color.FromArgb(180, 198, 212);
    private readonly Panel content = new Panel();
    private readonly Button back;
    private readonly Button next;
    private readonly Button cancel;
    private readonly Label heading;
    private readonly Label explanation;
    private readonly Label destination;
    private readonly TextBox folder;
    private readonly Button browse;
    private readonly CheckBox desktop;
    private readonly CheckBox launch;
    private readonly ProgressBar progress;
    private readonly string existing = InstallFiles.InstalledFolder();
    private string installedPath;
    private int page;
    private bool running;

    internal SetupWizard()
    {
        Text = "Charm City Beatdown Setup";
        Font = new Font("Segoe UI", 10);
        ForeColor = Color.White;
        BackColor = Navy;
        AutoScaleMode = AutoScaleMode.Dpi;
        AutoScaleDimensions = new SizeF(96F, 96F);
        ClientSize = new Size(784, 458);
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        Icon = System.Drawing.Icon.ExtractAssociatedIcon(Application.ExecutablePath);

        var brand = new Panel { BackColor = Sidebar, Bounds = new Rectangle(0, 0, 254, 458) };
        var logo = new PictureBox { Bounds = new Rectangle(19, 63, 216, 196), SizeMode = PictureBoxSizeMode.Zoom };
        using (var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("Logo.png"))
        using (var image = Image.FromStream(stream))
            logo.Image = new Bitmap(image);
        brand.Controls.Add(logo);
        brand.Controls.Add(MakeLabel("BSOD INTERACTIVE", 20, 290, 214, 28, 15, Gold, true, ContentAlignment.MiddleCenter));
        brand.Controls.Add(MakeLabel("A product of BSOD Interactive", 16, 326, 222, 40, 9, Mist, false, ContentAlignment.TopCenter));
        brand.Controls.Add(MakeLabel("ONLINE VERSUS PLAYTEST", 16, 412, 222, 24, 9, Gold, true, ContentAlignment.MiddleCenter));
        Controls.Add(brand);
        Controls.Add(new Panel { BackColor = Gold, Bounds = new Rectangle(254, 0, 2, 458) });

        content.Bounds = new Rectangle(256, 0, 528, 387);
        Controls.Add(content);
        heading = MakeLabel("", 30, 35, 468, 43, 24, Gold, true);
        explanation = MakeLabel("", 31, 98, 459, 67, 11, Mist);
        destination = MakeLabel("Installation folder", 31, 176, 454, 25, 10, Color.White, true);
        folder = new TextBox { Text = existing ?? InstallFiles.DefaultFolder(), Bounds = new Rectangle(31, 205, 348, 30), Font = new Font("Segoe UI", 10), BackColor = Sidebar, ForeColor = Color.White, ReadOnly = existing != null };
        browse = MakeButton("Browse…", 388, 201, 103, 34, false);
        browse.Enabled = existing == null;
        browse.Click += delegate
        {
            using (var picker = new FolderBrowserDialog())
            {
                picker.Description = "Choose a folder for Charm City Beatdown.";
                picker.SelectedPath = folder.Text;
                if (picker.ShowDialog(this) == DialogResult.OK) folder.Text = picker.SelectedPath;
            }
        };
        desktop = new CheckBox { Text = "Create a desktop shortcut", Bounds = new Rectangle(30, 256, 422, 36), Checked = true };
        launch = new CheckBox { Text = "Launch Charm City Beatdown", Bounds = new Rectangle(30, 209, 422, 36), Checked = true };
        progress = new ProgressBar { Bounds = new Rectangle(31, 190, 461, 26), Style = ProgressBarStyle.Continuous };
        content.Controls.AddRange(new Control[] { heading, explanation, destination, folder, browse, desktop, launch, progress });

        Controls.Add(new Panel { BackColor = Sidebar, Bounds = new Rectangle(256, 384, 528, 2) });
        back = MakeButton("Back", 342, 404, 119, 36, false);
        next = MakeButton("Next", 474, 404, 132, 36, true);
        cancel = MakeButton("Cancel", 619, 404, 132, 36, false);
        back.Click += delegate { ShowPage(0); };
        next.Click += Advance;
        cancel.Click += delegate { Close(); };
        FormClosing += delegate(object sender, FormClosingEventArgs args) { if (running) args.Cancel = true; };
        Controls.AddRange(new Control[] { back, next, cancel });
        AcceptButton = next;
        CancelButton = cancel;
        ShowPage(0);
    }

    private static Label MakeLabel(string text, int x, int y, int width, int height, int size, Color color, bool bold = false, ContentAlignment align = ContentAlignment.TopLeft)
    {
        return new Label { Text = text, Bounds = new Rectangle(x, y, width, height), Font = new Font("Segoe UI", size, bold ? FontStyle.Bold : FontStyle.Regular), ForeColor = color, TextAlign = align };
    }

    private static Button MakeButton(string text, int x, int y, int width, int height, bool primary)
    {
        var button = new Button { Text = text, Bounds = new Rectangle(x, y, width, height), FlatStyle = FlatStyle.Flat, BackColor = primary ? Gold : Sidebar, ForeColor = primary ? Navy : Color.White };
        button.FlatAppearance.BorderColor = primary ? Gold : Color.FromArgb(75, 95, 118);
        return button;
    }

    private void ShowPage(int step)
    {
        page = step;
        var headings = new[] { "Ready to fight?", "Installation options", "Installing the game", "Installation complete" };
        var copy = new[] {
            "Install Charm City Beatdown and challenge a friend in Online Versus. This playtest includes everything needed to run the game.",
            "Choose where to install the game. Setup also adds Charm City Beatdown to the Start Menu.",
            "Copying the Windows game files and creating your shortcuts.",
            "The game is ready. Open Online Versus from the title screen to create a room or join a friend."
        };
        heading.Text = headings[page];
        explanation.Text = copy[page];
        destination.Visible = folder.Visible = browse.Visible = desktop.Visible = page == 1;
        launch.Visible = page == 3;
        progress.Visible = page == 2;
        back.Enabled = page == 1;
        cancel.Enabled = page < 2;
        next.Enabled = page != 2;
        next.Text = new[] { "Next", "Install", "Installing…", "Finish" }[page];
    }

    private async void Advance(object sender, EventArgs args)
    {
        if (page == 0) { ShowPage(1); return; }
        if (page == 3)
        {
            if (launch.Checked)
            {
                try { Process.Start(new ProcessStartInfo(Path.Combine(installedPath, InstallFiles.Exe)) { WorkingDirectory = installedPath, UseShellExecute = true }); }
                catch (Exception error) { MessageBox.Show(this, error.Message, Text, MessageBoxButtons.OK, MessageBoxIcon.Warning); }
            }
            Close();
            return;
        }
        if (page != 1) return;
        if (String.IsNullOrWhiteSpace(folder.Text))
        {
            MessageBox.Show(this, "Choose an installation folder.", Text, MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }
        var target = folder.Text.Trim();
        var programs = Environment.GetFolderPath(Environment.SpecialFolder.Programs);
        var desktopPath = desktop.Checked ? Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory) : null;
        var update = new Progress<int>(percent => progress.Value = percent);
        running = true;
        progress.Value = 0;
        ShowPage(2);
        try
        {
            await Task.Run(() => InstallFiles.Install(target, programs, desktopPath, true, ((IProgress<int>)update).Report));
            installedPath = Path.GetFullPath(target);
            ShowPage(3);
        }
        catch (Exception error)
        {
            MessageBox.Show(this, error.Message, Text, MessageBoxButtons.OK, MessageBoxIcon.Warning);
            ShowPage(1);
        }
        finally { running = false; }
    }
}
