# debian-rootfs
### Status
[![Push-builds](https://github.com/AyHa1810/debian-rootfs/actions/workflows/push-builds.yml/badge.svg)](https://github.com/AyHa1810/debian-rootfs/actions/workflows/push-builds.yml)
#### WARNING: not finished lmao
debian-rootfs generator using debootstrap <br />
maybe multistrap idk

Work in progress :P 

## How to build
### On shell
1. Clone the repo using 
```
$ git clone https://github.com/AyHa1810/debian-rootfs.git
```
2. Give execute permission to the setup file using
```
$ chmod +x setup-debootstrap.sh
```
3. Run the setup using
```
$ sudo setup-debootstrap.sh [options]
```

### Using Github Actions (workflow_dispatch)
1. Fork this repo
2. Then go to the Actions tab of your fork
3. Select any one of the workflows
4. Click on Run Workflow
5. Set required variables like architecture
6. Then click on Run Workflow
7. Go to the workflow you ran
8. Download the artifact(s)

## My plans
I want to add stuff like
- [ ] build debian-rootfs using both debootstrap and multistrap
- [ ] build debian-rootfs for Windows Subsystem for Linux (WSL)
- [ ] multi distro support (as much as possible by the packages ofc)
- [ ] a proper nice lookin logging system (doesn't make sense but eh)

## Related
- [debian-rootfs](https://github.com/jubinson/debian-rootfs) by [@jubinson](https://github.com/jubinson) (MIT)
- [log4bash](https://github.com/fredpalmer/log4bash) by [@fredpalmer](https://github.com/fredpalmer) (BSD 3-Clause)
- [slog](https://github.com/swelljoe/slog) by [@swelljoe](https://github.com/swelljoe) (BSD 3-Clause)
- [multistrap](https://wiki.debian.org/Multistrap) (GNU GPL v3)
- [debootstrap](https://wiki.debian.org/Debootstrap) (GNU GPL v2)

well I'm learning some of bash scripting stuff through this specific repo so eh <br />
that's it ig

