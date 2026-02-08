# Smart Math Plugin for Notepad++

**Smart Math** is a lightweight, powerful plugin that turns Notepad++ into a dynamic calculator, inspired by tools like *Soulver* or *Numara*. It allows you to perform calculations naturally in plain text, showing results in real-time without altering your file content.

### ✨ Features
*   **Real-Time Evaluation:** Instantly evaluates addition, subtraction, multiplication, and division as you type.
*   **Non-Invasive Annotations:** Results are displayed using Scintilla’s End-of-Line (EOL) annotations. Your actual text remains untouched.
*   **Variable Support:** Define variables (e.g., `base = 100`) and reference them in subsequent lines (e.g., `base * 1.15`).
*   **Percentage Logic:** Intuitive handling of the `%` character (e.g., `500 + 21%`).
*   **Per-Tab Persistence:** The plugin operates independently for each document. It remembers which tabs have "Smart Math" enabled even after restarting Notepad++, allowing you to keep calculation sheets active alongside source code.
*   **Customizable Precision:** Set result output from 0 to 8 decimal places via the plugin menu.

### 🛠 Technical Details
*   **Language:** 100% FreeBASIC.
*   **Interface:** Based on the Notepad++ Plugin SDK and Scintilla API.
*   **Architecture:** Compatible and compilable for both **x86** (32-bit) and **x64** (64-bit).
*   **Dependencies:** None. It is a native, standalone binary.
*   **Storage:** Settings and tab states are saved in an `.ini` file within the Notepad++ plugins configuration folder.

### ⚙️ Compilation
To compile the plugin yourself:
1.  Ensure you have the **FreeBASIC** compiler installed and added to your PATH.
2.  Open a terminal in the project's root folder.
3.  Run the `Compile.bat` file.

### 📦 Installation
1.  Create a folder named `Smart-Math` inside the `plugins` directory of your Notepad++ installation.
    *   Typical path: `C:\Program Files\Notepad++\plugins\Smart-Math\`
2.  Copy the compiled DLL (`Smart-Math.dll`) into that folder.
3.  Restart Notepad++.

### 🙏 Special Thanks
This project was originally started in FreePascal. However, seeking better binary size optimization and a cleaner code structure, I decided to port it to **FreeBASIC**.

I would like to express my deepest gratitude to **Mysoft**, who was instrumental in this transition. He not only convinced me of FreeBASIC's benefits for plugin development but also generously shared his original code to serve as the template and backbone for **Smart-Math**.