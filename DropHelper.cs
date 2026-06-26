using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

class DropHelper
{
    [DllImport("user32.dll")]
    static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll", SetLastError = true)]
    static extern IntPtr FindWindowEx(IntPtr hwndParent, IntPtr hwndChildAfter, string lpszClass, string lpszWindow);

    [DllImport("user32.dll", SetLastError = true)]
    static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll", SetLastError = true)]
    static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

    [DllImport("user32.dll")]
    static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    // WM_DROPFILES
    [DllImport("user32.dll", SetLastError = true)]
    static extern IntPtr PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll")]
    static extern IntPtr GlobalAlloc(uint uFlags, UIntPtr dwBytes);

    [DllImport("kernel32.dll")]
    static extern IntPtr GlobalLock(IntPtr hMem);

    [DllImport("kernel32.dll")]
    static extern bool GlobalUnlock(IntPtr hMem);

    [DllImport("kernel32.dll")]
    static extern IntPtr GlobalFree(IntPtr hMem);

    const uint GMEM_MOVEABLE = 0x0002;
    const uint GMEM_ZEROINIT = 0x0040;
    const uint WM_DROPFILES = 0x0233;

    static IntPtr foundHwnd = IntPtr.Zero;
    static int targetProcessId = -1;

    static void Main(string[] args)
    {
        if (args.Length < 1)
        {
            Console.Error.WriteLine("Usage: DropHelper.exe <file.ncm>");
            Environment.Exit(1);
        }

        string filePath = args[0];
        Console.WriteLine("File: " + filePath);

        // Find cloudmusic processes
        Process[] procs = Process.GetProcessesByName("cloudmusic");
        if (procs.Length == 0)
        {
            Console.Error.WriteLine("ERROR: cloudmusic is not running");
            Environment.Exit(1);
        }

        // Find the main window
        IntPtr mainHwnd = IntPtr.Zero;
        foreach (Process p in procs)
        {
            if (p.MainWindowHandle != IntPtr.Zero)
            {
                mainHwnd = p.MainWindowHandle;
                targetProcessId = p.Id;
                Console.WriteLine("Found window: PID=" + p.Id + " HWND=" + mainHwnd);
                break;
            }
        }

        if (mainHwnd == IntPtr.Zero)
        {
            // Try to find any visible window owned by cloudmusic
            Console.WriteLine("MainWindowHandle is empty, searching for child windows...");
            foreach (Process p in procs)
            {
                targetProcessId = p.Id;
            }

            EnumWindows((hWnd, lParam) =>
            {
                uint pid;
                GetWindowThreadProcessId(hWnd, out pid);
                if (pid == targetProcessId)
                {
                    var sb = new StringBuilder(256);
                    GetClassName(hWnd, sb, 256);
                    var cn = sb.ToString();
                    sb.Clear();
                    GetWindowText(hWnd, sb, 256);
                    var title = sb.ToString();
                    Console.WriteLine("  HWND=" + hWnd + " class=" + cn + " title=" + title);
                    if (foundHwnd == IntPtr.Zero && IsVisible(hWnd))
                    {
                        foundHwnd = hWnd;
                    }
                }
                return true;
            }, IntPtr.Zero);

            if (foundHwnd != IntPtr.Zero)
            {
                mainHwnd = foundHwnd;
                Console.WriteLine("Using HWND=" + mainHwnd);
            }
        }

        if (mainHwnd == IntPtr.Zero)
        {
            Console.Error.WriteLine("ERROR: Cannot find cloudmusic window");
            Environment.Exit(1);
        }

        // Build DROPFILES structure
        byte[] fileBytes = Encoding.Unicode.GetBytes(filePath);
        int headerSize = 20; // sizeof(DROPFILES)
        int totalSize = headerSize + fileBytes.Length + 2; // double null terminate

        IntPtr hGlobal = GlobalAlloc(GMEM_MOVEABLE | GMEM_ZEROINIT, (UIntPtr)(uint)totalSize);
        if (hGlobal == IntPtr.Zero)
        {
            Console.Error.WriteLine("ERROR: GlobalAlloc failed");
            Environment.Exit(1);
        }

        IntPtr pGlobal = GlobalLock(hGlobal);
        if (pGlobal == IntPtr.Zero)
        {
            GlobalFree(hGlobal);
            Console.Error.WriteLine("ERROR: GlobalLock failed");
            Environment.Exit(1);
        }

        // DROPFILES header
        Marshal.WriteInt32(pGlobal, 0, headerSize);  // pFiles offset
        Marshal.WriteInt32(pGlobal, 4, -1);           // pt.x = -1 (use current mouse position)
        Marshal.WriteInt32(pGlobal, 8, -1);           // pt.y = -1
        Marshal.WriteInt32(pGlobal, 12, 0);           // fNC = FALSE
        Marshal.WriteInt32(pGlobal, 16, 1);           // fWide = TRUE (Unicode)

        // Write file path
        for (int i = 0; i < fileBytes.Length; i++)
        {
            Marshal.WriteByte(pGlobal, headerSize + i, fileBytes[i]);
        }
        // Already zeroed by GMEM_ZEROINIT for double null

        GlobalUnlock(hGlobal);

        // Send WM_DROPFILES
        Console.WriteLine("Sending WM_DROPFILES to " + mainHwnd + "...");
        IntPtr result = PostMessage(mainHwnd, WM_DROPFILES, hGlobal, IntPtr.Zero);
        if (result == IntPtr.Zero)
        {
            int err = Marshal.GetLastWin32Error();
            Console.Error.WriteLine("ERROR: PostMessage failed, error=" + err);
        }
        else
        {
            Console.WriteLine("WM_DROPFILES sent successfully");
        }

        // Note: we do NOT call GlobalFree here because the receiver
        // should free it when done. However, as a safety measure, 
        // we schedule cleanup after a delay.
        // Actually, PostMessage is async - the receiver will free it.
        
        Console.WriteLine("Done");
    }

    [DllImport("user32.dll")]
    static extern bool IsWindowVisible(IntPtr hWnd);
    
    static bool IsVisible(IntPtr hWnd)
    {
        return IsWindowVisible(hWnd);
    }
}
