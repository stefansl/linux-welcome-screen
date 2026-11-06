# Linux Welcome Screen

A lightweight, cross-distro **dynamic login dashboard** for Linux.  
Now with multi-shell support — works with **Bash, Zsh, Fish, Ksh, Dash** and more!

![screen.png](screen.png)
---

## Features

- 🖥 Shows hostname, OS, uptime, load, memory, disk, and IP
- 📦 Counts available updates for your distro’s package manager
- 🧩 Detects failed systemd/SysV services
- 🔄 Warns when a reboot is required (Debian/Ubuntu, Fedora/RHEL, openSUSE, kernel updates on Arch/Alpine & others)
- 🧱 Fancy ASCII banner via `figlet`
- 🐚 Works in Bash, Zsh, Fish, Dash, Ksh

---

## Universal One-Liner Install

```bash
curl -sL https://raw.githubusercontent.com/stefansl/linux-welcome-screen/main/install.sh | sudo bash
