# debian-rootfs
#### WARNING: not finished lmao
debian-rootfs generator using debootstrap <br />
maybe multistrap idk <br />
project is fucked up ofc

Work in progress :P 

### How to build
#### On shell
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

#### Using Github Actions (workflow_dispatch)
1. Fork this repo
2. Then go to the Actions tab of your fork
3. Select any one of the workflows
4. Click on Run Workflow
5. Set required variables like architecture
6. Then click on Run Workflow
7. Go to the workflow you ran
8. Download the artifact(s)

### My plans
I want to add stuff like
- [ ] build debian-rootfs using both debootstrap and multistrap
- [ ] multi distro support (as much as possible by the packages ofc)
- [ ] a proper nice lookin logging system (doesn't make sense but eh)

well I'm learning some of bash scripting stuff through this specific repo so eh <br />
that's it ig

