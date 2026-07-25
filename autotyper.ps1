# AutoTyper - no dependencies, uses only built-in Windows PowerShell.
# F8 = type text into focused window, F9 = stop. Delay 80-200ms/char +/- 20ms jitter.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @"
using System;
using System.Windows.Forms;
using System.Runtime.InteropServices;
public class HotkeyWindow : NativeWindow, IDisposable {
    [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr hWnd, int id, int mod, int vk);
    [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    public event Action<int> Pressed;
    public HotkeyWindow() { CreateHandle(new CreateParams()); }
    public bool Register(int id, int vk) { return RegisterHotKey(Handle, id, 0, vk); }
    protected override void WndProc(ref Message m) {
        if (m.Msg == 0x0312 && Pressed != null) Pressed((int)m.WParam);
        base.WndProc(ref m);
    }
    public void Dispose() { UnregisterHotKey(Handle, 1); UnregisterHotKey(Handle, 2); DestroyHandle(); }
}
"@ -ReferencedAssemblies System.Windows.Forms

$form = New-Object Windows.Forms.Form
$form.Text = "AutoTyper - F8 type, F9 stop"
$form.Size = New-Object Drawing.Size(540, 440)
$form.TopMost = $true

$label = New-Object Windows.Forms.Label
$label.Text = "Text to type:"
$label.Location = New-Object Drawing.Point(8, 8)
$label.AutoSize = $true
$form.Controls.Add($label)

$textBox = New-Object Windows.Forms.TextBox
$textBox.Multiline = $true
$textBox.ScrollBars = "Vertical"
$textBox.Location = New-Object Drawing.Point(8, 28)
$textBox.Size = New-Object Drawing.Size(508, 240)
$textBox.Anchor = "Top,Bottom,Left,Right"
$form.Controls.Add($textBox)

$speedLabel = New-Object Windows.Forms.Label
$speedLabel.Text = "Delay per char (ms): 100"
$speedLabel.Location = New-Object Drawing.Point(8, 278)
$speedLabel.AutoSize = $true
$speedLabel.Anchor = "Bottom,Left"
$form.Controls.Add($speedLabel)

$slider = New-Object Windows.Forms.TrackBar
$slider.Minimum = 80
$slider.Maximum = 200
$slider.Value = 100
$slider.TickFrequency = 10
$slider.Location = New-Object Drawing.Point(160, 272)
$slider.Size = New-Object Drawing.Size(356, 45)
$slider.Anchor = "Bottom,Left,Right"
$slider.Add_ValueChanged({ $speedLabel.Text = "Delay per char (ms): $($slider.Value)" })
$form.Controls.Add($slider)

$typeBtn = New-Object Windows.Forms.Button
$typeBtn.Text = "Type (F8)"
$typeBtn.Location = New-Object Drawing.Point(8, 330)
$typeBtn.Anchor = "Bottom,Left"
$form.Controls.Add($typeBtn)

$stopBtn = New-Object Windows.Forms.Button
$stopBtn.Text = "Stop (F9)"
$stopBtn.Location = New-Object Drawing.Point(96, 330)
$stopBtn.Anchor = "Bottom,Left"
$form.Controls.Add($stopBtn)

$status = New-Object Windows.Forms.Label
$status.Text = "Paste text, focus target window, press F8."
$status.ForeColor = "Blue"
$status.Location = New-Object Drawing.Point(8, 365)
$status.AutoSize = $true
$status.Anchor = "Bottom,Left"
$form.Controls.Add($status)

$script:queue = @()
$script:pos = 0
$rand = New-Object System.Random

# Characters SendKeys treats as special - must be wrapped in braces
$special = '+^%~(){}[]'

$timer = New-Object Windows.Forms.Timer

function Send-OneChar {
    $ch = $script:queue[$script:pos]
    $script:pos++
    switch ($ch) {
        "`n" { [Windows.Forms.SendKeys]::SendWait("{ENTER}") }
        "`r" { }
        "`t" { [Windows.Forms.SendKeys]::SendWait("{TAB}") }
        default {
            if ($special.Contains([string]$ch)) {
                [Windows.Forms.SendKeys]::SendWait("{$ch}")
            } else {
                [Windows.Forms.SendKeys]::SendWait([string]$ch)
            }
        }
    }
}

$timer.Add_Tick({
    if ($script:pos -ge $script:queue.Count) {
        $timer.Stop()
        $status.Text = "Done. F8 to type again."
        return
    }
    Send-OneChar
    $jitter = $rand.Next(-20, 21)
    $timer.Interval = [Math]::Max(1, $slider.Value + $jitter)
})

function Start-Typing {
    if ($timer.Enabled) { return }
    $text = $textBox.Text
    if (-not $text) { return }
    $script:queue = $text.ToCharArray()
    $script:pos = 0
    $status.Text = "Typing... (F9 stops)"
    $timer.Interval = $slider.Value
    $timer.Start()
}

function Stop-Typing {
    $timer.Stop()
    $status.Text = "Stopped."
}

$typeBtn.Add_Click({ Start-Typing })
$stopBtn.Add_Click({ Stop-Typing })

$hk = New-Object HotkeyWindow
$null = $hk.Register(1, 0x77)  # F8
$null = $hk.Register(2, 0x78)  # F9
$hk.add_Pressed({ param($id) if ($id -eq 1) { Start-Typing } else { Stop-Typing } })

$form.Add_FormClosed({ $hk.Dispose() })
[Windows.Forms.Application]::Run($form)
